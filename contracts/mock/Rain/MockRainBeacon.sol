// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.17;
import "openzeppelin/access/Ownable.sol";

contract MockRainBeacon is Ownable {

    constructor(address initialOwner) Ownable() {}
}