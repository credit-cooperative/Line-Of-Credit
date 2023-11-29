// SPDX-License-Identifier: GPL-3.0
// Copyright: https://github.com/credit-cooperative/Line-Of-Credit/blob/master/COPYRIGHT.md

pragma solidity ^0.8.16;
import {Denominations} from "chainlink/Denominations.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {MutualConsent} from "../../utils/MutualConsent.sol";
import {ILineOfCredit} from "../credit/LineOfCredit.sol";
import {Conduit} from "./Conduit.sol";

contract BackedConduit is Conduit  {
    event RedeemBackedTokens(address indexed user, uint256 amount);
    event BurnBackedTokens(address indexed user, uint256 amount);

    IERC20 revenueToken;
    IERC20 backedToken;
    address burnAddress;

    constructor(address _owner, address token, address backed, address _burnAddress) Conduit(_owner) {
        revenueToken = IERC20(token);
        backedToken = IERC20(backed);
        burnAddress = _burnAddress;
    }

    // user calls a function that sends their backed tokens to this address and emits an event

    function borrowTrigger(uint256 amount) external override(Conduit) returns (bool) {
        require(backedToken.transfer(address(this), amount), "Revenue: bad transfer");
        emit RedeemBackedTokens(msg.sender, amount);
        // get usd value of tokens via chainlink
      
        // probably need to itterae through positions to see if there is enough credit to redeem
        // if there is, continue
        Conduit.borrow(id, usdValue);
        // transfer borrowed funds to msg.sender
        require(revenueToken.transfer(msg.sender, usdValue), "Revenue: bad transfer");
        // start burn process
        _burnBackedTokens();
        return true;
    }

    function _burnBackedTokens() internal returns (bool) {
        require(backedToken.transfer(burnAddress, backedToken.balanceOf(address(this))), "Revenue: bad transfer");
        emit BurnBackedTokens(address(this), backedToken.balanceOf(address(this)));
        return true;
    }

    // a function that the burner address calls to send the redeemed usdc back and then calls the pushpayment function
    function receiveUsdc(uint256 amount) external returns (bool) {
        require(revenueToken.transferFrom(msg.sender, address(this), amount), "Revenue: bad transfer");
        Conduit.sendPushPayment();
        return true;
    }

}
