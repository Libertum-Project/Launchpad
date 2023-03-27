// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.5.0;

//BSC Testnet contract
//https://testnet.bscscan.com/address/0xb7926c0430afb07aa7defde6da862ae0bde767bc#code

interface IPancakeFactory {
    function createPair(address tokenA, address tokenB) external returns (address pair);

    //function setFeeTo(address) external;

    //function setFeeToSetter(address) external;

    //function INIT_CODE_PAIR_HASH() external view returns (bytes32);
}