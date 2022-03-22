// SPDX-License-Identifier: GPL-3.0
// ALEJANDRO RAMÍREZ Y DAVID SEIJAS
pragma solidity >=0.7.0 <0.9.0;

contract DhontElectionRegion{

    mapping(uint => uint) private weights;
    uint immutable regionId;
    uint[] internal results;

    constructor(uint _regionId, uint _nParties){
        regionId = _regionId;
        results = new uint[](_nParties);
        savedRegionInfo();
    }

    function savedRegionInfo() private{
        weights[28] = 1; // Madrid
        weights[8] = 1; // Barcelona
        weights[41] = 1; // Sevilla
        weights[44] = 5; // Teruel
        weights[42] = 5; // Soria
        weights[49] = 4; // Zamora
        weights[9] = 4; // Burgos
        weights[29] = 2; // Malaga
    }

    function registerVote(uint _party) internal returns(bool){
        if(_party >= 0 && _party < results.length){
            results[_party] += weights[regionId];
            return true;
        }
        else return false;
    }
}


abstract contract PollingStation{

    bool public votingFinish;
    bool private votingOpen;
    address immutable presidentDesk;

    modifier onlyPresident{
        require(msg.sender == presidentDesk, "No eres el presidente de la mesa. No tienes permitido esta accion.");
        _; 
    }

    modifier openVote{
        require(votingOpen, "La votacion no esta abierta. No puedes votar.");
        _;
    }

    constructor(address _presidentDesk){
        presidentDesk = _presidentDesk;
        votingFinish = false;
        votingOpen = false;
    }

    function openVoting() external onlyPresident{
        votingOpen = true;
    }

    function closeVoting() external onlyPresident{
        votingOpen = false;
        votingFinish = true;
    }

    function castVote(uint _party) external virtual;
    function getResults() external view virtual returns(uint[] memory);
}


contract DhontPollingStation is PollingStation, DhontElectionRegion{

    constructor(address _presidentDesk, uint _nParties, uint _regionId) 
    DhontElectionRegion(_regionId, _nParties) 
    PollingStation(_presidentDesk){}

    function castVote(uint _party) override external openVote{
        require(registerVote(_party), "El partido votado no es valido.");
    }

    function getResults() override external view returns(uint[] memory){
        return results;
    }
}


contract Election{

    mapping(uint => DhontPollingStation) mappingSedes;
    uint[] regions;
    uint immutable nParties;
    mapping(address => bool) votants;
    address owner;

    modifier onlyAuthority {
        require(msg.sender == owner, "Solo la autoridad administrativa tiene permiso para realizar esta accion.");
        _;
    }

    modifier freshId(uint regionId) {
        require(address(mappingSedes[regionId]) == address(0));
        _;
    }

    modifier validId(uint regionId) {
        require(address(mappingSedes[regionId]) !=  address(0));
        _;
    }

    constructor(uint _nParties){
        owner = msg.sender;
        nParties = _nParties;
    }

    function createPollingStation(uint _regionId, address _presidentDesk) external freshId(_regionId) onlyAuthority returns(address){
        DhontPollingStation ps = new DhontPollingStation(_presidentDesk, nParties, _regionId);
        mappingSedes[_regionId] = ps;
        regions.push(_regionId);
        return address(ps);
    }

    function castVote(uint _regionId, uint _party) external validId(_regionId){
        require(!votants[msg.sender], "Solo puedes votar 1 vez"); //No castigamos a los tramposos. Utilizando if else sin revert les supondría coste extra por intentar engañar.
        votants[msg.sender] = true;
        mappingSedes[_regionId].castVote(_party);
    }

    function getResults() external view onlyAuthority returns(uint[] memory){
        uint[] memory results = new uint[](nParties);
        for(uint i = 0; i < regions.length; ++i){
            if(!mappingSedes[regions[i]].votingFinish()){
                revert("No todas las sedes han acabado su votacion.");
            }
            else{
                uint[] memory res = mappingSedes[regions[i]].getResults();
                for(uint j = 0; j < res.length; ++j){
                    results[j] += res[j];
                }
            }
        }
        return results;
    }
}