// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;
contract lab6ex5 {
    function maxMinMemory(uint[] memory arr) public pure returns (uint maxmin) {
        assembly{
            function fmaxmin (array_pointer) -> maxVal, minVal
                {
                    let len := mload(array_pointer)
                    let data := add(array_pointer, 0x20)
                    maxVal := mload(data)
                    minVal := mload(data)
                    let i := 1
                    for {} lt(i,len) {i:= add(i,1)}
                    {
                        let elem := mload(add(data,mul(i,0x20)))
                        if gt(elem,maxVal) { maxVal := elem }
                        if lt(elem,minVal) { minVal := elem }
                    }
                }
            
            let max, min := fmaxmin (arr)
            maxmin := sub(max,min)
        }
    }   
}
