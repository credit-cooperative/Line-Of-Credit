// SPDX-License-Identifier: GPL-3.0
// Copyright: https://github.com/credit-cooperative/Line-Of-Credit/blob/master/COPYRIGHT.md

pragma solidity ^0.8.16;
import {Denominations} from "chainlink/Denominations.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {MutualConsent} from "../../utils/MutualConsent.sol";
import {ILineOfCredit} from "../credit/LineOfCredit.sol";

abstract contract Conduit  {

    event PushPayment(address indexed user, uint256 amount);

    address public owner;
    bool public isWhitelisted;
    address[] public whitelist;
    ILineOfCredit lineOfCredit;

    constructor(address _owner) {
        owner = _owner;
    }

    function setLineOfCredit(address _lineOfCredit) external returns (bool) {
        require(msg.sender == owner, "Revenue: Only owner can set line of credit");
        lineOfCredit = ILineOfCredit(_lineOfCredit);
        return true;
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
        emit PushPayment(owner, address(this).balance);

        // maybe call claim revenue here to update spigot accounting?
        return true;
    }

    function addCredit(
        uint128 drate,
        uint128 frate,
        uint256 amount,
        address token,
        address lender
    ) external returns (bool) {
        require(msg.sender == owner, "Revenue: Only owner can add credit");
        lineOfCredit.addCredit(drate, frate, amount, token, lender);
        return true;
    }

    function borrow() public returns (bool) {
        require(msg.sender == address(this), "Revenue: Only owner can borrow");
        uint256 usdValue = 0; // set that value here
        bytes32 id = 0; //
        lineOfCredit.borrow(id, usdValue);
        return true;
    }


    // user calls a function that sends their backed tokens to this address and emits an event

    function borrowTrigger(uint256 amount) internal virtual returns (bool) {
   
        return true;
    }


    // a function that the burner address calls to send the redeemed usdc back and then calls the pushpayment function
    function receiveUsdc(uint256 amount) external returns (bool) {
        require(revenueToken.transferFrom(msg.sender, address(this), amount), "Revenue: bad transfer");
        sendPushPayment();
        return true;
    }

}