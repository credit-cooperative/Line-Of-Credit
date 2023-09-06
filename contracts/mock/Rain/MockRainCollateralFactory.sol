// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.17;
import "openzeppelin/access/Ownable.sol";

contract MockRainCollateralFactory is Ownable {

    constructor(address initialOwner) Ownable(initialOwner) {}
}