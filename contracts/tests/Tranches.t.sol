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
    SimpleRevenueContract revenueContract;
    SimpleRevenueContract revenueContract2;
    SimpleOracle oracle;
    SecuredLine line;
    uint mintAmount = 100 ether;
    uint MAX_INT = 115792089237316195423570985008687907853269984665640564039457584007913129639935;
    uint32 minCollateralRatio = 0; // 100%
    uint128 dRate = 1500; // 15%
    uint128 fRate = 1500; // 15%
    uint ttl = 60 days;
    uint8 constant ownerSplit = 100; // 100% of all borrower revenue goes to spigot

    uint256 FULL_ALLOC = 100000;
    uint256 constant REVENUE_EARNED = 500 ether;
    uint256 constant INSUFFICIENT_REVENUE_EARNED = 200 ether;

    address borrower;
    address borrower2;
    address arbiter;
    address lender1;
    address lender2;
    address lender3;
    address lender4;
    address lender5;
    address lender6;
    address externalLender;

    address[] beneficiaries;
    uint256[] allocations;
    uint256[] debtOwed;
    address[] creditTokens;

    function setUp() public {
        borrower = address(20);
        borrower2 = address(40);
        lender1 = address(10);
        lender2 = address(11);
        lender3 = address(12);
        lender4 = address(13);
        lender5 = address(14);
        lender6 = address(15);
        externalLender = address(30);
        arbiter = address(this);

        supportedToken1 = new RevenueToken();
        supportedToken2 = new RevenueToken();

        revenueContract = new SimpleRevenueContract(borrower, address(supportedToken1));
        revenueContract2 = new SimpleRevenueContract(borrower, address(supportedToken2));

        // 1. Configure Line of Credit
        // Deploy contracts
        console.log('\n First Cycle: ');
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

        allocations = new uint256[](1);
        allocations[0] = 100000;

        debtOwed = new uint256[](1);
        debtOwed[0] = 0;

        creditTokens = new address[](1);
        creditTokens[0] = address(0);

        beneficiaries = new address[](1);
        beneficiaries[0] = address(line);

        // Transfer ownership of spigot and escrow to the line
        escrow.updateLine(address(line));
        spigot.initialize(beneficiaries, allocations, debtOwed, creditTokens, arbiter);

        line.init();

        _mintAndApprove();
    }

    function _mintAndApprove() internal {
        deal(lender1, mintAmount);
        deal(lender2, mintAmount);
        deal(lender3, mintAmount);
        deal(lender4, mintAmount);

        supportedToken1.mint(borrower, mintAmount);
        supportedToken1.mint(lender1, mintAmount);
        supportedToken1.mint(lender2, mintAmount);
        supportedToken1.mint(lender3, mintAmount);
        supportedToken1.mint(lender4, mintAmount);
        supportedToken1.mint(lender5, mintAmount);
        supportedToken1.mint(lender6, mintAmount);
        supportedToken2.mint(borrower, mintAmount);
        supportedToken2.mint(lender1, mintAmount);
        supportedToken2.mint(lender2, mintAmount);
        supportedToken2.mint(lender3, mintAmount);
        supportedToken2.mint(lender4, mintAmount);
        supportedToken2.mint(lender5, mintAmount);
        supportedToken2.mint(lender6, mintAmount);

        vm.startPrank(borrower);
        supportedToken1.approve(address(escrow), MAX_INT);
        supportedToken1.approve(address(line), MAX_INT);
        supportedToken2.approve(address(escrow), MAX_INT);
        supportedToken2.approve(address(line), MAX_INT);
        vm.stopPrank();

        vm.startPrank(lender1);
        supportedToken1.approve(address(escrow), MAX_INT);
        supportedToken1.approve(address(line), MAX_INT);
        supportedToken2.approve(address(escrow), MAX_INT);
        supportedToken2.approve(address(line), MAX_INT);
        vm.stopPrank();

        vm.startPrank(lender2);
        supportedToken1.approve(address(escrow), MAX_INT);
        supportedToken1.approve(address(line), MAX_INT);
        supportedToken2.approve(address(escrow), MAX_INT);
        supportedToken2.approve(address(line), MAX_INT);
        vm.stopPrank();

        vm.startPrank(lender3);
        supportedToken1.approve(address(escrow), MAX_INT);
        supportedToken1.approve(address(line), MAX_INT);
        supportedToken2.approve(address(escrow), MAX_INT);
        supportedToken2.approve(address(line), MAX_INT);
        vm.stopPrank();

        vm.startPrank(lender4);
        supportedToken1.approve(address(escrow), MAX_INT);
        supportedToken1.approve(address(line), MAX_INT);
        supportedToken2.approve(address(escrow), MAX_INT);
        supportedToken2.approve(address(line), MAX_INT);
        vm.stopPrank();

        vm.startPrank(lender5);
        supportedToken1.approve(address(escrow), MAX_INT);
        supportedToken1.approve(address(line), MAX_INT);
        supportedToken2.approve(address(escrow), MAX_INT);
        supportedToken2.approve(address(line), MAX_INT);
        vm.stopPrank();

        vm.startPrank(lender6);
        supportedToken1.approve(address(escrow), MAX_INT);
        supportedToken1.approve(address(line), MAX_INT);
        supportedToken2.approve(address(escrow), MAX_INT);
        supportedToken2.approve(address(line), MAX_INT);
        vm.stopPrank();


    }

    function _addCredit(address token, uint256 amount, address lender, uint256 creditLimit) public {
        vm.startPrank(borrower);
        line.addCredit(dRate, fRate, amount, token, lender, creditLimit);
        vm.stopPrank();
        vm.startPrank(lender);
        line.addCredit(dRate, fRate, amount, token, lender, creditLimit);
        vm.stopPrank();
    }


    // TODO: test full repayment lifecycle with CC lender tranching plus beneficiaries

    // REALISTIC SCENARIO - single tranche with two CC lenders
    function test_full_repayment_lifecycle_w_single_tranche_one_credit_token() public {

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

        // create single tranche w/ two positions
        _addCredit(address(supportedToken1), 100 ether, lender1, 200 ether);
        _addCredit(address(supportedToken1), 100 ether, lender4, 0);

        emit log_named_bytes32('xxx - credit position 1: ', line.ids(0, 0));
        emit log_named_bytes32('xxx - credit position 2: ', line.ids(0, 1));
        console.log('\n');

        uint256 trancheLimit1 = line.tranches(0);
        emit log_named_uint('xxx - tranche 1 - credit limit: ', trancheLimit1);
        console.log('\n');

        assertEq(trancheLimit1, 200 ether);
        // TODO: fix this - assertEq(trancheSubscribedAmount1, 200 ether);

        // // Borrower borrows from both credit positions
        vm.startPrank(borrower);
        bytes32 creditPositionId1 = line.ids(0, 0);
        bytes32 creditPositionId2 = line.ids(0, 1);
        line.borrow(creditPositionId1, 100 ether, borrower);
        line.borrow(creditPositionId2, 100 ether, borrower);

        vm.stopPrank();

        // 3. Repay and Close Line of Credit
        vm.warp(block.timestamp + 365 days);
        console.log('Ending Timestamp: ', block.timestamp);

        // Revenue accrues to the Revenue contract
        deal(address(supportedToken1), address(revenueContract), REVENUE_EARNED);
        assertEq(REVENUE_EARNED, IERC20(supportedToken1).balanceOf(address(revenueContract)));

        // Arbiter claims revenue to the spigot
        spigot.claimRevenue(
            address(revenueContract),
            address(supportedToken1),
            abi.encode(SimpleRevenueContract.sendPushPayment.selector)
        );

        assertEq(IERC20(supportedToken1).balanceOf(address(spigot)), REVENUE_EARNED);

        // Arbiter distributes funds from the spigot to beneficiaries (only the line)
        spigot.distributeFunds(address(supportedToken1));
        // owner tokens: 500 * 1.0 * 1.0 = 500
        uint256 ownerTokens = spigot.getOwnerTokens(address(supportedToken1));
        assertEq(ownerTokens, REVENUE_EARNED / FULL_ALLOC * allocations[0]);

        // Arbiter fully repays tranche with funds from spigot and closes both credit positions
        vm.startPrank(arbiter);
        uint256 interestOwed = line.interestAccrued(creditPositionId1) + line.interestAccrued(creditPositionId2);
        line.claimAndRepay(address(supportedToken1), "");
        // Arbiter closes positions
        // line.close(creditPositionId1);
        // line.close(creditPositionId2);
        bytes32[] memory creditPositionsToClose = new bytes32[](2);
        creditPositionsToClose[0] = creditPositionId1;
        creditPositionsToClose[1] = creditPositionId2;
        line.closePositions(creditPositionsToClose);

        // line status is REPAID
        assertEq(3, uint(line.status()));
        vm.stopPrank();

        // Borrower sweeps line to get leftover tokens
        vm.startPrank(borrower);
        uint256 startingBorrowerBalance = IERC20(supportedToken1).balanceOf(borrower);
        line.sweep(borrower, address(supportedToken1), 0);
        uint256 endingBorrowerBalance = IERC20(supportedToken1).balanceOf(borrower);
        assertEq(endingBorrowerBalance - startingBorrowerBalance, ownerTokens - interestOwed - 200 ether);
        vm.stopPrank();
    }

    // REALISTIC SCENARIO - single tranche with two CC lenders
    function test_full_repayment_lifecycle_w_single_tranche_w_multiple_credit_tokens() public {

       // Line owns the Spigot and Escrow modules
        assertEq(address(line), spigot.owner());
        assertEq(address(line), escrow.line());

        // Line status is active
        assertEq(1, uint(line.status()));

        // Borrower transfers ownership of revenue contract to Spigot
        vm.startPrank(borrower);
        revenueContract.transferOwnership(address(spigot));
        revenueContract2.transferOwnership(address(spigot));
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
        line.addSpigot(address(revenueContract2), settings);
        vm.stopPrank();

        // 2. Fund Line of Credit and Borrow
        // Lender proposes credit position
        // Borrower accepts credit position

        // create single tranche w/ two positions
        _addCredit(address(supportedToken1), 100 ether, lender1, 30000000000000); // token price = 1000 USD
        _addCredit(address(supportedToken2), 100 ether, lender2, 0); // token price = 2000 USD

        emit log_named_bytes32('xxx - credit position 1: ', line.ids(0, 0));
        emit log_named_bytes32('xxx - credit position 2: ', line.ids(0, 1));
        // console.log('\n');

        uint256 trancheLimit1 = line.tranches(0);
        emit log_named_uint('xxx - tranche 1 - credit limit: ', trancheLimit1);
        console.log('\n');

        assertEq(trancheLimit1, 30000000000000);
        // TODO - fix this assertEq(trancheSubscribedAmount1, 200 ether);

        // Borrower borrows from both credit positions
        vm.startPrank(borrower);
        bytes32 creditPositionId1 = line.ids(0, 0);
        bytes32 creditPositionId2 = line.ids(0, 1);
        line.borrow(creditPositionId1, 100 ether, borrower);
        line.borrow(creditPositionId2, 100 ether, borrower);

        vm.stopPrank();

        // 3. Repay and Close Line of Credit
        vm.warp(block.timestamp + 365 days);
        console.log('Ending Timestamp: ', block.timestamp);

        // Revenue accrues to the Revenue contract
        deal(address(supportedToken1), address(revenueContract), REVENUE_EARNED / 4);
        deal(address(supportedToken2), address(revenueContract2), REVENUE_EARNED / 4);
        assertEq(REVENUE_EARNED / 4, IERC20(supportedToken1).balanceOf(address(revenueContract)));
        assertEq(REVENUE_EARNED / 4, IERC20(supportedToken2).balanceOf(address(revenueContract2)));

        // Arbiter claims revenue to the spigot
        spigot.claimRevenue(
            address(revenueContract),
            address(supportedToken1),
            abi.encode(SimpleRevenueContract.sendPushPayment.selector)
        );
        spigot.claimRevenue(
            address(revenueContract2),
            address(supportedToken2),
            abi.encode(SimpleRevenueContract.sendPushPayment.selector)
        );

        assertEq(IERC20(supportedToken1).balanceOf(address(spigot)), REVENUE_EARNED / 4);
        assertEq(IERC20(supportedToken2).balanceOf(address(spigot)), REVENUE_EARNED / 4);

        // Arbiter distributes funds from the spigot to beneficiaries (only the line)
        spigot.distributeFunds(address(supportedToken1));
        spigot.distributeFunds(address(supportedToken2));
        // owner tokens 1: 500 / 4 * 1.0 * 1.0 = 125
        uint256 ownerTokens1 = spigot.getOwnerTokens(address(supportedToken1));
        // owner tokens 2: 500 / 4 * 1.0 * 1.0 = 125
        uint256 ownerTokens2 = spigot.getOwnerTokens(address(supportedToken2));
        assertEq(ownerTokens1, REVENUE_EARNED / 4 / FULL_ALLOC * allocations[0]);
        // console.log('xxx - ownerTokens1: ', ownerTokens1);
        assertEq(ownerTokens2, REVENUE_EARNED / 4 / FULL_ALLOC * allocations[0]);

        // Arbiter fully repays tranche with funds from spigot and closes both credit positions
        vm.startPrank(arbiter);
        // line.claimAndRepay(address(supportedToken2), "");
        uint256 interestOwed1Before = line.interestAccrued(creditPositionId1);
        line.claimAndRepay(address(supportedToken1), "");
        uint256 interestOwed1After = line.interestAccrued(creditPositionId1);
        (, uint256 principal1,,,,,,,) = line.credits(creditPositionId1);
        console.log('xxx - interestOwed1Before: ', interestOwed1Before);
        console.log('xxx - interestOwed1After: ', interestOwed1After);
        console.log('xxx - principal1: ', principal1);
        emit log_named_bytes32('xxx - 1st credit position: ', line.ids(0, 0));

        uint256 interestOwed2Before = line.interestAccrued(creditPositionId2);
        line.claimAndRepay(address(supportedToken2), "");
        uint256 interestOwed2After = line.interestAccrued(creditPositionId2);
        (, uint256 principal2,,,,,,,) = line.credits(creditPositionId2);
        console.log('xxx - interestOwed2Before: ', interestOwed2Before);
        console.log('xxx - interestOwed2After: ', interestOwed2After);
        console.log('xxx - principal2: ', principal2);
        console.log('xxx - num active creidt positions after repayment: ', line.count());

        // Arbiter closes positions
        line.close(creditPositionId1);
        console.log('xxx - num active creidt positions - close 1: ', line.count());
        line.close(creditPositionId2);
        console.log('xxx - num active creidt positions - close 2: ', line.count());

        // credit positions are zero address in ids array
        // assertEq(bytes32(0), line.ids(0, 0));
        // emit log_named_bytes32('xxx - 1st credit position NULL: ', line.ids(0, 0));
        // assertEq(bytes32(0), line.ids(0, 1));
        // emit log_named_bytes32('xxx - 2nd credit position NULL: ', line.ids(0, 1));
        (uint256 numActivePositions, uint256 numTranches) = line.counts();

        // credit positions are removed from ids array
        assertEq(0, numActivePositions);
        assertEq(0, numTranches);
        console.log('ZZZ - num tranches: ', numTranches);

        // bytes32[] memory creditPositionsToClose = new bytes32[](2);
        // creditPositionsToClose[0] = creditPositionId1;
        // creditPositionsToClose[1] = creditPositionId2;
        // line.closePositions(creditPositionsToClose);

        // line status is REPAID
        assertEq(3, uint(line.status()));
        vm.stopPrank();

        // // Borrower sweeps line to get leftover tokens
        // vm.startPrank(borrower);
        // uint256 startingBorrowerBalance = IERC20(supportedToken1).balanceOf(borrower);
        // line.sweep(borrower, address(supportedToken1), 0);
        // uint256 endingBorrowerBalance = IERC20(supportedToken1).balanceOf(borrower);
        // assertEq(endingBorrowerBalance - startingBorrowerBalance, ownerTokens - interestOwed - 200 ether);
        // vm.stopPrank();

        // lender withdraws funds
        vm.startPrank(lender1);
        line.withdraw(creditPositionId1, 114 ether);
        vm.stopPrank();

        vm.startPrank(lender2);
        line.withdraw(creditPositionId2, 114 ether);
        vm.stopPrank();

        // extend the line
        vm.startPrank(borrower);
        line.extend(60 days);
        vm.stopPrank();

        // line status is ACTIVE
        assertEq(1, uint(line.status()));

        // create single tranche w/ two positions
        _addCredit(address(supportedToken1), 100 ether, lender1, 30000000000000); // token price = 1000 USD
        _addCredit(address(supportedToken2), 100 ether, lender2, 0); // token price = 2000 USD

        emit log_named_bytes32('xxx - credit position 1: ', line.ids(0, 0));
        emit log_named_bytes32('xxx - credit position 2: ', line.ids(0, 1));
        // // console.log('\n');

        trancheLimit1 = line.tranches(0);
        emit log_named_uint('xxx - tranche 1 - credit limit: ', trancheLimit1);
        console.log('\n');

        assertEq(trancheLimit1, 30000000000000);

        (numActivePositions, numTranches) = line.counts();
        assertEq(2, numActivePositions);
        assertEq(1, numTranches);
    }

   // REALISTIC SCENARIO - single tranche with two CC lenders
    function test_partial_repayment_lifecycle_w_single_tranche_one_credit_token() public {

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

        // create single tranche w/ two positions
        _addCredit(address(supportedToken1), 100 ether, lender1, 200 ether);
        _addCredit(address(supportedToken1), 100 ether, lender4, 0);

        emit log_named_bytes32('xxx - credit position 1: ', line.ids(0, 0));
        emit log_named_bytes32('xxx - credit position 2: ', line.ids(0, 1));
        console.log('\n');

        uint256 trancheLimit1 = line.tranches(0);
        emit log_named_uint('xxx - tranche 1 - credit limit: ', trancheLimit1);
        console.log('\n');

        assertEq(trancheLimit1, 200 ether);

        // // Borrower borrows from both credit positions
        vm.startPrank(borrower);
        bytes32 creditPositionId1 = line.ids(0, 0);
        bytes32 creditPositionId2 = line.ids(0, 1);
        line.borrow(creditPositionId1, 100 ether, borrower);
        line.borrow(creditPositionId2, 100 ether, borrower);

        vm.stopPrank();

        // 3. Repay and Close Line of Credit
        vm.warp(block.timestamp + 365 days);
        console.log('Ending Timestamp: ', block.timestamp);

        // Revenue accrues to the Revenue contract
        deal(address(supportedToken1), address(revenueContract), INSUFFICIENT_REVENUE_EARNED);
        assertEq(INSUFFICIENT_REVENUE_EARNED, IERC20(supportedToken1).balanceOf(address(revenueContract)));

        // Arbiter claims revenue to the spigot
        spigot.claimRevenue(
            address(revenueContract),
            address(supportedToken1),
            abi.encode(SimpleRevenueContract.sendPushPayment.selector)
        );

        assertEq(IERC20(supportedToken1).balanceOf(address(spigot)), INSUFFICIENT_REVENUE_EARNED);

        // Arbiter distributes funds from the spigot to beneficiaries (only the line)
        spigot.distributeFunds(address(supportedToken1));
        // owner tokens: 500 * 1.0 * 1.0 = 500
        uint256 ownerTokens = spigot.getOwnerTokens(address(supportedToken1));
        assertEq(ownerTokens, INSUFFICIENT_REVENUE_EARNED / FULL_ALLOC * allocations[0]);

        // Arbiter fully repays tranche with funds from spigot and closes both credit positions
        vm.startPrank(arbiter);
        uint256 interestAccrued1 = line.interestAccrued(creditPositionId1);
        uint256 interestAccrued2 = line.interestAccrued(creditPositionId2);
        line.claimAndRepay(address(supportedToken1), "");
        // All interest is repaid for both positions
        (uint256 deposit1, uint256 principal1,,,,,,,) = line.credits(creditPositionId1);
        (uint256 deposit2, uint256 principal2,,,,,,,) = line.credits(creditPositionId2);

        // Principal equivalent to the interest is still unpaid
        assertEq(interestAccrued1, principal1);
        assertEq(interestAccrued2, principal2);
        assertEq(1, uint(line.status()));
        vm.stopPrank();
    }

    // four Credit Coop lenders across two tranches
    function test_full_repayment_lifecycle_w_two_tranches_w_single_credit_token() public {

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

        // create first tranche when adding first position
        _addCredit(address(supportedToken1), 100 ether, lender1, 200 ether);

        // add another credit position to the newly created tranche
        _addCredit(address(supportedToken1), 100 ether, lender2, 0);

        // create a second tranche
        _addCredit(address(supportedToken1), 100 ether, lender3, 200 ether);
        _addCredit(address(supportedToken1), 100 ether, lender4, 0);

        emit log_named_bytes32('xxx - credit position 1: ', line.ids(0, 0));
        emit log_named_bytes32('xxx - credit position 2: ', line.ids(0, 1));
        emit log_named_bytes32('xxx - credit position 3: ', line.ids(1, 0));
        emit log_named_bytes32('xxx - credit position 4: ', line.ids(1, 1));

        uint256 trancheLimit1 = line.tranches(0);
        emit log_named_uint('xxx - tranche 1 - credit limit: ', trancheLimit1);
        // TODO: fix this - assertEq(trancheSubscribedAmount1, 200 ether);

        uint256 trancheLimit2 = line.tranches(1);
        emit log_named_uint('xxx - tranche 2 - credit limit: ', trancheLimit2);
        // TODO: fix this - assertEq(trancheSubscribedAmount2, 200 ether);

        // // Borrower borrows from all credit positions across both tranches
        vm.startPrank(borrower);
        bytes32 creditPositionId1 = line.ids(0, 0);
        bytes32 creditPositionId2 = line.ids(0, 1);
        bytes32 creditPositionId3 = line.ids(1, 0);
        bytes32 creditPositionId4 = line.ids(1, 1);
        line.borrow(creditPositionId1, 100 ether, borrower);
        line.borrow(creditPositionId2, 100 ether, borrower);
        line.borrow(creditPositionId3, 100 ether, borrower);
        line.borrow(creditPositionId4, 100 ether, borrower);
        vm.stopPrank();

        // 3. Repay and Close Line of Credit
        vm.warp(block.timestamp + 365 days);
        console.log('\nEnding Timestamp: ', block.timestamp);

        // Revenue accrues to the Revenue contract
        deal(address(supportedToken1), address(revenueContract), REVENUE_EARNED);
        assertEq(REVENUE_EARNED, IERC20(supportedToken1).balanceOf(address(revenueContract)));

        // Arbiter claims revenue to the spigot
        spigot.claimRevenue(
            address(revenueContract),
            address(supportedToken1),
            abi.encode(SimpleRevenueContract.sendPushPayment.selector)
        );

        assertEq(IERC20(supportedToken1).balanceOf(address(spigot)), REVENUE_EARNED);

        // Arbiter distributes funds from the spigot to beneficiaries (only the line)
        spigot.distributeFunds(address(supportedToken1));
        // owner tokens: 500 * 1.0 * 1.0 = 500
        // total = 250 (operator) + 147.5 (owner) + 102.5 (beneficiary) = 500
        uint256 ownerTokens = spigot.getOwnerTokens(address(supportedToken1));
        assertEq(ownerTokens, REVENUE_EARNED / FULL_ALLOC * allocations[0]);

        // Arbiter repays interestAccrued on both senior and junior tranche with funds
        // from spigot
        vm.startPrank(arbiter);
        // (,uint principal,,,,,,) = line.credits(line.ids(0, 0));
        uint256 interestAccrued1 = line.interestAccrued(line.ids(0, 0));
        uint256 interestAccrued2 = line.interestAccrued(line.ids(0, 1));
        uint256 interestAccrued3 = line.interestAccrued(line.ids(1, 0));
        uint256 interestAccrued4 = line.interestAccrued(line.ids(1, 1));
        uint256 interestOwed = interestAccrued1 + interestAccrued2 + interestAccrued3 + interestAccrued4;
        ownerTokens = spigot.getOwnerTokens(address(supportedToken1));

        // repay with useAndRepay
        uint256 tokensAvailable = line.claimAndTrade(address(supportedToken1), address(supportedToken1), "");
        console.log('xxx - tokensAvailable: ', tokensAvailable);
        line.useAndRepay(address(supportedToken1), tokensAvailable);

        // repay with claimAndRepay
        // line.claimAndRepay(address(supportedToken1), "");

        // line.close(creditPositionId1);
        // line.close(creditPositionId2);
        // line.close(creditPositionId3);
        // line.close(creditPositionId4);
        bytes32[] memory creditPositionsToClose = new bytes32[](4);
        creditPositionsToClose[0] = creditPositionId1;
        creditPositionsToClose[1] = creditPositionId2;
        creditPositionsToClose[2] = creditPositionId3;
        creditPositionsToClose[3] = creditPositionId4;
        line.closePositions(creditPositionsToClose);

        // line status is REPAID
        assertEq(3, uint(line.status()));

        vm.stopPrank();

        // Borrower sweeps line to get leftover tokens
        vm.startPrank(borrower);
        uint256 startingBorrowerBalance = IERC20(supportedToken1).balanceOf(borrower);
        line.sweep(borrower, address(supportedToken1), 0);
        uint256 endingBorrowerBalance = IERC20(supportedToken1).balanceOf(borrower);
        console.log('xxx - startingBorrowerBalance: ', startingBorrowerBalance);
        console.log('xxx - endingBorrowerBalance: ', endingBorrowerBalance);
        console.log('xxx - ownerTokens: ', ownerTokens);
        console.log('xxx - interestOwed: ', interestOwed);
        assertEq(endingBorrowerBalance - startingBorrowerBalance, ownerTokens - interestOwed - 400 ether);
        vm.stopPrank();

        // Arbiter repays principal for senior tranche

        // Arbiter repays principal for junior tranche

        // Arbiter closes positions

        // // Lender withdraws position
        // vm.startPrank(lender);
        // uint256 lenderBalanceBefore = IERC20(supportedToken1).balanceOf(lender);
        // line.withdraw(creditPositionId, principal + interestAccrued);
        // uint256 lenderBalanceAfter = IERC20(supportedToken1).balanceOf(lender);
        // // CC Lender balance increases by principal + interest
        // assertEq(lenderBalanceAfter - lenderBalanceBefore, principal + interestAccrued);
        // vm.stopPrank();

        // // Borrower sweeps all unused funds to borrower address
        // vm.startPrank(borrower);
        // uint256 tokensToBorrower =  ownerTokens - principal - interestAccrued;
        // uint256 borrowerBalanceBefore = IERC20(supportedToken1).balanceOf(borrower);
        // line.sweep(borrower, address(supportedToken1), 0);
        // uint256 borrowerBalanceAfter = IERC20(supportedToken1).balanceOf(borrower);
        // uint256 borrowerDiff = borrowerBalanceAfter - borrowerBalanceBefore;
        // assertEq(borrowerDiff, tokensToBorrower);
        // spigot.claimOperatorTokens(address(supportedToken1));
        // vm.stopPrank();

        // // 4. Borrower Amends / Extends Line of Credit
        // vm.startPrank(borrower);
        // // reset borrower address to borrower2
        // // add 60 days to the deadline
        // // send 100% of cash flows to the spigot
        // address[] memory revenueContracts = new address[](1);
        // revenueContracts[0] = address(revenueContract);
        // uint8[] memory ownerSplits = new uint8[](1);
        // ownerSplits[0] = 100;
        // uint256 oldDeadline = line.deadline();
        // // TODO: cannot update borrower!!! fix this
        // line.amendAndExtend(borrower, 60 days, 0, revenueContracts, ownerSplits);
        // assertEq(line.borrower(), borrower); // TODO: fix this!
        // assertEq(line.deadline(), oldDeadline + 60 days);
        // (uint256 newOwnerSplit,,) = spigot.getSetting(address(revenueContract));
        // assertEq(newOwnerSplit, 100);
        // // line status now ACTIVE
        // assertEq(1, uint256(line.status()));
        // vm.stopPrank();

        // // 5. Borrower/Arbiter updates spigot's beneficiary settings
        // vm.startPrank(arbiter);
        // line.updateBeneficiarySettings(beneficiaries, beneficiaries, allocations,creditTokens, debtOwed);
        // vm.stopPrank();

        // --------------------------------------- //
        // -------------- NEW CYCLE -------------- //
        // --------------------------------------- //

        // // 6. Repeat steps 2 - 3

        // console.log('\n Second Cycle: ');
        // console.log('Initial Timestamp - new cycle: ', block.timestamp);
        // // 2. Fund Line of Credit and Borrow
        // // Lender proposes credit position
        // // Borrower accepts credit position
        // _addCredit(address(supportedToken1), 100 ether);

        // // Borrower borrows from line
        // // TODO: what happens if lender did not withdraw from line before borrower/arbiter called amendAndExtend? Can the lender still withdraw the full amount from the credit position? Can the lender leave funds in the line and by calling addCredit use the funds already there?
        // vm.startPrank(borrower);
        // bytes32 creditPositionId2 = line.ids(0);
        // bytes32 id2 = line.ids(1);
        // line.borrow(creditPositionId2, 100 ether, borrower);
        // vm.stopPrank();

        // // 3. Repay and Close Line of Credit
        // vm.warp(block.timestamp + 59 days);
        // console.log('Ending Timestamp: ', block.timestamp);

        // // Revenue accrues to the Revenue contract
        // deal(address(supportedToken1), address(revenueContract), REVENUE_EARNED);
        // assertEq(REVENUE_EARNED, IERC20(supportedToken1).balanceOf(address(revenueContract)));
        // uint256 startingSpigotBalance = IERC20(supportedToken1).balanceOf(address(address(spigot)));
        // // Arbiter claims revenue to the spigot
        // spigot.claimRevenue(
        //     address(revenueContract),
        //     address(supportedToken1),
        //     abi.encode(SimpleRevenueContract.sendPushPayment.selector)
        // );
        // assertEq(IERC20(supportedToken1).balanceOf(address(spigot)) - startingSpigotBalance, REVENUE_EARNED);

        // // Arbiter distributes funds from the spigot to beneficiaries
        // uint256 elDebtOwed2 = debtOwed[1];
        // spigot.distributeFunds(address(supportedToken1));

        // // Beneficiary Debt is completely repaid and remainign balance goes to line
        // // operator tokens = 500 * 0 (ownersplit) = 0
        // // beneficiary tokens: 500 * 1.0 * 0.5 = 250 => 250 - 102.5 = 147.5 (leftover)
        // // owner tokens: 500 * 1.0 * 0.5 = 250 => 250 + 147.5 = 397.5
        // // total = 0 (operator) + 397.5 (owner) + 102.5 (beneficiary) = 500
        // uint256 ownerTokens2 = spigot.getOwnerTokens(address(supportedToken1));
        // uint256 operatorTokens2 = spigot.getOperatorTokens(address(supportedToken1));
        // uint256 externalLenderTokens2 = IERC20(address(supportedToken1)).balanceOf(externalLender) - elDebtOwed2;
        // uint256 excessTokens2 = REVENUE_EARNED / FULL_ALLOC * allocations[1] - elDebtOwed2;

        // // Each party receives expected tokens
        // assertEq(ownerTokens2, REVENUE_EARNED / FULL_ALLOC * allocations[0] + excessTokens2);
        // assertEq(operatorTokens2, 0);
        // assertEq(externalLenderTokens2, elDebtOwed2);

        // // External lender debt is repaid, allocation is set to zero
        // // External lender allocation is transferred to line
        // (, uint256 ownerAllocation2, , ) = spigot.getBeneficiaryBasicInfo(spigot.owner());
        // (, uint256 elAllocation2, , uint256 elNewDebtOwed2) = spigot.getBeneficiaryBasicInfo(externalLender);
        // assertEq(ownerAllocation2, 100000);
        // assertEq(elAllocation2, 0);
        // assertEq(elNewDebtOwed2, 0);

        // // Arbiter repays and closes line with spigot funds
        // vm.startPrank(arbiter);
        // (,uint256 principal2,,,,,,) = line.credits(creditPositionId2);
        // uint256 interestAccrued2 = line.interestAccrued(creditPositionId2);
        // line.claimAndRepay(address(supportedToken1), "");
        // line.close(creditPositionId2);
        // emit log_named_uint("line status", uint(line.status()));
        // // line status is REPAID
        // assertEq(3, uint(line.status()));
        // vm.stopPrank();

        // // Lender withdraws position
        // vm.startPrank(lender);
        // uint256 lenderBalanceBefore2 = IERC20(supportedToken1).balanceOf(lender);
        // line.withdraw(creditPositionId2, principal2 + interestAccrued2);
        // uint256 lenderBalanceAfter2 = IERC20(supportedToken1).balanceOf(lender);
        // // CC Lender balance increases by principal + interest
        // assertEq(lenderBalanceAfter2 - lenderBalanceBefore2, principal2 + interestAccrued2);
        // vm.stopPrank();

        // // Borrower sweeps all unused funds to borrower address
        // vm.startPrank(borrower);
        // uint256 tokensToBorrower2 =  ownerTokens2 - principal2 - interestAccrued2;
        // uint256 borrowerBalanceBefore2 = IERC20(supportedToken1).balanceOf(borrower);
        // line.sweep(borrower, address(supportedToken1), 0);
        // uint256 borrowerBalanceAfter2 = IERC20(supportedToken1).balanceOf(borrower);
        // uint256 borrowerDiff2 = borrowerBalanceAfter2 - borrowerBalanceBefore2;
        // assertEq(borrowerDiff2, tokensToBorrower2);
        // // spigot.claimOperatorTokens(address(supportedToken1));
        // vm.stopPrank();

        // // 7. Borrower regains ownership of revenue contract
        // vm.startPrank(borrower);
        // line.removeSpigot(address(revenueContract));
        // assertEq(borrower, revenueContract.owner());
        // vm.stopPrank();

    }

    // four Credit Coop lenders across two tranches
    function test_full_repayment_lifecycle_w_two_tranches_w_multiple_credit_tokens() public {

        // Line owns the Spigot and Escrow modules
        assertEq(address(line), spigot.owner());
        assertEq(address(line), escrow.line());

        // Line status is active
        assertEq(1, uint(line.status()));

        // Borrower transfers ownership of revenue contract to Spigot
        vm.startPrank(borrower);
        revenueContract.transferOwnership(address(spigot));
        revenueContract2.transferOwnership(address(spigot));
        vm.stopPrank();

        // Arbiter adds revenue contract to the Spigot and b
        ISpigot.Setting memory settings = ISpigot.Setting({
            ownerSplit: ownerSplit,
            claimFunction: SimpleRevenueContract.sendPushPayment.selector,
            transferOwnerFunction: SimpleRevenueContract.transferOwnership.selector
        });

        vm.startPrank(arbiter);
        line.addSpigot(address(revenueContract), settings);
        line.addSpigot(address(revenueContract2), settings);
        vm.stopPrank();

        // 2. Fund Line of Credit and Borrow
        // Lender proposes credit position
        // Borrower accepts credit position

        // create first tranche when adding first position
        _addCredit(address(supportedToken1), 100 ether, lender1, 200 ether);

        // add another credit position to the newly created tranche
        _addCredit(address(supportedToken2), 100 ether, lender2, 0);

        // create a second tranche
        _addCredit(address(supportedToken2), 100 ether, lender3, 200 ether);
        _addCredit(address(supportedToken1), 100 ether, lender4, 0);

        emit log_named_bytes32('xxx - credit position 1: ', line.ids(0, 0));
        emit log_named_bytes32('xxx - credit position 2: ', line.ids(0, 1));
        emit log_named_bytes32('xxx - credit position 3: ', line.ids(1, 0));
        emit log_named_bytes32('xxx - credit position 4: ', line.ids(1, 1));

        uint256 trancheLimit1 = line.tranches(0);
        emit log_named_uint('xxx - tranche 1 - credit limit: ', trancheLimit1);
        // TODO: fix this - assertEq(trancheSubscribedAmount1, 200 ether);

        uint256 trancheLimit2 = line.tranches(1);
        emit log_named_uint('xxx - tranche 2 - credit limit: ', trancheLimit2);
        // TODO: fix this - assertEq(trancheSubscribedAmount2, 200 ether);

        // Borrower borrows from all credit positions across both tranches
        vm.startPrank(borrower);
        bytes32 creditPositionId1 = line.ids(0, 0);
        bytes32 creditPositionId2 = line.ids(0, 1);
        bytes32 creditPositionId3 = line.ids(1, 0);
        bytes32 creditPositionId4 = line.ids(1, 1);
        line.borrow(creditPositionId1, 100 ether, borrower);
        line.borrow(creditPositionId2, 100 ether, borrower);
        line.borrow(creditPositionId3, 100 ether, borrower);
        line.borrow(creditPositionId4, 100 ether, borrower);
        vm.stopPrank();

        // 3. Repay and Close Line of Credit
        vm.warp(block.timestamp + 365 days);
        console.log('\nEnding Timestamp: ', block.timestamp);

        // Revenue accrues to the Revenue contract
        deal(address(supportedToken1), address(revenueContract), REVENUE_EARNED / 2);
        deal(address(supportedToken2), address(revenueContract2), REVENUE_EARNED / 2);
        assertEq(REVENUE_EARNED / 2, IERC20(supportedToken1).balanceOf(address(revenueContract)));
        assertEq(REVENUE_EARNED / 2, IERC20(supportedToken2).balanceOf(address(revenueContract2)));

        // Arbiter claims revenue to the spigot
        spigot.claimRevenue(
            address(revenueContract),
            address(supportedToken1),
            abi.encode(SimpleRevenueContract.sendPushPayment.selector)
        );
        spigot.claimRevenue(
            address(revenueContract2),
            address(supportedToken2),
            abi.encode(SimpleRevenueContract.sendPushPayment.selector)
        );

        assertEq(IERC20(supportedToken1).balanceOf(address(spigot)), REVENUE_EARNED / 2);
        assertEq(IERC20(supportedToken2).balanceOf(address(spigot)), REVENUE_EARNED / 2);

        // Arbiter distributes funds from the spigot to beneficiaries (only the line)
        spigot.distributeFunds(address(supportedToken1));
        spigot.distributeFunds(address(supportedToken2));
        // owner tokens 1: 250 * 1.0 * 1.0 = 250
        uint256 ownerTokens1 = spigot.getOwnerTokens(address(supportedToken1));
        assertEq(ownerTokens1, REVENUE_EARNED / 2 / FULL_ALLOC * allocations[0]);
        uint256 ownerTokens2 = spigot.getOwnerTokens(address(supportedToken2));
        assertEq(ownerTokens2, REVENUE_EARNED / 2 / FULL_ALLOC * allocations[0]);

        // Arbiter repays interestAccrued on both senior and junior tranche with funds
        // from spigot
        vm.startPrank(arbiter);
        // (,uint principal,,,,,,) = line.credits(line.ids(0, 0));
        uint256 interestAccrued1 = line.interestAccrued(line.ids(0, 0)) + line.interestAccrued(line.ids(1, 1));
        uint256 interestAccrued2 = line.interestAccrued(line.ids(0, 1)) + line.interestAccrued(line.ids(1, 0));
        ownerTokens1 = spigot.getOwnerTokens(address(supportedToken1));
        ownerTokens2 = spigot.getOwnerTokens(address(supportedToken2));

        // repay positions with supportedToken1 with claimAndRepay
        line.claimAndRepay(address(supportedToken1), "");

        // close positions for supportedToken1
        line.close(creditPositionId1);
        line.close(creditPositionId4);

        // repay positions with supportedToken2 with claimAndRepay
        line.claimAndRepay(address(supportedToken2), "");

        // close positions for supportedToken2
        line.close(creditPositionId2);
        line.close(creditPositionId3);

        (uint256 numActivePositions, uint256 numTranches) = line.counts();
        console.log('\n');
        console.log('ZZZ - numActivePositions: ', numActivePositions);
        console.log('ZZZ - numTranches: ', numTranches);
        console.log('\n');

        // // close positions in order
        // line.close(creditPositionId4);
        // line.close(creditPositionId3);
        // line.close(creditPositionId2);
        // line.close(creditPositionId1);

        // // line.close(creditPositionId4);
        // bytes32[] memory creditPositionsToClose = new bytes32[](4);
        // creditPositionsToClose[0] = creditPositionId1;
        // creditPositionsToClose[1] = creditPositionId2;
        // creditPositionsToClose[2] = creditPositionId3;
        // creditPositionsToClose[3] = creditPositionId4;
        // line.closePositions(creditPositionsToClose);

        // line status is REPAID
        assertEq(3, uint(line.status()));

        vm.stopPrank();

        // Borrower sweeps line to get leftover tokens
        vm.startPrank(borrower);
        uint256 startingBorrowerBalance1 = IERC20(supportedToken1).balanceOf(borrower);
        line.sweep(borrower, address(supportedToken1), 0);
        uint256 endingBorrowerBalance1 = IERC20(supportedToken1).balanceOf(borrower);
        console.log('xxx - startingBorrowerBalance1: ', startingBorrowerBalance1);
        console.log('xxx - endingBorrowerBalance1: ', endingBorrowerBalance1);
        console.log('xxx - ownerTokens1: ', ownerTokens1);
        console.log('xxx - interestAccrued1: ', interestAccrued1);
        assertEq(endingBorrowerBalance1 - startingBorrowerBalance1, ownerTokens1 - interestAccrued1 - 200 ether);
        console.log('xxx - endingBorrowerBalance1 - startingBorrowerBalance1: ', endingBorrowerBalance1 - startingBorrowerBalance1);

        uint256 startingBorrowerBalance2 = IERC20(supportedToken2).balanceOf(borrower);
        line.sweep(borrower, address(supportedToken2), 0);
        uint256 endingBorrowerBalance2 = IERC20(supportedToken2).balanceOf(borrower);
        console.log('xxx - startingBorrowerBalance2: ', startingBorrowerBalance2);
        console.log('xxx - endingBorrowerBalance2: ', endingBorrowerBalance2);
        console.log('xxx - ownerTokens2: ', ownerTokens2);
        console.log('xxx - interestAccrued2: ', interestAccrued2);
        assertEq(endingBorrowerBalance2 - startingBorrowerBalance2, ownerTokens2 - interestAccrued2 - 200 ether);
        console.log('xxx - endingBorrowerBalance2 - startingBorrowerBalance2: ', endingBorrowerBalance2 - startingBorrowerBalance2);
        vm.stopPrank();

        // lenders withdraw positions
        vm.startPrank(lender1);
        line.withdraw(creditPositionId1, 114 ether);
        vm.stopPrank();

        vm.startPrank(lender2);
        line.withdraw(creditPositionId2, 114 ether);
        vm.stopPrank();

        vm.startPrank(lender3);
        line.withdraw(creditPositionId3, 114 ether);
        vm.stopPrank();

        vm.startPrank(lender4);
        line.withdraw(creditPositionId4, 114 ether);
        vm.stopPrank();

        // extend the line
        vm.startPrank(borrower);
        line.extend(60 days);
        vm.stopPrank();

        // line status is ACTIVE
        assertEq(1, uint(line.status()));

        // create first tranche when adding first position
        _addCredit(address(supportedToken1), 100 ether, lender1, 200 ether);

        // add another credit position to the newly created tranche
        _addCredit(address(supportedToken2), 100 ether, lender2, 0);

        // create a second tranche
        _addCredit(address(supportedToken2), 100 ether, lender3, 200 ether);
        _addCredit(address(supportedToken1), 100 ether, lender4, 0);

        // emit log_named_bytes32('xxx - credit position 1: ', line.ids(0, 0));
        // emit log_named_bytes32('xxx - credit position 2: ', line.ids(0, 1));
        // emit log_named_bytes32('xxx - credit position 3: ', line.ids(1, 0));
        // emit log_named_bytes32('xxx - credit position 4: ', line.ids(1, 1));

        (numActivePositions, numTranches) = line.counts();
        assertEq(4, numActivePositions);
        assertEq(2, numTranches);
        // console.log('xxx - numActivePositions: ', numActivePositions);
        // console.log('xxx - numTranches: ', numTranches);

        // trancheLimit1 = line.tranches(0);
        // emit log_named_uint('xxx - tranche 1 - credit limit: ', trancheLimit1);

        // trancheLimit2 = line.tranches(1);
        // emit log_named_uint('xxx - tranche 2 - credit limit: ', trancheLimit2);

    }

    // four Credit Coop lenders across two tranches
    function test_full_repayment_lifecycle_w_three_tranches_w_multiple_credit_tokens() public {

        // Line owns the Spigot and Escrow modules
        assertEq(address(line), spigot.owner());
        assertEq(address(line), escrow.line());

        // Line status is active
        assertEq(1, uint(line.status()));

        // Borrower transfers ownership of revenue contract to Spigot
        vm.startPrank(borrower);
        revenueContract.transferOwnership(address(spigot));
        revenueContract2.transferOwnership(address(spigot));
        vm.stopPrank();

        // Arbiter adds revenue contract to the Spigot and b
        ISpigot.Setting memory settings = ISpigot.Setting({
            ownerSplit: ownerSplit,
            claimFunction: SimpleRevenueContract.sendPushPayment.selector,
            transferOwnerFunction: SimpleRevenueContract.transferOwnership.selector
        });

        vm.startPrank(arbiter);
        line.addSpigot(address(revenueContract), settings);
        line.addSpigot(address(revenueContract2), settings);
        vm.stopPrank();

        // 2. Fund Line of Credit and Borrow
        // Lender proposes credit position
        // Borrower accepts credit position

        // create first tranche when adding first position
        _addCredit(address(supportedToken1), 100 ether, lender1, 200 ether);

        // add another credit position to the newly created tranche
        _addCredit(address(supportedToken2), 100 ether, lender2, 0);

        // create a second tranche
        _addCredit(address(supportedToken2), 100 ether, lender3, 200 ether);
        _addCredit(address(supportedToken1), 100 ether, lender4, 0);

        // create a third tranche
        _addCredit(address(supportedToken1), 100 ether, lender5, 200 ether);
        _addCredit(address(supportedToken2), 100 ether, lender6, 0);

        // Borrower borrows from all credit positions across both tranches
        vm.startPrank(borrower);
        bytes32 creditPositionId1 = line.ids(0, 0);
        bytes32 creditPositionId2 = line.ids(0, 1);
        bytes32 creditPositionId3 = line.ids(1, 0);
        bytes32 creditPositionId4 = line.ids(1, 1);
        bytes32 creditPositionId5 = line.ids(2, 0);
        bytes32 creditPositionId6 = line.ids(2, 1);
        line.borrow(creditPositionId1, 100 ether, borrower);
        line.borrow(creditPositionId2, 100 ether, borrower);
        line.borrow(creditPositionId3, 100 ether, borrower);
        line.borrow(creditPositionId4, 100 ether, borrower);
        line.borrow(creditPositionId5, 100 ether, borrower);
        line.borrow(creditPositionId6, 100 ether, borrower);
        vm.stopPrank();

        // 3. Repay and Close Line of Credit
        vm.warp(block.timestamp + 365 days);
        console.log('\nEnding Timestamp: ', block.timestamp);

        // Revenue accrues to the Revenue contract
        deal(address(supportedToken1), address(revenueContract), REVENUE_EARNED);
        deal(address(supportedToken2), address(revenueContract2), REVENUE_EARNED);
        assertEq(REVENUE_EARNED, IERC20(supportedToken1).balanceOf(address(revenueContract)));
        assertEq(REVENUE_EARNED, IERC20(supportedToken2).balanceOf(address(revenueContract2)));

        // Arbiter claims revenue to the spigot
        spigot.claimRevenue(
            address(revenueContract),
            address(supportedToken1),
            abi.encode(SimpleRevenueContract.sendPushPayment.selector)
        );
        spigot.claimRevenue(
            address(revenueContract2),
            address(supportedToken2),
            abi.encode(SimpleRevenueContract.sendPushPayment.selector)
        );

        assertEq(IERC20(supportedToken1).balanceOf(address(spigot)), REVENUE_EARNED);
        assertEq(IERC20(supportedToken2).balanceOf(address(spigot)), REVENUE_EARNED);

        // Arbiter distributes funds from the spigot to beneficiaries (only the line)
        spigot.distributeFunds(address(supportedToken1));
        spigot.distributeFunds(address(supportedToken2));
        // owner tokens 1: 500 * 1.0 * 1.0 = 500
        uint256 ownerTokens1 = spigot.getOwnerTokens(address(supportedToken1));
        assertEq(ownerTokens1, REVENUE_EARNED / FULL_ALLOC * allocations[0]);
        uint256 ownerTokens2 = spigot.getOwnerTokens(address(supportedToken2));
        assertEq(ownerTokens2, REVENUE_EARNED / FULL_ALLOC * allocations[0]);

        // Arbiter repays interestAccrued on both senior and junior tranche with funds
        // from spigot
        vm.startPrank(arbiter);
        // (,uint principal,,,,,,) = line.credits(line.ids(0, 0));
        uint256 interestAccrued1 = line.interestAccrued(line.ids(0, 0)) + line.interestAccrued(line.ids(1, 1)) + line.interestAccrued(line.ids(2, 0));
        uint256 interestAccrued2 = line.interestAccrued(line.ids(0, 1)) + line.interestAccrued(line.ids(1, 0)) + line.interestAccrued(line.ids(2, 1));
        ownerTokens1 = spigot.getOwnerTokens(address(supportedToken1));
        ownerTokens2 = spigot.getOwnerTokens(address(supportedToken2));

        // repay positions with supportedToken1 and supportedToken2 with claimAndRepay
        line.claimAndRepay(address(supportedToken1), "");
        line.claimAndRepay(address(supportedToken2), "");

        (uint256 numActivePositions, uint256 numTranches) = line.counts();
        assertEq(6, numActivePositions);
        assertEq(3, numTranches);

        // close positions in 2nd tranche
        line.close(creditPositionId4);
        line.close(creditPositionId3);

        (numActivePositions, numTranches) = line.counts();
        assertEq(4, numActivePositions);
        assertEq(2, numTranches);

        // close positions in 1st tranche
        line.close(creditPositionId1);
        line.close(creditPositionId2);

        (numActivePositions, numTranches) = line.counts();
        assertEq(2, numActivePositions);
        assertEq(1, numTranches);

        // close positions in last tranche
        line.close(creditPositionId6);
        line.close(creditPositionId5);

        (numActivePositions, numTranches) = line.counts();
        assertEq(0, numActivePositions);
        assertEq(0, numTranches);

        // line status is REPAID
        assertEq(3, uint(line.status()));

        vm.stopPrank();

        // lenders withdraw positions
        vm.startPrank(lender1);
        line.withdraw(creditPositionId1, 114 ether);
        vm.stopPrank();

        vm.startPrank(lender2);
        line.withdraw(creditPositionId2, 114 ether);
        vm.stopPrank();

        vm.startPrank(lender3);
        line.withdraw(creditPositionId3, 114 ether);
        vm.stopPrank();

        vm.startPrank(lender4);
        line.withdraw(creditPositionId4, 114 ether);
        vm.stopPrank();

        vm.startPrank(lender5);
        line.withdraw(creditPositionId5, 114 ether);
        vm.stopPrank();

        vm.startPrank(lender6);
        line.withdraw(creditPositionId6, 114 ether);
        vm.stopPrank();

        // extend the line
        vm.startPrank(borrower);
        line.extend(60 days);
        vm.stopPrank();

        // line status is ACTIVE
        assertEq(1, uint(line.status()));

        // create first tranche when adding first position
        _addCredit(address(supportedToken1), 100 ether, lender1, 200 ether);

        // add another credit position to the newly created tranche
        _addCredit(address(supportedToken2), 100 ether, lender2, 0);

        (numActivePositions, numTranches) = line.counts();
        assertEq(2, numActivePositions);
        assertEq(1, numTranches);

        // create a second tranche
        _addCredit(address(supportedToken2), 100 ether, lender3, 200 ether);
        _addCredit(address(supportedToken1), 100 ether, lender4, 0);

        (numActivePositions, numTranches) = line.counts();
        assertEq(4, numActivePositions);
        assertEq(2, numTranches);

        // // emit log_named_bytes32('xxx - credit position 1: ', line.ids(0, 0));
        // // emit log_named_bytes32('xxx - credit position 2: ', line.ids(0, 1));
        // // emit log_named_bytes32('xxx - credit position 3: ', line.ids(1, 0));
        // // emit log_named_bytes32('xxx - credit position 4: ', line.ids(1, 1));

        // (numActivePositions, numTranches) = line.counts();
        // assertEq(4, numActivePositions);
        // assertEq(2, numTranches);
        // // console.log('xxx - numActivePositions: ', numActivePositions);
        // // console.log('xxx - numTranches: ', numTranches);

        // // trancheLimit1 = line.tranches(0);
        // // emit log_named_uint('xxx - tranche 1 - credit limit: ', trancheLimit1);

        // // trancheLimit2 = line.tranches(1);
        // // emit log_named_uint('xxx - tranche 2 - credit limit: ', trancheLimit2);

    }


    // four Credit Coop lenders across two tranches
    function test_partial_repayment_lifecycle_w_two_tranches() public {

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

        // create first tranche when adding first position
        _addCredit(address(supportedToken1), 100 ether, lender1, 200 ether);

        // add another credit position to the newly created tranche
        _addCredit(address(supportedToken1), 100 ether, lender2, 0);

        // create a second tranche
        _addCredit(address(supportedToken1), 100 ether, lender3, 200 ether);
        _addCredit(address(supportedToken1), 100 ether, lender4, 0);

        emit log_named_bytes32('\nxxx - credit position 1: ', line.ids(0, 0));
        emit log_named_bytes32('xxx - credit position 2: ', line.ids(0, 1));
        emit log_named_bytes32('xxx - credit position 3: ', line.ids(1, 0));
        emit log_named_bytes32('xxx - credit position 4: ', line.ids(1, 1));

        uint256 trancheLimit1 = line.tranches(0);
        emit log_named_uint('xxx - tranche 1 - credit limit: ', trancheLimit1);
        // TODO: fix this - assertEq(trancheSubscribedAmount1, 200 ether);

        uint256 trancheLimit2 = line.tranches(1);
        emit log_named_uint('xxx - tranche 2 - credit limit: ', trancheLimit2);
        // TODO: fix this - assertEq(trancheSubscribedAmount2, 200 ether);

        // // Borrower borrows from all credit positions across both tranches
        vm.startPrank(borrower);
        bytes32 creditPositionId1 = line.ids(0, 0);
        bytes32 creditPositionId2 = line.ids(0, 1);
        bytes32 creditPositionId3 = line.ids(1, 0);
        bytes32 creditPositionId4 = line.ids(1, 1);
        line.borrow(creditPositionId1, 100 ether, borrower);
        line.borrow(creditPositionId2, 100 ether, borrower);
        line.borrow(creditPositionId3, 100 ether, borrower);
        line.borrow(creditPositionId4, 100 ether, borrower);
        vm.stopPrank();

        // 3. Repay and Close Line of Credit
        vm.warp(block.timestamp + 365 days);
        console.log('\nEnding Timestamp: ', block.timestamp);

        // Revenue accrues to the Revenue contract
        deal(address(supportedToken1), address(revenueContract), 2 * INSUFFICIENT_REVENUE_EARNED);
        assertEq(2 * INSUFFICIENT_REVENUE_EARNED, IERC20(supportedToken1).balanceOf(address(revenueContract)));

        // Arbiter claims revenue to the spigot
        spigot.claimRevenue(
            address(revenueContract),
            address(supportedToken1),
            abi.encode(SimpleRevenueContract.sendPushPayment.selector)
        );

        assertEq(IERC20(supportedToken1).balanceOf(address(spigot)), 2 * INSUFFICIENT_REVENUE_EARNED);

        // Arbiter distributes funds from the spigot to beneficiaries (only the line)
        spigot.distributeFunds(address(supportedToken1));
        // owner tokens: 500 * 1.0 * 1.0 = 500
        // total = 250 (operator) + 147.5 (owner) + 102.5 (beneficiary) = 500
        uint256 ownerTokens = spigot.getOwnerTokens(address(supportedToken1));
        assertEq(ownerTokens, 2 * INSUFFICIENT_REVENUE_EARNED / FULL_ALLOC * allocations[0]);

        // Arbiter repays interestAccrued on both senior and junior tranche with funds
        // from spigot
        vm.startPrank(arbiter);
        // (,uint principal,,,,,,) = line.credits(line.ids(0, 0));
        uint256 interestAccrued1 = line.interestAccrued(creditPositionId1);
        uint256 interestAccrued2 = line.interestAccrued(creditPositionId2);
        uint256 interestAccrued3 = line.interestAccrued(creditPositionId3);
        uint256 interestAccrued4 = line.interestAccrued(creditPositionId4);
        uint256 interestOwed = interestAccrued1 + interestAccrued2 + interestAccrued3 + interestAccrued4;
        ownerTokens = spigot.getOwnerTokens(address(supportedToken1));
        line.claimAndRepay(address(supportedToken1), "");

        // interest accrued is repaid for all positions
        assertEq(0, line.interestAccrued(creditPositionId1));
        assertEq(0, line.interestAccrued(creditPositionId2));
        assertEq(0, line.interestAccrued(creditPositionId3));
        assertEq(0, line.interestAccrued(creditPositionId4));

        // senior tranche positions are repaid, but junior tranche is partially repaid
        (, uint256 principal1,,,,,,,) = line.credits(creditPositionId1);
        (, uint256 principal2,,,,,,,) = line.credits(creditPositionId2);
        (, uint256 principal3,,,,,,,) = line.credits(creditPositionId3);
        (, uint256 principal4,,,,,,,) = line.credits(creditPositionId4);

        // senior tranche
        assertEq(0, principal1);
        assertEq(0, principal2);

        // junior tranche
        assertEq(principal3, 100 ether - (2 * INSUFFICIENT_REVENUE_EARNED - interestOwed - 200 ether) / 2);
        assertEq(principal4, 100 ether - (2 * INSUFFICIENT_REVENUE_EARNED - interestOwed - 200 ether) / 2);

        // line status is ACTIVE
        assertEq(1, uint(line.status()));

        vm.stopPrank();

    }

    receive() external payable {}
}
