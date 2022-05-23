// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

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
