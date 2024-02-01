// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.17;
import "openzeppelin/access/Ownable.sol";
import "./MockRainCollateral.sol";

contract MockRainCollateralFactory is Ownable {

    address public controller;

    constructor(address initialOwner, address _controller) Ownable(initialOwner) {
        controller = _controller;
    }

    function createCollateralContract(string calldata _name, address _user) external returns (address) {
        MockRainCollateral collateral = new MockRainCollateral(_user, address(this));
        return address(collateral);
    }
}