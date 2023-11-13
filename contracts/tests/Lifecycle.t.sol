// SPDX-License-Identifier: GPL-3.0
// Copyright: https://github.com/credit-cooperative/Line-Of-Credit/blob/master/COPYRIGHT.md

 pragma solidity ^0.8.16;

import "forge-std/Test.sol";
// TODO: Imports for development purpose only
import "forge-std/console.sol";


import { Denominations } from "chainlink/Denominations.sol";

import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";

import { Spigot } from "../modules/spigot/Spigot.sol";
import { Escrow } from "../modules/escrow/Escrow.sol";
import { SecuredLine } from "../modules/credit/SecuredLine.sol";
import { ILineOfCredit } from "../interfaces/ILineOfCredit.sol";
import { ISecuredLine } from "../interfaces/ISecuredLine.sol";
import { ISpigotedLine } from "../interfaces/ISpigotedLine.sol";
import { ISpigot } from "../interfaces/ISpigot.sol";
import { LineLib } from "../utils/LineLib.sol";
import { MutualConsent } from "../utils/MutualConsent.sol";

import { MockLine } from "../mock/MockLine.sol";
import { SimpleOracle } from "../mock/SimpleOracle.sol";
import { RevenueToken } from "../mock/RevenueToken.sol";
import { SimpleRevenueContract } from "../mock/SimpleRevenueContract.sol";

contract SecuredLineTest is Test {

    Escrow escrow;
    Spigot spigot;
    RevenueToken supportedToken1;
    RevenueToken supportedToken2;
    RevenueToken unsupportedToken;
    SimpleRevenueContract revenueContract;
    SimpleOracle oracle;
    SecuredLine line;
    uint mintAmount = 100 ether;
    uint MAX_INT = 115792089237316195423570985008687907853269984665640564039457584007913129639935;
    uint32 minCollateralRatio = 10000; // 100%
    uint128 dRate = 1500; // 15%
    uint128 fRate = 1500; // 15%
    uint ttl = 60 days;
    uint8 constant ownerSplit = 50; // 50% of all borrower revenue goes to spigot

    uint256 FULL_ALLOC = 100000;
    uint256 constant REVENUE_EARNED = 500 ether;

    address borrower;
    address arbiter;
    address lender;
    address externalLender;
    address _multisigAdmin;

    address[] beneficiaries;
    uint256[] allocations;
    uint256[] debtOwed;
    address[] creditTokens;

    function setUp() public {
        borrower = address(20);
        lender = address(10);
        externalLender = address(30);
        arbiter = address(this);
        _multisigAdmin = address(0xdead);

        supportedToken1 = new RevenueToken();
        supportedToken2 = new RevenueToken();
        unsupportedToken = new RevenueToken();

        revenueContract = new SimpleRevenueContract(borrower, address(supportedToken1));

        // 1. Configure Line of Credit
        // Deploy contracts
        console.log('Initial Timestamp: ', block.timestamp);
        spigot = new Spigot(address(this), borrower);
        oracle = new SimpleOracle(address(supportedToken1), address(supportedToken2));
        escrow = new Escrow(minCollateralRatio, address(oracle), arbiter, borrower, arbiter);

        // Initialize line
        // Transfer ownership of spigot and escrow to the line
        line = new SecuredLine(
          address(oracle),
          arbiter,
          borrower,
          payable(address(0)),
          address(spigot),
          address(escrow),
          60 days,
          0
        );

        allocations = new uint256[](2);
        allocations[0] = 50000;
        allocations[1] = 50000;

        debtOwed = new uint256[](2);
        debtOwed[0] = 0;
        debtOwed[1] = 102.5 ether;
        console.log('External Lender Debt: ', debtOwed[1]);

        creditTokens = new address[](2);
        creditTokens[0] = address(0);
        creditTokens[1] = address(supportedToken1);

        beneficiaries = new address[](2);
        beneficiaries[0] = address(line);
        beneficiaries[1] = externalLender;

        // Transfer ownership of spigot and escrow to the line
        escrow.updateLine(address(line));
        spigot.initialize(beneficiaries, allocations, debtOwed, creditTokens, arbiter);

        line.init();

        _mintAndApprove();
    }

    function _mintAndApprove() internal {
        deal(lender, mintAmount);

        supportedToken1.mint(borrower, mintAmount);
        supportedToken1.mint(lender, mintAmount);
        supportedToken2.mint(borrower, mintAmount);
        supportedToken2.mint(lender, mintAmount);
        unsupportedToken.mint(borrower, mintAmount);
        unsupportedToken.mint(lender, mintAmount);

        vm.startPrank(borrower);
        supportedToken1.approve(address(escrow), MAX_INT);
        supportedToken1.approve(address(line), MAX_INT);
        supportedToken2.approve(address(escrow), MAX_INT);
        supportedToken2.approve(address(line), MAX_INT);
        unsupportedToken.approve(address(escrow), MAX_INT);
        unsupportedToken.approve(address(line), MAX_INT);
        vm.stopPrank();

        vm.startPrank(lender);
        supportedToken1.approve(address(escrow), MAX_INT);
        supportedToken1.approve(address(line), MAX_INT);
        supportedToken2.approve(address(escrow), MAX_INT);
        supportedToken2.approve(address(line), MAX_INT);
        unsupportedToken.approve(address(escrow), MAX_INT);
        unsupportedToken.approve(address(line), MAX_INT);
        vm.stopPrank();

    }

    function _addCredit(address token, uint256 amount) public {
        vm.startPrank(borrower);
        line.addCredit(dRate, fRate, amount, token, lender);
        vm.stopPrank();
        vm.startPrank(lender);
        line.addCredit(dRate, fRate, amount, token, lender);
        vm.stopPrank();
    }

    // one Credit Coop lender (line)
    // one external lender (beneficiary)
    function test_full_repayment_lifecycle() public {

        // Line owns the Spigot and Escrow modules
        assertEq(address(line), spigot.owner());
        assertEq(address(line), escrow.line());

        // Line status is active
        assertEq(1, uint(line.status()));

        // Borrower transfers ownership of revenue contract to Spigot
        vm.startPrank(borrower);
        revenueContract.transferOwnership(address(spigot));
        vm.stopPrank();

        // Arbiter adds revenue contract to the Spigot and b
        ISpigot.Setting memory settings = ISpigot.Setting({
            ownerSplit: ownerSplit,
            claimFunction: SimpleRevenueContract.sendPushPayment.selector,
            // claimFunction: bytes4(0),
            transferOwnerFunction: SimpleRevenueContract.transferOwnership.selector
        });

        vm.startPrank(arbiter);
        line.addSpigot(address(revenueContract), settings);
        vm.stopPrank();

        // 2. Fund Line of Credit and Borrow
        // Lender proposes credit position
        // Borrower accepts credit position
        _addCredit(address(supportedToken1), 100 ether);

        // 3. Repay and Close Line of Credit
        vm.warp(block.timestamp + 59 days);
        console.log('Ending Timestamp: ', block.timestamp);
        (uint256 principal, uint256 interest) = line.updateOutstandingDebt();
        // TODO: why is principal 0?
        console.log('Credit Coop Lender Debt: ', principal + interest);

        // Revenue accrues to the Revenue contract
        deal(address(supportedToken1), address(revenueContract), REVENUE_EARNED);
        assertEq(REVENUE_EARNED, IERC20(supportedToken1).balanceOf(address(revenueContract)));
        console.log('Revenue Contract Balance: ', IERC20(supportedToken1).balanceOf(address(revenueContract)));
        // bytes memory claimData;
        // Arbiter claims revenue to the spigot
        spigot.claimRevenue(
            address(revenueContract),
            address(supportedToken1),
            // ""
            abi.encode(SimpleRevenueContract.sendPushPayment.selector)
        );

        console.log('Spigot Token Balance: ', IERC20(supportedToken1).balanceOf(address(spigot)));
        assertEq(IERC20(supportedToken1).balanceOf(address(spigot)), REVENUE_EARNED);

        // Arbiter distributes funds from the spigot to beneficiaries
        spigot.distributeFunds(address(supportedToken1));
        console.log('Spigot Token Balance 2: ', IERC20(supportedToken1).balanceOf(address(spigot)));

        // TODO: this isn't quite right - owner split should be 50% of claimed revenue
        // Beneficiary Debt is completely repaid and remainign balance goes to line
        // operator tokens = 500 * 0.5 (ownersplit) = 250
        // beneficiary tokens: 500 * 0.5 * 0.5 = 125 => 125 - 102.5 = 22.5 (leftover)
        // owner tokens: 500 * 0.5 * 0.5 = 125 => 125 + 22.5 = 147.5
        // total = 250 (operator) + 147.5 (owner) + 102.5 (beneficiary) = 500
        uint256 ownerTokens = spigot.getOwnerTokens(address(supportedToken1));
        uint256 operatorTokens = spigot.getOperatorTokens(address(supportedToken1));
        assertEq(ownerTokens, REVENUE_EARNED / ownerSplit);

        // Borrower closes line

        // Borrower sweeps unused funds?

        // Lender withdraws position
        // External Lender balance increases by 100 ether of supported token

        // 4. Borrower Amends / Extends Line of Credit
        // 5. Borrower/Arbiter updates spigot's beneficiary settings
        // 6. Repeat steps 2 - 3
        // 7. Borrower regains ownership of revenue contract

        // // attempting to update beneficiary settings fails because there is outstanding debt
        // vm.startPrank(lender);
        // vm.expectRevert(ILineOfCredit.CallerAccessDenied.selector);
        // line.updateBeneficiarySettings(newBeneficiaries, newOperators, newAllocations, newCreditTokens, newOutstandingDebts);
        // vm.stopPrank();

        // vm.startPrank(borrower);
        // line.updateBeneficiarySettings(newBeneficiaries, newOperators, newAllocations, newCreditTokens, newOutstandingDebts);
        // vm.stopPrank();




    }

    receive() external payable {}
}
