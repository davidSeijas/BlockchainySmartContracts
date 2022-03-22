// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.8.0;

contract piggyArray {
    
    struct infoClient{
        string name;
        uint balance;
        address addr;
    }

    infoClient[] clients;

    function addCliente(string memory name) external payable{
        require(bytes(name).length > 0, "Nombre vacio NO valido!");
        (bool exist, uint pos) = searchCliente(msg.sender);
        require(!exist, "El cliente ya existe");
        infoClient memory newClient = infoClient(name, msg.value, msg.sender);
        clients.push(newClient);
    }

    function searchCliente(address addr) internal view returns(bool, uint){
        bool exist = false;
        uint pos = 0;
        for (uint i = 0; i < clients.length && !exist; ++i){
            if(clients[i].addr == addr){
                exist = true;
                pos = i;
            }
        }

        return (exist, pos);
    }

    function deposit() external payable{
        (bool exist, uint pos) = searchCliente(msg.sender);
        require(exist, "No puedes depositar dinero porque no estas registrado");
        clients[pos].balance += msg.value;
    }
    
    function withdraw(uint amountInWei) external{
        (bool exist, uint pos) = searchCliente(msg.sender);
        require(exist, "No puedes retirar dinero porque no estas registrado");
        require(clients[pos].balance > amountInWei, "No tienes suficiente dinero en la hucha");
        clients[pos].balance -= amountInWei;
        payable(msg.sender).transfer(amountInWei);
    }

    function getBalance() external view returns (uint){
        (bool exist, uint pos) = searchCliente(msg.sender);
        require(exist, "No puedes consultar tu dinero porque no estas registrado");
        return clients[pos].balance;
    }
}