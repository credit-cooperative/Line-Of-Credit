// SPDX-License-Identifier: GPL-3.0
// Copyright: https://github.com/credit-cooperative/Line-Of-Credit/blob/master/COPYRIGHT.md

 pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {Denominations} from "chainlink/Denominations.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";

import {LineLib} from "../utils/LineLib.sol";
import {CreditLib} from "../utils/CreditLib.sol";
import {CreditListLib} from "../utils/CreditListLib.sol";
import {MutualConsent} from "../utils/MutualConsent.sol";
import {LineOfCredit} from "../modules/credit/LineOfCredit.sol";

import {Escrow} from "../modules/escrow/Escrow.sol";
import {EscrowLib} from "../utils/EscrowLib.sol";
import {IOracle} from "../interfaces/IOracle.sol";
import {ILineOfCredit} from "../interfaces/ILineOfCredit.sol";
import {RevenueToken} from "../mock/RevenueToken.sol";
import {SimpleOracle} from "../mock/SimpleOracle.sol";
import {ILendingPositionToken} from "../interfaces/ILendingPositionToken.sol";
import {LendingPositionToken} from "../modules/tokenized-positions/LendingPositionToken.sol";

interface Events {
    event Borrow(bytes32 indexed id, uint256 indexed amount, address indexed to);
    event MutualConsentRegistered(
        bytes32 _consentHash
    );
    event MutualConsentRevoked(bytes32 _toRevoke);
    event SetRates(
        bytes32 indexed id,
        uint128 indexed dRate,
        uint128 indexed fRate
    );
}

contract WithdrawalFeeTest is Test, Events {
    SimpleOracle oracle;
    address borrower;
    address borrower2;
    address arbiter;
    address lender;
    address lender2;
     address LPTAddress;

    uint256 ttl = 150 days;
    RevenueToken supportedToken1;
    RevenueToken supportedToken2;
    RevenueToken unsupportedToken;
    LineOfCredit line;
    LineOfCredit line2;
    uint256 mintAmount = 100 ether;
    uint256 MAX_INT =
        115792089237316195423570985008687907853269984665640564039457584007913129639935;
    uint256 minCollateralRatio = 1 ether; // 100%
    uint128 dRate = 100;
    uint128 fRate = 1;

    function setUp() public {
        borrower = address(10);
        borrower2 = address(11);
        arbiter = address(this);
        lender = address(20);
        lender2 = address(21);

        supportedToken1 = new RevenueToken();
        supportedToken2 = new RevenueToken();
        unsupportedToken = new RevenueToken();

        oracle = new SimpleOracle(
            address(supportedToken1),
            address(supportedToken2)
        );

        line = new LineOfCredit(address(oracle), arbiter, borrower, ttl);

        LPTAddress = address(_deployLendingPositionToken());
        line.initTokenizedPosition(LPTAddress);

        line.init();

        
        // assertEq(uint256(line.init()), uint256(LineLib.STATUS.ACTIVE));
        _mintAndApprove(address(line));
    }

    function _deployLendingPositionToken() internal returns (LendingPositionToken) {
        return new LendingPositionToken();
    }

    function _mintAndApprove(address loc) internal {
        deal(lender, mintAmount);

        supportedToken1.mint(borrower, mintAmount);
        supportedToken1.mint(lender, mintAmount);
        supportedToken2.mint(borrower, mintAmount);
        supportedToken2.mint(lender, mintAmount);
        unsupportedToken.mint(borrower, mintAmount);
        unsupportedToken.mint(lender, mintAmount);

        vm.startPrank(borrower);
        supportedToken1.approve(loc, MAX_INT);
        supportedToken2.approve(loc, MAX_INT);
        unsupportedToken.approve(loc, MAX_INT);
        vm.stopPrank();

        vm.startPrank(lender);
        supportedToken1.approve(loc, MAX_INT);
        supportedToken1.approve(borrower, MAX_INT);
        supportedToken2.approve(loc, MAX_INT);
        unsupportedToken.approve(loc, MAX_INT);
        vm.stopPrank();

        vm.startPrank(loc);
        supportedToken1.approve(borrower, MAX_INT);
        supportedToken1.approve(lender, MAX_INT);
        vm.stopPrank();
    }

    function _addCredit(address token, uint256 amount) public {
        vm.startPrank(borrower);
        line.addCredit(dRate, fRate, amount, token, lender, 50);
        vm.stopPrank();
        vm.startPrank(lender);
        vm.expectEmit(false, true, true, false);
        emit Events.SetRates(bytes32(0), dRate, fRate);
        line.addCredit(dRate, fRate, amount, token, lender, 50);
        vm.stopPrank();
    }

    function test_fee_set_correctly() public {
        _addCredit(address(supportedToken1), 100 ether);

        (,bytes32 id) = line.getPositionFromTokenId(1);
        (,,,,,,,uint128 withdrawalRate,) = line.credits(id);
        console.log(withdrawalRate);

        assertEq(withdrawalRate, 50);
    }

    function test_withdrawal_fee_if_now_is_less_than_deadline() public {
        _addCredit(address(supportedToken1), 100 ether);

        vm.warp(10 days);

        uint256 lenderBalanceBefore = supportedToken1.balanceOf(lender);
        uint256 borrowerBalanceBefore = supportedToken1.balanceOf(borrower);

        vm.startPrank(lender);
        line.withdraw(1, 100 ether);
        vm.stopPrank();

        uint256 lenderBalanceAfter = supportedToken1.balanceOf(lender);
        uint256 borrowerBalanceAfter = supportedToken1.balanceOf(borrower);

        assertLt(borrowerBalanceBefore, borrowerBalanceAfter);
        assertLt(lenderBalanceAfter, lenderBalanceBefore + 100 ether);

        
    }

    function test_no_withdrawal_fee_if_exactly_deadline() public {
        _addCredit(address(supportedToken1), 100 ether);

        vm.warp(150 days + 1 seconds);
  
        console.log("now",block.timestamp);
        console.log("deadline",line.deadline());
        uint256 lenderBalanceBefore = supportedToken1.balanceOf(lender);
        uint256 borrowerBalanceBefore = supportedToken1.balanceOf(borrower);

        vm.startPrank(lender);
        line.withdraw(1, 100 ether);
        vm.stopPrank();

        uint256 lenderBalanceAfter = supportedToken1.balanceOf(lender);
        uint256 borrowerBalanceAfter = supportedToken1.balanceOf(borrower);

        assertEq(borrowerBalanceBefore, borrowerBalanceAfter);
        assertEq(lenderBalanceAfter, lenderBalanceBefore + 100 ether);

    }

    function test_no_withdrawal_fee_if_past_deadline() public {
        _addCredit(address(supportedToken1), 100 ether);

        vm.warp(151 days);

        uint256 lenderBalanceBefore = supportedToken1.balanceOf(lender);
        uint256 borrowerBalanceBefore = supportedToken1.balanceOf(borrower);

        vm.startPrank(lender);

        line.withdraw(1, 100 ether);
        vm.stopPrank();

        uint256 lenderBalanceAfter = supportedToken1.balanceOf(lender);
        uint256 borrowerBalanceAfter = supportedToken1.balanceOf(borrower);

        assertEq(borrowerBalanceBefore, borrowerBalanceAfter);
        assertEq(lenderBalanceBefore + 100 ether, lenderBalanceAfter);

    }

    // (100000000000000000000 * 50) / (10000 * 315576000000) = 15844043907

    function test_math() public {
        _addCredit(address(supportedToken1), 100 ether);

        vm.warp(149 days);

        uint256 borrowerBalanceBefore = supportedToken1.balanceOf(borrower);

        vm.startPrank(lender);

        line.withdraw(1, 100 ether);
        vm.stopPrank();

        uint256 borrowerBalanceAfter = supportedToken1.balanceOf(borrower);

        uint256 fee = borrowerBalanceAfter - borrowerBalanceBefore;

        console.log("days in a year in seconds",365.25 days);
        console.log("ether with decimals",100 ether);
        console.log("fee calculated from balances",fee);

        assertEq(fee, 15844043907);
    }

    function test_lender_can_withdraw_interest_before_deadline_without_incurring_fee() public {
        _addCredit(address(supportedToken1), 100 ether);

        (,bytes32 id) = line.getPositionFromTokenId(1);

        vm.startPrank(borrower);
        line.borrow(id, 100 ether, borrower);
        vm.stopPrank();

        vm.warp(149 days);

        vm.startPrank(borrower);
        line.depositAndRepay(99 ether);
        vm.stopPrank();

        (,,,uint256 interestRepaid,,,,,) = line.credits(id);


        uint256 lenderBalanceBefore = supportedToken1.balanceOf(lender);
        uint256 borrowerBalanceBefore = supportedToken1.balanceOf(borrower);

        vm.startPrank(lender);
        line.withdraw(1, interestRepaid);
        vm.stopPrank();

        uint256 lenderBalanceAfter = supportedToken1.balanceOf(lender);
        uint256 borrowerBalanceAfter = supportedToken1.balanceOf(borrower);

        assertEq(borrowerBalanceBefore, borrowerBalanceAfter);

        assertEq(lenderBalanceAfter, lenderBalanceBefore + interestRepaid);

        console.log("interest repaid",interestRepaid);

    }

    function test_lender_can_withdraw_without_fee_if_line_repaid_before_deadline() public {
        _addCredit(address(supportedToken1), 100 ether);

        (,bytes32 id) = line.getPositionFromTokenId(1);

        vm.startPrank(borrower);
        line.borrow(id, 100 ether, borrower);
        vm.stopPrank();

        vm.warp(148 days);

        vm.startPrank(borrower);
        line.depositAndClose();
        vm.stopPrank();

        uint256 borrowerBalanceBefore = supportedToken1.balanceOf(borrower);
        uint256 lenderBalanceBefore = supportedToken1.balanceOf(lender);

        vm.startPrank(lender);
        line.withdraw(1, 100 ether);
        vm.stopPrank();

        uint256 borrowerBalanceAfter = supportedToken1.balanceOf(borrower);
        uint256 lenderBalanceAfter = supportedToken1.balanceOf(lender);

        assertEq(borrowerBalanceBefore, borrowerBalanceAfter);
        assertEq(lenderBalanceBefore + 100 ether, lenderBalanceAfter);
    }

}