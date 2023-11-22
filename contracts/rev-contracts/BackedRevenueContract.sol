// SPDX-License-Identifier: GPL-3.0
// Copyright: https://github.com/credit-cooperative/Line-Of-Credit/blob/master/COPYRIGHT.md

pragma solidity ^0.8.16;
import {Denominations} from "chainlink/Denominations.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {MutualConsent} from "../utils/MutualConsent.sol";

contract BackedRevenueContract  {

    event RedeemBackedTokens(address indexed user, uint256 amount);
    event BurnBackedTokens(address indexed user, uint256 amount);
    
    address public owner;
    IERC20 revenueToken;
    IERC20 backedToken;
    address burnAddress;

    constructor(address _owner, address token, address backed, address _burnAddress) {
        owner = _owner;
        revenueToken = IERC20(token);
        backedToken = IERC20(backed);
        burnAddress = _burnAddress;
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

    // user calls a function that sends their backed tokens to this address and emits an event

    function redeemBackedTokens(uint256 amount) external returns (bool) {
        require(backedToken.transfer(address(this), amount), "Revenue: bad transfer");
        emit RedeemBackedTokens(msg.sender, amount);
        return true;
    }

    function burnBackedTokens() external returns (bool) {
        require(backedToken.transfer(burnAddress, backedToken.balanceOf(address(this))), "Revenue: bad transfer");
        emit BurnBackedTokens(address(this), backedToken.balanceOf(address(this)));
        return true;
    }
}
