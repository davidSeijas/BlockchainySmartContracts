// SPDX-License-Identifier: GPL-3.0
//ALEJANDRO RAMÍRES Y DAVID SEIJAS
pragma solidity >=0.7.0 <0.9.0;

interface ERC721simplified {
    // EVENTS
    event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId);
    event Approval(address indexed _owner, address indexed _approved, uint256 indexed _tokenId);

    // APPROVAL FUNCTIONS
    function approve(address _approved, uint256 _tokenId) external payable;

    // TRANSFER FUNCTION
    function transferFrom(address _from, address _to, uint256 _tokenId) external payable;

    // VIEW FUNCTIONS (GETTERS)
    function balanceOf(address _owner) external view returns (uint256);
    function ownerOf(uint256 _tokenId) external view returns (address);
    function getApproved(uint256 _tokenId) external view returns (address);
}

library ArrayUtils {
    function contains(string[] storage arr, string memory val) external view returns(bool) {
        for (uint i = 0; i < arr.length; i++)
            if (keccak256(abi.encodePacked(arr[i])) == keccak256(abi.encodePacked(val)))
                return true;
        return false;
    }

    function increment(uint[] storage arr, uint8 per) external {
        for (uint i = 0; i < arr.length; i++)
            arr[i] += arr[i]*per;
    }

    function sum(uint[] storage arr) external view returns(uint) {
        uint suma = 0;
        for (uint i = 0; i < arr.length; i++)
            suma += arr[i];
        return suma;
    }
}

contract MonsterTokens is ERC721simplified{

    struct Weapons {
        string[] names; // name of the weapon
        uint[] firePowers; // capacity of the weapon
    }

    struct Character {
        string name; // character name
        Weapons weapons; // weapons assigned to this character
        address ownerToken; //propietario del personaje (token)
        address approvedOwnerToken; //direccion autorizada por Owner 
    }

    mapping(uint => Character) characters;
    address immutable owner;
    uint contToken = 10000;
    mapping(address => uint) n_tokens;

    constructor(){
        owner = msg.sender;
    }

    modifier onlyOwner{
        require(msg.sender == owner, "No eres el propietario, no tienes estos permisos");
        _;
    }

    modifier onlyPropietary(uint _tokenId){
        require(characters[_tokenId].ownerToken == msg.sender, "No eres propietario del token");
        _;
    }

    modifier onlyPropOrApproved(uint _tokenId){
        require(characters[_tokenId].ownerToken == msg.sender || characters[_tokenId].approvedOwnerToken == msg.sender, "No eres propietario del token ni estas autorizado");
        _;
    }

    function createMonsterToken(string memory _name, address _ownerToken) external onlyOwner returns(uint) {
        contToken += 1;
        characters[contToken] = Character(_name, Weapons(new string[](0), new uint[](0)), _ownerToken, address(0));
        n_tokens[_ownerToken] += 1;
        return contToken;
    }

    function addWeapon(uint _tokenId, string memory _nameWeapon, uint _powerWeapon) external onlyPropietary(_tokenId) {
        require(!ArrayUtils.contains(characters[_tokenId].weapons.names, _nameWeapon),"Ya tienes este arma");
        characters[_tokenId].weapons.names.push(_nameWeapon);
        characters[_tokenId].weapons.firePowers.push(_powerWeapon);
    }

    function incrementFirePower(uint _tokenId, uint8 _per) public {
        ArrayUtils.increment(characters[_tokenId].weapons.firePowers, _per);
    }

    function collectProfits() public onlyOwner{
        payable(msg.sender).transfer(address(this).balance);
    }

    function approve(address _approved, uint256 _tokenId) override external onlyPropietary(_tokenId) payable{
        require(msg.value >= ArrayUtils.sum(characters[_tokenId].weapons.firePowers), "Necesitas mas Weis para ejecutar esta funcion");
        characters[_tokenId].approvedOwnerToken = _approved;
        if(_approved != address(0)) //No mandamos approval en caso de haber revocado al aprobado anterior
            emit Approval(msg.sender, _approved, _tokenId);
    }

    function transferFrom(address from, address to, uint256 _tokenId) override external onlyPropOrApproved(_tokenId) payable{
        require(msg.value >= ArrayUtils.sum(characters[_tokenId].weapons.firePowers), "Necesitas mas Weis para ejecutar esta funcion");
        characters[_tokenId].ownerToken = to;
        characters[_tokenId].approvedOwnerToken = address(0);
        n_tokens[from] -= 1;
        n_tokens[to] += 1;
        emit Transfer(from, to, _tokenId);
    }

    function balanceOf(address _owner) override external view returns(uint256){
        return n_tokens[_owner];
    }

    function ownerOf(uint256 tokenId) override external view returns(address){
        require(characters[tokenId].ownerToken != address(0), "No existe el propietario de este token");
        return characters[tokenId].ownerToken;
    }

    function getApproved(uint256 tokenId) override external view returns(address){
        require(tokenId >= 10001 && tokenId <= contToken, "tokenId invalido");
        return characters[tokenId].approvedOwnerToken;
    }
}