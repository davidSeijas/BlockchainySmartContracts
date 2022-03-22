// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.8.0;

contract piggyBank0 {
    function deposit() external payable{

    }
    
    function withdraw(uint amountInWei) external{
        require(address(this).balance > amountInWei, "No hay suficiente dinero en la hucha");
        payable(msg.sender).transfer(amountInWei);
    }

    function getBalance() external view returns (uint){
        return address(this).balance;
    }
}