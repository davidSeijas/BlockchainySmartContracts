// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.4.0;
contract lab6 {
    uint[] arr;
    uint sum;

    function generate(uint n) external {
        for (uint i = 0; i < n; i++) {
            arr.push(i*i);
        }
    }

    function computeSum() external {
        sum = 0;
        for (uint i = 0; i < arr.length; i++) {
            sum = sum + arr[i];
        }
    }
}

contract lab6_1 {
    uint[] arr;
    uint sum;

    function generate(uint n) external {
        for (uint i = 0; i < n; i++) {
            arr.push(i*i);
        }
    }

    function computeSum() external {
        uint auxvar = 0;
        uint lenarray = arr.length;
        for (uint i = 0; i < lenarray; i++) {
            auxvar = auxvar + arr[i];
        }
        sum = auxvar;
    }
}

contract lab6_2 {
    uint[] arr;
    uint sum;

    function generate(uint n) external {
        for (uint i = 0; i < n; i++) {
            arr.push(i*i);
        }
    }

    function computeSum() external {
        uint auxvar = 0;
        uint[] memory arrAux = arr;
        uint lenarray = arrAux.length;
        for (uint i = 0; i < lenarray; i++) {
            auxvar = auxvar + arrAux[i];
        }
        sum = auxvar;
    }
}

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

contract lab6ex7 {
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
        uint max = arr[0];
        uint min = max;
        for(uint i = 1; i < arr.length; ++i){
            if(arr[i] > max){ max = arr[i]; }
            if(arr[i] < min){ min = arr[i]; }
        }

        maxmin = max - min;
    }
}

contract lab6ex7_mej {
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
        uint max = arr[0];
        uint min = arr[0];
        uint len = arr.length;
        for(uint i = 1; i < len; ++i){
            uint elem = arr[i];
            if(elem > max){ max = elem; }
            if(elem < min){ min = elem; }
        }

        maxmin = max - min;
    }
}