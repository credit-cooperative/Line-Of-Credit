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

contract OriginationFeeTest is Test, Events {
    SimpleOracle oracle;
    address borrower;
    address borrower2;
    address arbiter;
    address lender;
    address lender2;
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
        line.init();

        
        // assertEq(uint256(line.init()), uint256(LineLib.STATUS.ACTIVE));
        _mintAndApprove(address(line));
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
        supportedToken2.approve(loc, MAX_INT);
        unsupportedToken.approve(loc, MAX_INT);
        vm.stopPrank();
    }

    function _addCredit(address token, uint256 amount) public {
        vm.startPrank(borrower);
        line.addCredit(dRate, fRate, amount, token, lender);
        vm.stopPrank();
        vm.startPrank(lender);
        vm.expectEmit(false, true, true, false);
        emit Events.SetRates(bytes32(0), dRate, fRate);
        line.addCredit(dRate, fRate, amount, token, lender);
        vm.stopPrank();
    }

    function test_arbiter_and_borrower_set_fee() public {
        assertEq(line.orginiationFee(), 0);
        assertEq(line.count(), 0);

        vm.startPrank(borrower);
        line.setOriginationFee(5000);
        vm.stopPrank();

        vm.startPrank(arbiter);
        line.setOriginationFee(5000);
        vm.stopPrank();

        assertEq(line.orginiationFee(), 5000);
    }

    function test_arbiter_gets_fee() public {
        vm.startPrank(borrower);
        line.setOriginationFee(5000);
        vm.stopPrank();

        vm.startPrank(arbiter);
        line.setOriginationFee(5000);
        vm.stopPrank();

        _addCredit(address(supportedToken1), 100 ether);

        // check all the math :'(

        // check balance of line is 100 ether - fee
        // check balance of arbiter is fee amount

        //NOTE: How do i know what the fee is supposed to be?
    }

    function test_fee_adjusts_based_on_deadline() public {
        vm.startPrank(borrower);
        line.setOriginationFee(5000);
        vm.stopPrank();

        vm.startPrank(arbiter);
        line.setOriginationFee(5000);
        vm.stopPrank();

        _addCredit(address(supportedToken1), 100 ether);

        line2 = new LineOfCredit(address(oracle), arbiter, borrower, 200 days);
        line2.init();

        _mintAndApprove(address(line2));

        vm.startPrank(borrower);
        line2.setOriginationFee(5000);
        vm.stopPrank();

        vm.startPrank(arbiter);
        line2.setOriginationFee(5000);
        vm.stopPrank();

        _addCredit(address(supportedToken1), 100 ether);
        


    }
}