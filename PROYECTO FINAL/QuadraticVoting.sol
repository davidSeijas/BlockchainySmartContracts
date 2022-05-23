// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./SafeMath.sol";
import "./ERC20.sol";

interface IExecutableProposal {

    event Executing(uint id, uint numVotes, uint numTokens, uint budget, uint balance, string message);

    function executeProposal(uint proposalId, uint numVotes, uint numTokens) external payable;
}


contract SignalingProposal is IExecutableProposal {

    function executeProposal(uint proposalId, uint numVotes, uint numTokens) external payable override{
        emit Executing(proposalId, numVotes, numTokens, msg.value, address(this).balance, "Ejecutando la propuesta...");
    }
}

contract FinantialProposal is IExecutableProposal {

    function executeProposal(uint proposalId, uint numVotes, uint numTokens) external payable override{
        emit Executing(proposalId, numVotes, numTokens, msg.value, address(this).balance, "Ejecutando la propuesta...");
    }
}


contract TokenManager is ERC20 {

    address immutable admin;

    modifier onlyAdmin(){
        require(msg.sender == admin , "No permission");
        _;
    }

    constructor(string memory _name, string memory _desc) ERC20(_name,_desc){
        admin = msg.sender;
    }

    function mint(address account, uint256 amount) external onlyAdmin {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) external onlyAdmin{
        _burn(account, amount);
    }

}


contract QuadraticVoting {

    //Creador de la votacion
    address immutable admin; 
    //Precio del token
    uint tokenPrice;
    //Nº máximo de tokens que se ponen en venta  
    uint maxTokens; 
    //Contrato ERC-20
    TokenManager tokenContract; 
    //Presupuesto de la votacion disponible para propuestas
    uint totalBudget; 
    //Comprobar si el periodo de votación está abierto
    bool isOpen; 

    //Informacion sobre una propuesta
    struct ProposalInfo{
        address creator;
        string tittle;
        string description;
        uint budget; //Presupuesto de la propuesta
        uint votes;
        uint tokens;
        uint indexList; //Indice de la correspondiente lista de propuestas para eliminarla cuando se cancela
        address proposalContract; //cuenta del contrato de una propuesta que se crea
        bool isApproved; //Redundante, para no tener que recorrer todo el array de notApproved en los modifiers
    }

    //Ver que participantes estan inscritos
    mapping(address => bool) participants; 

    //Lista de participantes inscritos
    address[] participantsList;

    //Asociar id con la info de propuesta
    mapping(uint => ProposalInfo) proposalsInfo;

    //Lista de propuestas (guardamos los ids)
    uint[] signProps;
    uint[] finPropsNotApproved;
    uint[] finPropsApproved;
    
    //Asociar a cada propuesta la cantidad de votos que lleva cada persona en esa propuesta
    mapping(address => mapping(uint => uint)) participantVotes;

    //Cambio que le sobra a cada participante al comprar tokens.
    mapping(address => uint) participantExchange;

    //Numero histórico de propuestas, utilizado para dar id a cada una
    uint idProposals;
    
    //Evitar vulnerabilidad Reentrancy
    bool lock = false;
    bool lock2 = false;

    //Ejecutar acciones solo si eres el administrador de la votacion
    modifier onlyAdmin(){
        require(admin == msg.sender, "You're not the admin of the votation.");
        _;
    }

    //Ejecutar acciones solo si la votacion esta abierta
    modifier isPeriodOpen(){
        require(isOpen, "The votation isn't open. You can't do this action.");
        _;
    }

    //Ejecutar acciones solo si eres participante
    modifier onlyParticipants(){
        require(participants[msg.sender], "You're not a participant yet.");
        _;
    }

    //Ejecutar acciones sobre una propuesta solo si eres el creador de ella
    modifier onlyCreator(uint proposalId){
        require(proposalsInfo[proposalId].creator == msg.sender, "You're not the creator of this proposal.");
        _;
    }

    //Comprobar que el id es valido
    modifier isProposal(uint _proposalId){
        require(proposalsInfo[_proposalId].creator != address(0), "This proposal doesn't exist.");
        _;
    }

    //Comprobar que la propuesta todavia no ha sido aprobada
    modifier isnotProposalApproved(uint _proposalId){
        require(!proposalsInfo[_proposalId].isApproved, "This proposal has already been approved.");
        _;
    }

    //Evento de aprobar una propuesta
    event ApprovedProposal(uint _proposalId, string _message);
    //Evento de compra de tokens
    event BoughtTokens(uint _tokens, string _message);

    //No obligamos pero la idea es lanzar el contrato con tokenPrice > 0
    constructor(uint _tokenPrice, uint _maxTokens){
        admin = msg.sender;
        tokenPrice = _tokenPrice;
        maxTokens = _maxTokens;
        tokenContract = new TokenManager("Toks", "desc");
        idProposals = 1;
    }
    
    //Abrir un periodo de votacion
    function openVoting() public onlyAdmin payable {
        //Obligamos a que el budget de la votacion sea > 0 porque si no nunca se pueden aprobar propuestas
        require(msg.value > 0, "You need to introduce budget");
        //Establecemos el presupuesto inicial del contrato es la cantidad con la que abrimos la votacion
        totalBudget = msg.value;
        //Abrimos votacion
        isOpen = true;
    }

    //Añadir nuevo participante
    function addParticipant() public payable {
        require(!participants[msg.sender], "You are already a participant");
        //Obligamos a que adquieran al menos 1 token
        uint tokens = _calculateTokens(msg.value, msg.sender);
        require(tokens >= 1, "Not enough ethers to buy at least one token");
        //Comprobar que quedan suficientes tokens a la aventa
        //TotalSuply siempre va a ser menor o igual que maxTokens
        require(maxTokens - tokenContract.totalSupply() >= tokens, "There are not enought available tokens");
        
        //Inscribimos al participante
        participants[msg.sender] = true;
        participantsList.push(msg.sender);
        //Transferir los tokens al participante
        tokenContract.mint(msg.sender, tokens);
        
        //Emitir evento de tokens comprados
        emit BoughtTokens(tokens, "You have bought {tokens} tokens"); //checkear como se escribe eso bien
    }

    //Añadir nueva propuesta
    function addProposal(string memory _title, string memory _description, uint _budget, address _accountContract) public isPeriodOpen onlyParticipants returns(uint) {
        require(msg.sender != address(0), "The creator must be an account");
        //Añadir propuesta a su correspondiente lista
        uint index;
        if(_budget == 0){//Es signaling
            index = signProps.length;
            signProps.push(idProposals);
        }
        else { //Financial no approved
            index = finPropsNotApproved.length;
            finPropsNotApproved.push(idProposals);
        }
        
        //Guardar la informacion de la propuesta
        ProposalInfo memory proposal = ProposalInfo(msg.sender, _title, _description, _budget, 0, 0, index, _accountContract, false);
        proposalsInfo[idProposals] = proposal;
        unchecked{ //2^256 es mayor que el nº de átomos del universo. No creemos que hayan tantas propuestas
            idProposals += 1;
        }

        return idProposals - 1;
    }

    //Cancelar propuesta
    function cancelProposal(uint _proposalId) public isPeriodOpen isProposal(_proposalId) isnotProposalApproved(_proposalId) onlyCreator(_proposalId) {
        //Devolucion de tokens
        for(uint i = 0; i < participantsList.length; ++i){
            address participant = participantsList[i];
            //Tokens que se le deben devolver (si no ha votado no se le devuelve nada)
            uint tokens = participantVotes[participant][_proposalId]**2;
            if(tokens > 0)
                tokenContract.transfer(participant,tokens);
        }

        //Descartar la propuesta
        if(proposalsInfo[_proposalId].budget == 0){ //La propuesta es signaling
            //Guardar indices involucrados para evitar mas accesos
            uint lastIndex;
            unchecked{ //Sabemos que al ser signaling tiene que haber alguna propuesta en el array sigProps (y no se ha cancelado anteriormente por el modifier isProposal)
                lastIndex = signProps.length - 1;
            }
            uint deleteIndex = proposalsInfo[_proposalId].indexList;
            //Cambiar índice del último 
            proposalsInfo[signProps[lastIndex]].indexList = deleteIndex;
            //Intercambiar elementos en el array y eliminar el último
            signProps[deleteIndex] = signProps[lastIndex];
            signProps.pop();
        }
        else{//La propuesta es financial, not approved
            //Guardar indices involucrados para evitar mas accesos
            uint lastIndex; 
            unchecked{ //Idem
                lastIndex = finPropsNotApproved.length - 1;
            }
            uint deleteIndex = proposalsInfo[_proposalId].indexList;
            //Cambiar índice del último 
            proposalsInfo[finPropsNotApproved[lastIndex]].indexList = deleteIndex;
            //Intercambiar elementos en el array y eliminar el último
            finPropsNotApproved[deleteIndex] = finPropsNotApproved[lastIndex];
            finPropsNotApproved.pop();
        }
        
        //Eliminamos informacion del mapping
        delete proposalsInfo[_proposalId];
    }

    
    //Comprar tokens
    function buyTokens() public onlyParticipants payable {
        //Permitimos que el msg.value sea menor que un tokenPrice, por si con el exchange suma 1 token
        uint tokens = _calculateTokens(msg.value, msg.sender);
        //Comprobar que quedan suficientes tokens a la aventa
        require(maxTokens - tokenContract.totalSupply() >= tokens, "There are not enought available tokens");
        //Asignarle los tokens comprados al participante
        tokenContract.mint(msg.sender, tokens);
        //Emitir evento de tokens comprados
        emit BoughtTokens(tokens, "You have bought {tokens} tokens"); //checkear como se escribe eso bien
    }

    //Vender tokens
    function sellTokens(uint _numTokens) public onlyParticipants payable {
        //Comprobar que los tokens que quiere vender de verdad los tiene
        require(_numTokens >= tokenContract.balanceOf(msg.sender), "Imposible to sell more tokens than you have");
        //Calculamos los ethers que le tocan a devolver
        uint ethersDevolved = _numTokens * tokenPrice;
        //Quemar los tokens que se han vendido
        tokenContract.burn(msg.sender, _numTokens);
        //Le devolvemos los ethers al propietario de los tokens
        payable(msg.sender).transfer(ethersDevolved);
    }

    //Devuelve el total de tokens que quedan disponibles en el sistema
    function getRestTokens() public view returns(uint){
        return maxTokens - tokenContract.totalSupply();
    }

    //Devuelve cambio de un usuario
    function getExchange() public view returns(uint){
        return participantExchange[msg.sender];
    }

    //El participante recupera su cambio
    function regainExchange() public onlyParticipants payable{
        uint exchange = participantExchange[msg.sender];
        participantExchange[msg.sender] = 0;
        payable(msg.sender).transfer(exchange);
    }


    //Obtener la direccion del contrato ERC20
    function getERC20() public view returns(address){
        return address(tokenContract);
    }

    //Devolver array con los ids de las propuestas pendientes de aprobar (solo finantial pues signaling no se pueden aprobar)
    function getPendingProposals() public view isPeriodOpen returns(uint[] memory){
        return finPropsNotApproved;
    }

    //Devolver array con los ids de las propuestas finantial ya aprobadas
    function getApprovedProposals() public view isPeriodOpen returns(uint[] memory){
        return finPropsApproved;
    }

    //Devolver array con los ids de las propuestas signaling
    function getSignalingProposals() public view isPeriodOpen returns(uint[] memory){
        return signProps;
    }

    //Devolver la info de una propuesta segun su id
    function getProposalInfo(uint _proposalId) public view isPeriodOpen isProposal(_proposalId) returns(ProposalInfo memory){
        return proposalsInfo[_proposalId];
    }

    //Votar en una propuesta
    function stake(uint _proposalId, uint _votes) public isPeriodOpen isProposal(_proposalId) isnotProposalApproved(_proposalId){
        require(_votes > 0, "You have to deposit at least 1 vote.");
        
        //Cantidad de votos que ha hecho esa persona a esa propuesta previamente
        uint previousVotes = participantVotes[msg.sender][_proposalId];
        //Cantidad de tokens necesarios a pagar para votar en funcion de votos anteriores
        uint needTokens = (_votes + previousVotes)**2 - previousVotes**2;

        //Comprobar: participante tiene suficientes tokens y permisos de nuestro contrato para operar con ellos
        require(tokenContract.balanceOf(msg.sender) >= needTokens, "You don't have enough tokens to vote");
        require(tokenContract.allowance(msg.sender, address(this)) >= needTokens, "You need to allow us to operate with your tokens");
        
        //Actualizar la info de tokens y votos del participantes que ha votado
        participantVotes[msg.sender][_proposalId] += _votes;
        //Transferir tokens de la cuenta del participante a la del contrato
        tokenContract.transferFrom(msg.sender, address(this), needTokens);

        //Actualizar la info de tokens y votos de la propuesta que ha votado
        proposalsInfo[_proposalId].votes += _votes;
        proposalsInfo[_proposalId].tokens += needTokens;

        //Llama a check si la propuesta no es signaling para ver si hay que ejecutarla
        if(proposalsInfo[_proposalId].budget != 0)
            _checkAndExecuteProposal(_proposalId);
    }

    //Retirar votos de una propuesta
    function withdrawFromProposal(uint _proposalId, uint _votes) public isPeriodOpen isProposal(_proposalId) isnotProposalApproved(_proposalId){
        //Comprobar que ha depositado esa cantidad de votos previamente (no se pueden retirar mas votos de los depositados)
        uint previousVotes = participantVotes[msg.sender][_proposalId];
        require(_votes <= previousVotes, "You haven't deposit that votes amount.");
        
        //Cantidad de tokens que tenemos que devolver
        uint returnTokens = previousVotes**2 - (previousVotes - _votes)**2;
        
        //Actualizar los votos y tokens del participante
        unchecked{ //Hemos comprobado que _votes es como mucho previousVotes
            participantVotes[msg.sender][_proposalId] -= _votes;
        }
        //Devolver tokens a la cuenta del participante
        tokenContract.transfer(msg.sender, returnTokens);

        //Actualizar la info de votos y tokens de la propuesta
        unchecked{ //La propuesta ha de tener al menos esos valores pues si se retiran los votos es porque voto y la info se actualiza al votar
            proposalsInfo[_proposalId].votes -= _votes;
            proposalsInfo[_proposalId].tokens -= returnTokens;
        }
    } 

    //Cerrar la votacion y dejarla en un estado que pueda volver a ser abierta
    function closeVoting() public isPeriodOpen onlyAdmin {
        //Asegurarnos que no haya vulnerabilidades de reentrancy
        require(!lock, "This action is being already executed. You have to wait.");

        //Descartar propuestas no aprobadas
        for(uint i = 0; i < finPropsNotApproved.length; ++i){
            uint proposalId = finPropsNotApproved[i];

            //Devolver tokens a participantes que han votado una propuesta descartada
            for(uint j = 0; j < participantsList.length; ++j){
                tokenContract.transfer(msg.sender, participantVotes[participantsList[i]][proposalId]**2);
            }

            //Borrar info de la propuesta
            delete proposalsInfo[proposalId];
        }

        //Reiniciar lista de propuestas no aprobadas
        finPropsNotApproved = new uint[](0);

        //Aprobar Signaling proposals y descartarla posteriormente (borrado de info)
        for(uint i = 0; i < signProps.length; ++i){
            uint proposalId = signProps[i];

            //Devolver tokens a participantes que han votado a una signaling proposal
            for(uint j = 0; j < participantsList.length; ++j){
                tokenContract.transfer(msg.sender, participantVotes[participantsList[i]][proposalId]**2);
            }

            //Presupuesto de esa propuesta
            uint budget = proposalsInfo[proposalId].budget;
            //Votos de esa propuesta
            uint votes = proposalsInfo[proposalId].votes;
            //Tokens de esa propuesta
            uint tokens = proposalsInfo[proposalId].tokens;

            //Ejecutar signaling proposal
            lock = true;
            IExecutableProposal(payable(proposalsInfo[proposalId].proposalContract)).executeProposal{value: budget, gas :100000}(proposalId,votes,tokens);
            lock = false;

            //Borrar info de la propuesta
            delete proposalsInfo[proposalId];
        }

        //Reiniciar lista de propuestas no aprobadas
        signProps = new uint[](0);

        //Borrar info de las propuestas aprobadas y reiniciar su lista 
        for(uint i = 0; i < finPropsApproved.length; ++i){
            delete proposalsInfo[finPropsApproved[i]];
        }
        finPropsApproved = new uint[](0);

        //Devolve presupuesto restante al propietario y reiniciamos para una nueva votacion
        payable(admin).transfer(totalBudget);
        totalBudget = 0;
        
        //Cerramos periodo de votacion
        isOpen = false;
    }

    //--------- FUNCIONES INTERNAS ---------

    //Ejecuta una propuesta si se cumplen las conidicones necesarias para su aprobacion
    function _checkAndExecuteProposal(uint _proposalId) internal {
        require(!lock2, "This action is being already executed. You have to wait.");
        //Presupuesto de esa propuesta
        uint budget = proposalsInfo[_proposalId].budget;
        //Votos de esa propuesta
        uint votes = proposalsInfo[_proposalId].votes;
        //Tokens de esa propuesta
        uint tokens = proposalsInfo[_proposalId].tokens;

        //1ª condicion: comprobar que tenemos suficiente presupuesto (el de la votacion mas el de los votos)
        if (totalBudget + tokenPrice * tokens > budget){ //Obligamos a ser > para que totalBudget nunca sea 0 porque hace que la votacion sea inconsistente 
            //Calculamos el umbral de aprobacion 
            uint threshold = (2 * totalBudget + 10 * budget) * participantsList.length + 10 * totalBudget * (finPropsNotApproved.length + signProps.length);
            
            //2ª condicion: Nº de votos recibidos por la propuesta supera el umbral
            if(10 * totalBudget * votes >= threshold){ 
                //Ejecutar la propuesta
                lock2 = true;
                IExecutableProposal(payable(proposalsInfo[_proposalId].proposalContract)).executeProposal{value: budget, gas :100000}(_proposalId,votes,tokens);
                lock2 = false;

                //La propuesta ha sido aprobada y ejecutada
                uint lastIndex;
                unchecked{ //Si la propuesta ha sido aprobada es porque en stake el array de porpuestas no aprobadas tenia al menos una porpuesta (la aporbada ahora)
                    lastIndex = finPropsNotApproved.length - 1;
                }
                uint deleteIndex = proposalsInfo[_proposalId].indexList;
                //Cambiar índice de la ultima propuesta del array de no aprobadas
                proposalsInfo[finPropsNotApproved[lastIndex]].indexList = deleteIndex;

                //Eliminar propuesta de lista de no aprobadas 
                finPropsNotApproved[deleteIndex] = finPropsNotApproved[lastIndex];
                finPropsNotApproved.pop();

                //Añadimos la propuesta al array de aprobadas con su info actualizada 
                proposalsInfo[_proposalId].indexList = finPropsApproved.length;
                proposalsInfo[_proposalId].isApproved = true;
                finPropsApproved.push(_proposalId);

                //Emitir evento de aprobacion de propuesta
                emit ApprovedProposal(_proposalId, "This proposal has been approved.");

                //Elimar tokens asociados a los votos de la propuesta
                tokenContract.burn(address(this), tokens);

                //Actualizamos el presupuesto disponible para propuestas (quitamos el de la propuesta aprobada y añadimos el importe de los tokens pagado para esta)
                unchecked{ //Es segura por el if de arriba
                    totalBudget += tokenPrice * tokens - budget;
                }
            }
        }
    }

    //Calcular el numero de tokens que puede comprar un participante en función de los ethers aportados
    function _calculateTokens(uint256 weis, address _participant) internal returns(uint){
        //Almacenar en memory para no acceder a storage numerosas veces
        uint _tokenPrice = tokenPrice;

        //Nº de tokens y cambio que le quedaría según lo pagado (no sabemos si son seguras por si tokenPrice es 0)
        uint tokens = weis / _tokenPrice;
        uint exchange = weis % _tokenPrice;
        uint oldExchange = participantExchange[_participant];

        //Comprobar con el antiguo cambio si puede recibir un token más
        if(exchange + oldExchange >= _tokenPrice){
            tokens += 1;
            unchecked{ //Por el if
                participantExchange[_participant] = exchange + oldExchange - _tokenPrice;
            }
        }
        else{
            unchecked{
                participantExchange[_participant] = exchange + oldExchange;
            }
        }

        return tokens;
    }
}