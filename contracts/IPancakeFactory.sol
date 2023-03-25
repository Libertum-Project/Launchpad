// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.5.0;

interface IPancakeFactory {
    function createPair(address tokenA, address tokenB) external returns (address pair);

    //function setFeeTo(address) external;

    //function setFeeToSetter(address) external;

    //function INIT_CODE_PAIR_HASH() external view returns (bytes32);
}