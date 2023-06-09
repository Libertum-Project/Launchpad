// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract USDT is ERC20 {


    constructor() ERC20("USD Dollar Libertum v2", "USDTLv2"){
        mint(200);
    }

    function mint(uint amount) public {
        _mint(msg.sender, amount*1e18);
    }


}