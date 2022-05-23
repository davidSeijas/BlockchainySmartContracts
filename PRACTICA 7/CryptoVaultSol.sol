// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.6.0; // Do not change the compiler version.

/*
 * CryptoVault contract: A service for storing Ether.
 */
contract CryptoVaultSol {
    address public owner;      // Contract owner.
    uint prcFee;               // Percentage to be subtracted from deposited
                               // amounts to charge fees.
    uint public collectedFees; // Amount of this contract balance that
                               // corresponds to fees.
    mapping (address => uint256) public accounts;

    bool lock = false;         // Usamos lock para bloquear el contrato cuando podamos tener vulnerabilidades de reentrada

    modifier onlyOwner() {
        require(msg.sender == owner,"You are not the contract owner!");
        _;
    }

    // Constructor sets the owner of this contract using a VaultLib
    // library contract, and an initial value for prcFee.
    constructor(uint _prcFee) public {
        prcFee = _prcFee;
        owner = msg.sender; //Eliminamos la libreria y añadimos la funcionalidad de poner como owner el que crea el contrato
    }

    // getBalance returns the balance of this contract. 
    function getBalance() public view returns(uint){
        return address(this).balance;
    }

    // deposit allows clients to deposit amounts of Ether. A percentage
    // of the deposited amount is set aside as a fee for using this
    // vault. 
    function deposit() public payable{
        require (msg.value >= 100, "Insufficient deposit");
        uint fee = msg.value * prcFee / 100;
        accounts[msg.sender] += msg.value - fee;
        collectedFees += fee;
    }

    // withdraw allows clients to recover part of the amounts deposited
    // in this vault.
    function withdraw(uint _amount) public {
        require (accounts[msg.sender] >=  _amount, "Insufficient funds"); //Cambiamos la operación aritmetica para evitar el underflow y que no haya errores de "falsear" la cantidad a retirar y la disponible
        accounts[msg.sender] -= _amount;
        (bool sent, ) = msg.sender.call{value: _amount}("");
        require(sent, "Failed to send funds");
    }

    // withdrawAll is similar to withdraw, but withdrawing all Ether
    // deposited by a client.
    function withdrawAll() public {
        require(lock, "Contract locked"); //para ejecutar withdrawAll el contrato debe estar desbloqueado para no ejecutarlo varias veces antes de actualizar accounts
        uint amount = accounts[msg.sender];
        require (amount > 0, "Insufficient funds");
        lock = true; //bloqueamos el contrato cuando llamamos a call y lo desbloqueamos cuando hemos terminado para evitar llamadas continuas a msg.sender.call
        (bool sent, ) = msg.sender.call{value: amount}("");
        lock = false;
        require(sent, "Failed to send funds");
        accounts[msg.sender] = 0;
    }

    // collectFees is used by the contract owner to transfer all fees
    // collected from clients so far.
    function collectFees() public onlyOwner {
        require (collectedFees > 0, "No fees collected");
        (bool sent, ) = owner.call{value: collectedFees}("");
        require(sent, "Failed to send fees");
        collectedFees = 0;
    }

    // Any other function call is redirected to VaultLib library
    // functions. 
    fallback () external payable {
        revert("Calling a non-existent function!"); //Como en la libreria de antes, hacemos revert cuando llaman a funciones no definidas en el contrato
    }
    receive () external payable {
        revert("This contract does not accept transfers with empty call data"); //Como en la libreria de antes, hacemos revert cuando se intentan hacer transeferencias sin call data
    }
}

