// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

contract lab6ex6 {
    uint[] public arr;

    function generate(uint n) external {
        // Populates the array with some weird small numbers.
        bytes32 b = keccak256("seed");
        for (uint i = 0; i < n; i++) {
            uint8 number = uint8(b[i % 32]);
            arr.push(number);
        }
    }

    function maxMinStorage() public view returns (uint maxmin){
        assembly{
            function fmaxmin (slot) -> maxVal, minVal
                {
                    let len := sload(slot)
                    mstore(0x0, slot)
                    let data := keccak256(0x0, 0x20) 
                    //posicion de local memory donde tenemos el dato del que queremos calcular el hash y la longitud de la pos de memoria donde se guarda
                    maxVal := sload(data)
                    minVal := maxVal
                    let i := 1
                    for {} lt(i,len) {i:= add(i,1)}
                    {
                        let elem := sload(add(data,i)) //en storage la memorya va de 1 en 1
                        if gt(elem,maxVal) { maxVal := elem }
                        if lt(elem,minVal) { minVal := elem }
                    }
                }

            let max, min := fmaxmin (arr.slot)
            maxmin := sub(max,min)
        }
    }
}
