// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.8.0;

contract piggyMapping {
    
    struct infoClient{
        string name;
        uint balance;
    }

    mapping(address => infoClient) clients;

    function addCliente(string memory name) external payable{
        require(bytes(name).length > 0, "Nombre vacio NO valido!");
        require(bytes(clients[msg.sender].name).length == 0, "El cliente ya existe");
        infoClient memory newClient = infoClient(name, msg.value);
        clients[msg.sender] = newClient;
    }

    //Ahora no necesitamos searchClient por usar mapping

    function deposit() external payable{
        require(bytes(clients[msg.sender].name).length > 0, "No puedes depositar dinero porque no estas registrado");
        clients[msg.sender].balance += msg.value;
    }
    
    function withdraw(uint amountInWei) external{
        require(bytes(clients[msg.sender].name).length > 0, "No puedes retirar dinero porque no estas registrado");
        require(clients[msg.sender].balance > amountInWei, "No tienes suficiente dinero en la hucha");
        clients[msg.sender].balance -= amountInWei;
        payable(msg.sender).transfer(amountInWei);
    }

    function getBalance() external view returns (uint){
        require(bytes(clients[msg.sender].name).length > 0, "No puedes consultar tu dinero porque no estas registrado");
        return clients[msg.sender].balance;
    }
}