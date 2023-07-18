// SPDX-License-Identifier: GPL-3.0
// Copyright: https://github.com/test-org2222/Line-Of-Credit/blog/master/COPYRIGHT.md

 pragma solidity ^0.8.16;
import {Denominations} from "chainlink/Denominations.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import { MutualUpgrade } from "./MutualUpgrade.sol";

contract SimpleRevenueContract {
    address owner;
    address manager;
    address methodologist;
    IERC20 revenueToken;
    mapping (address => uint256) public nonce;

    constructor(address _owner, address token) {
        owner = _owner;
        manager = _owner;
        methodologist = _owner;
        revenueToken = IERC20(token);
    }

    function claimPullPayment() external returns (bool) {
        require(msg.sender == owner, "Revenue: Only owner can claim");
        if (address(revenueToken) != Denominations.ETH) {
            require(revenueToken.transfer(owner, revenueToken.balanceOf(address(this))), "Revenue: bad transfer");
        } else {
            payable(owner).transfer(address(this).balance);
        }
        return true;
    }

    function sendPushPayment() external returns (bool) {
        if (address(revenueToken) != Denominations.ETH) {
            require(revenueToken.transfer(owner, revenueToken.balanceOf(address(this))), "Revenue: bad transfer");
        } else {
            payable(owner).transfer(address(this).balance);
        }
        return true;
    }

    function doAnOperationsThing() external returns (bool) {
        require(msg.sender == owner, "Revenue: Only owner can operate");
        return true;
    }

    function doAnOperationsThingWithArgs(uint256 val) external returns (bool) {
        require(val > 10, "too small");
        if (val % 2 == 0) return true;
        else return false;
    }

    function getOwner() external view returns (address) {
        return owner;
    }

    function getManager() external view returns (address) {
        return manager;
    }


    function getMethodologist() external view returns (address) {
        return manager;
    }

    function transferOwnership(address newOwner) external returns (bool) {
        require(msg.sender == owner, "Revenue: Only owner can transfer");
        owner = newOwner;
        return true;
    }

    function setMethodologist(address newMethodologist) external {
        require(msg.sender == methodologist, "Only methodologist can call");
        methodologist = newMethodologist;
    }

    function setManager(address newManager) external mutualUpgrade(manager, methodologist) {
        require(_newManager != address(0), "Zero address not valid");
        manager = newManager;
        return true;
    }

    function updateNonce(address _address, uint256 num) external {
        require(msg.sender == manager, "Only manager can call");
        nonce[_address] += num;
    }

    receive() external payable {}
}
