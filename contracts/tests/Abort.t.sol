// SPDX-License-Identifier: GPL-3.0
// Copyright: https://github.com/credit-cooperative/Line-Of-Credit/blob/master/COPYRIGHT.md

 pragma solidity ^0.8.16;

import "forge-std/Test.sol";
// TODO: Imports for development purpose only
import "forge-std/console.sol";


import { Denominations } from "chainlink/Denominations.sol";

import { Spigot } from "../modules/spigot/Spigot.sol";
import { Escrow } from "../modules/escrow/Escrow.sol";
import { SecuredLine } from "../modules/credit/SecuredLine.sol";
import { ILineOfCredit } from "../interfaces/ILineOfCredit.sol";
import { ISecuredLine } from "../interfaces/ISecuredLine.sol";
import { ISpigotedLine } from "../interfaces/ISpigotedLine.sol";

import { LineLib } from "../utils/LineLib.sol";
import { MutualConsent } from "../utils/MutualConsent.sol";

import { MockLine } from "../mock/MockLine.sol";
import { ComplexOracle } from "../mock/ComplexOracle.sol";
import { RevenueToken } from "../mock/RevenueToken.sol";

contract AbortTest is Test {

    Escrow escrow;
    Spigot spigot;
    RevenueToken supportedToken1;
    RevenueToken supportedToken2;
    RevenueToken supportedToken3;
    RevenueToken supportedToken4;
    RevenueToken unsupportedToken;
    ComplexOracle oracle;
    SecuredLine line;
    uint mintAmount = 100 ether;
    uint MAX_INT = 115792089237316195423570985008687907853269984665640564039457584007913129639935;
    uint32 minCollateralRatio = 10000; // 100%
    uint128 dRate = 100;
    uint128 fRate = 1;
    uint ttl = 150 days;

    uint256 FULL_ALLOC = 100000;

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
        supportedToken3 = new RevenueToken();
        supportedToken4 = new RevenueToken();
        unsupportedToken = new RevenueToken();

        allocations = new uint256[](3);
        allocations[0] = 30000;
        allocations[1] = 50000;
        allocations[2] = 20000;

        debtOwed = new uint256[](3);
        debtOwed[0] = 0;
        debtOwed[1] = 0;
        debtOwed[2] = 0;

        creditTokens = new address[](3);
        creditTokens[0] = address(supportedToken1);
        creditTokens[1] = address(supportedToken1);
        creditTokens[2] = address(supportedToken1);

        spigot = new Spigot(address(this), borrower);
        oracle = new ComplexOracle(address(supportedToken1), address(supportedToken2), address(supportedToken3), address(supportedToken4));

        escrow = new Escrow(minCollateralRatio, address(oracle), arbiter, borrower, arbiter);

        line = new SecuredLine(
          address(oracle),
          arbiter,
          borrower,
          payable(address(0)),
          address(spigot),
          address(escrow),
          150 days,
          0
        );

        beneficiaries = new address[](3);
        beneficiaries[0] = address(line);
        beneficiaries[1] = lender;
        beneficiaries[2] = externalLender;

        escrow.updateLine(address(line));
        spigot.initialize(beneficiaries, allocations, debtOwed, creditTokens, arbiter);

        line.init();
        // assertEq(uint(line.init()), uint(LineLib.STATUS.ACTIVE));

        _mintAndApprove();
        escrow.enableCollateral( address(supportedToken1));
        escrow.enableCollateral( address(supportedToken2));

        vm.startPrank(borrower);
        escrow.addCollateral(1 ether, address(supportedToken1));
        escrow.addCollateral(1 ether, address(supportedToken2));
        vm.stopPrank();
    }

    function _mintAndApprove() internal {
        deal(lender, mintAmount);

        supportedToken1.mint(borrower, mintAmount);
        supportedToken1.mint(lender, mintAmount);
        supportedToken2.mint(borrower, mintAmount);
        supportedToken2.mint(lender, mintAmount);
        supportedToken3.mint(borrower, mintAmount);
        supportedToken3.mint(lender, mintAmount);
        supportedToken4.mint(borrower, mintAmount);
        supportedToken4.mint(lender, mintAmount);
        unsupportedToken.mint(borrower, mintAmount);
        unsupportedToken.mint(lender, mintAmount);

        vm.startPrank(borrower);
        supportedToken1.approve(address(escrow), MAX_INT);
        supportedToken1.approve(address(line), MAX_INT);
        supportedToken2.approve(address(escrow), MAX_INT);
        supportedToken2.approve(address(line), MAX_INT);
        supportedToken3.approve(address(escrow), MAX_INT);
        supportedToken3.approve(address(line), MAX_INT);
        supportedToken4.approve(address(escrow), MAX_INT);
        supportedToken4.approve(address(line), MAX_INT);
        unsupportedToken.approve(address(escrow), MAX_INT);
        unsupportedToken.approve(address(line), MAX_INT);
        vm.stopPrank();

        vm.startPrank(lender);
        supportedToken1.approve(address(escrow), MAX_INT);
        supportedToken1.approve(address(line), MAX_INT);
        supportedToken2.approve(address(escrow), MAX_INT);
        supportedToken2.approve(address(line), MAX_INT);
        supportedToken3.approve(address(escrow), MAX_INT);
        supportedToken3.approve(address(line), MAX_INT);
        supportedToken4.approve(address(escrow), MAX_INT);
        supportedToken4.approve(address(line), MAX_INT);
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

    function test_can_abort() public {
        _addCredit(address(supportedToken3), 1 ether);
        _addCredit(address(supportedToken4), 1 ether);

        // an array of addresses to run abort on
        address[] memory tokens = new address[](2);
        tokens[0] = address(supportedToken1);
        tokens[1] = address(supportedToken2);

        vm.startPrank(borrower);
        line.recoverEscrowTokensAndSpigotedContracts(tokens);
        vm.stopPrank();

        vm.startPrank(arbiter);
        line.recoverEscrowTokensAndSpigotedContracts(tokens);
        vm.stopPrank();

        assertEq(uint(line.status()), uint(LineLib.STATUS.ABORTED));

        assertEq(supportedToken1.balanceOf(address(arbiter)), 1 ether);

        assertEq(supportedToken2.balanceOf(address(arbiter)), 1 ether);

        // check ownership of spigot
        assertEq(spigot.owner(), arbiter);

        // withdraw abort functtion
        // an array of tokens that have been added via addCredit
        address[] memory tokens2 = new address[](2);
        tokens2[0] = address(supportedToken3);
        tokens2[1] = address(supportedToken4);
        vm.startPrank(arbiter);
        line.recoverTokens(tokens2);
        vm.stopPrank();

        assertEq(supportedToken3.balanceOf(address(arbiter)), 1 ether);
        assertEq(supportedToken4.balanceOf(address(arbiter)), 1 ether);

    }

    function test_can_abort_only_spigot() public{
        _addCredit(address(supportedToken3), 1 ether);
        _addCredit(address(supportedToken4), 1 ether);


        vm.startPrank(borrower);
        line.recoverSpigotedContracts();
        vm.stopPrank();

        vm.startPrank(arbiter);
        line.recoverSpigotedContracts();
        vm.stopPrank();

        assertEq(uint(line.status()), uint(LineLib.STATUS.ABORTED));

        // check ownership of spigot
        assertEq(spigot.owner(), arbiter);

        // withdraw abort functtion
        // an array of tokens that have been added via addCredit
        address[] memory tokens2 = new address[](2);
        tokens2[0] = address(supportedToken3);
        tokens2[1] = address(supportedToken4);
        vm.startPrank(arbiter);
        line.recoverTokens(tokens2);
        vm.stopPrank();

        assertEq(supportedToken3.balanceOf(address(arbiter)), 1 ether);
        assertEq(supportedToken4.balanceOf(address(arbiter)), 1 ether);
    }

    function test_can_abort_only_escrow() public{
        _addCredit(address(supportedToken3), 1 ether);
        _addCredit(address(supportedToken4), 1 ether);

        // an array of addresses to run abort on
        address[] memory tokens = new address[](2);
        tokens[0] = address(supportedToken1);
        tokens[1] = address(supportedToken2);

        vm.startPrank(borrower);
        line.recoverEscrowTokens(tokens);
        vm.stopPrank();

        vm.startPrank(arbiter);
        line.recoverEscrowTokens(tokens);
        vm.stopPrank();

        assertEq(uint(line.status()), uint(LineLib.STATUS.ABORTED));

        assertEq(supportedToken1.balanceOf(address(arbiter)), 1 ether);

        assertEq(supportedToken2.balanceOf(address(arbiter)), 1 ether);

        // withdraw abort functtion
        // an array of tokens that have been added via addCredit
        address[] memory tokens2 = new address[](2);
        tokens2[0] = address(supportedToken3);
        tokens2[1] = address(supportedToken4);
        vm.startPrank(arbiter);
        line.recoverTokens(tokens2);
        vm.stopPrank();

        assertEq(supportedToken3.balanceOf(address(arbiter)), 1 ether);
        assertEq(supportedToken4.balanceOf(address(arbiter)), 1 ether);
    }

    function test_cannot_add_credit_if_escrow_aborted() public {
        _addCredit(address(supportedToken3), 1 ether);
        _addCredit(address(supportedToken4), 1 ether);


        vm.startPrank(borrower);
        line.recoverSpigotedContracts();
        vm.stopPrank();

        vm.startPrank(arbiter);
        line.recoverSpigotedContracts();
        vm.stopPrank();

        assertEq(uint(line.status()), uint(LineLib.STATUS.ABORTED));

        // check ownership of spigot
        assertEq(spigot.owner(), arbiter);

        // withdraw abort functtion
        // an array of tokens that have been added via addCredit
        address[] memory tokens2 = new address[](2);
        tokens2[0] = address(supportedToken3);
        tokens2[1] = address(supportedToken4);
        vm.startPrank(arbiter);
        line.recoverTokens(tokens2);
        vm.stopPrank();

        assertEq(supportedToken3.balanceOf(address(arbiter)), 1 ether);
        assertEq(supportedToken4.balanceOf(address(arbiter)), 1 ether);

        // try to add credit
        vm.startPrank(borrower);
        vm.expectRevert(ILineOfCredit.NotActive.selector);
        line.addCredit(dRate, fRate, 1 ether, address(supportedToken3), lender);
        vm.stopPrank();

        assertEq(uint(line.status()), uint(LineLib.STATUS.ABORTED));

    }

    function test_cannot_add_credit_if_spigot_aborted() public {
        _addCredit(address(supportedToken3), 1 ether);
        _addCredit(address(supportedToken4), 1 ether);


        vm.startPrank(borrower);
        line.recoverSpigotedContracts();
        vm.stopPrank();

        vm.startPrank(arbiter);
        line.recoverSpigotedContracts();
        vm.stopPrank();

        assertEq(uint(line.status()), uint(LineLib.STATUS.ABORTED));

        // check ownership of spigot
        assertEq(spigot.owner(), arbiter);

        // withdraw abort functtion
        // an array of tokens that have been added via addCredit
        address[] memory tokens2 = new address[](2);
        tokens2[0] = address(supportedToken3);
        tokens2[1] = address(supportedToken4);
        vm.startPrank(arbiter);
        line.recoverTokens(tokens2);
        vm.stopPrank();

        assertEq(supportedToken3.balanceOf(address(arbiter)), 1 ether);
        assertEq(supportedToken4.balanceOf(address(arbiter)), 1 ether);

        // try to add credit
        vm.startPrank(borrower);
        vm.expectRevert(ILineOfCredit.NotActive.selector);
        line.addCredit(dRate, fRate, 1 ether, address(supportedToken3), lender);
        vm.stopPrank();

        vm.startPrank(lender);
        vm.expectRevert(ILineOfCredit.NotActive.selector);
        line.addCredit(dRate, fRate, 1 ether, address(supportedToken3), lender);
        vm.stopPrank();
    }

    function test_cannot_add_credit_if_aborted() public {
        _addCredit(address(supportedToken3), 1 ether);
        _addCredit(address(supportedToken4), 1 ether);

        // an array of addresses to run abort on
        address[] memory tokens = new address[](2);
        tokens[0] = address(supportedToken1);
        tokens[1] = address(supportedToken2);

        vm.startPrank(borrower);
        line.recoverEscrowTokensAndSpigotedContracts(tokens);
        vm.stopPrank();

        vm.startPrank(arbiter);
        line.recoverEscrowTokensAndSpigotedContracts(tokens);
        vm.stopPrank();

        assertEq(uint(line.status()), uint(LineLib.STATUS.ABORTED));

        assertEq(supportedToken1.balanceOf(address(arbiter)), 1 ether);

        assertEq(supportedToken2.balanceOf(address(arbiter)), 1 ether);

        // check ownership of spigot
        assertEq(spigot.owner(), arbiter);

        // withdraw abort functtion
        // an array of tokens that have been added via addCredit
        address[] memory tokens2 = new address[](2);
        tokens2[0] = address(supportedToken3);
        tokens2[1] = address(supportedToken4);
        vm.startPrank(arbiter);
        line.recoverTokens(tokens2);
        vm.stopPrank();

        assertEq(supportedToken3.balanceOf(address(arbiter)), 1 ether);
        assertEq(supportedToken4.balanceOf(address(arbiter)), 1 ether);

        // try to add credit

        vm.startPrank(borrower);
        vm.expectRevert(ILineOfCredit.NotActive.selector);
        line.addCredit(dRate, fRate, 1 ether, address(supportedToken3), lender);
        vm.stopPrank();

        vm.startPrank(lender);
        vm.expectRevert(ILineOfCredit.NotActive.selector);
        line.addCredit(dRate, fRate, 1 ether, address(supportedToken3), lender);
        vm.stopPrank();
    }
}