// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.17;


contract RainCollateralFactory {
    address public controller;

    constructor(address _controller) {
        controller = _controller;
    }
}