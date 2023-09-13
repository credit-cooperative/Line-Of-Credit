// SPDX-License-Identifier: GPL-3.0
// Copyright: https://github.com/credit-cooperative/Line-Of-Credit/blob/master/COPYRIGHT.md

 pragma solidity ^0.8.16;

import "openzeppelin/token/ERC20/ERC20.sol";

contract RevToken is ERC20{
    constructor(
        string memory name,
        string memory symbol
    )ERC20(name, symbol){

    }
    function mint(address account, uint256 amount) external returns(bool) {
        _mint(account, amount);
        return true;
    }

    function burnFrom(address account, uint256 amount) external returns(bool) {
        _burn(account, amount);
        return true;
    }

}