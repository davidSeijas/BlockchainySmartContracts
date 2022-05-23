// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.4.0;
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
