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

import { LineLib } from "../utils/LineLib.sol";
import { MutualConsent } from "../utils/MutualConsent.sol";

import { MockLine } from "../mock/MockLine.sol";
import { SimpleOracle } from "../mock/SimpleOracle.sol";
import { RevenueToken } from "../mock/RevenueToken.sol";

contract SecuredLineTest is Test {

    Escrow escrow;
    Spigot spigot;
    RevenueToken supportedToken1;
    RevenueToken supportedToken2;
    RevenueToken unsupportedToken;
    SimpleOracle oracle;
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
    address[] repaymentToken;

    function setUp() public {
        borrower = address(20);
        lender = address(10);
        externalLender = address(30);
        arbiter = address(this);
        _multisigAdmin = address(0xdead);

        beneficiaries = new address[](3);
        beneficiaries[0] = address(this);
        beneficiaries[1] = lender;

        supportedToken1 = new RevenueToken();
        supportedToken2 = new RevenueToken();
        unsupportedToken = new RevenueToken();

        /// make an array of length 3 and type uint256 where all 3 amounts add up to 100000
        allocations = new uint256[](3);
        allocations[0] = 0; // TODO: setting this to something greater than zero breaking tests
        allocations[1] = 20000;
        allocations[2] = 80000;

        // make an array of length 3 and type uint256 with random amounts for each member. name it debtOwed
        debtOwed = new uint256[](3);
        debtOwed[0] = 0;
        debtOwed[1] = 20000;
        debtOwed[2] = 80000;

        // make an array of length 3 and type address where each member is se to supportedToken1
        repaymentToken = new address[](3);
        repaymentToken[0] = address(supportedToken1);
        repaymentToken[1] = address(supportedToken1);
        repaymentToken[2] = address(supportedToken1);


        spigot = new Spigot(address(this), beneficiaries, allocations, debtOwed, repaymentToken, _multisigAdmin);
        oracle = new SimpleOracle(address(supportedToken1), address(supportedToken2));

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

        escrow.updateLine(address(line));
        spigot.updateOwner(address(line));

        line.init();
        // assertEq(uint(line.init()), uint(LineLib.STATUS.ACTIVE));

        _mintAndApprove();
        escrow.enableCollateral( address(supportedToken1));
        escrow.enableCollateral( address(supportedToken2));

        vm.startPrank(borrower);
        escrow.addCollateral(1 ether, address(supportedToken2));
        vm.stopPrank();
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

    function test_can_liquidate_escrow_if_cratio_below_min() public {
        _addCredit(address(supportedToken1), 1 ether);
        uint balanceOfEscrow = supportedToken2.balanceOf(address(escrow));
        uint balanceOfArbiter = supportedToken2.balanceOf(arbiter);

        bytes32 id = line.ids(0);
        vm.startPrank(borrower);
        line.borrow(id, 1 ether, borrower);
        vm.stopPrank();
        (uint p,) = line.updateOutstandingDebt();
        assertGt(p, 0);
        console.log('checkpoint');
        oracle.changePrice(address(supportedToken2), 1);
        line.liquidate(1 ether, address(supportedToken2));
        assertEq(balanceOfEscrow, supportedToken1.balanceOf(address(escrow)) + 1 ether, "Escrow balance should have increased by 1e18");
        assertEq(balanceOfArbiter, supportedToken2.balanceOf(arbiter) - 1 ether, "Arbiter balance should have decreased by 1e18");

    }

    function test_line_is_uninitilized_on_deployment() public {
        Spigot s = new Spigot(address(this), beneficiaries, allocations, debtOwed, repaymentToken, _multisigAdmin);
        Escrow e = new Escrow(minCollateralRatio, address(oracle), arbiter, borrower, arbiter);
        SecuredLine l = new SecuredLine(
            address(oracle),
            arbiter,
            borrower,
            payable(address(0)),
            address(s),
            address(e),
            150 days,
            0
        );
        // assertEq(uint(l.init()), uint(LineLib.STATUS.UNINITIALIZED));

        // spigot fails first because we need it more
        vm.expectRevert(abi.encodeWithSelector(ILineOfCredit.BadModule.selector, address(s)));
        l.init();
    }

    function invariant_position_count_equals_non_null_ids() public {
        (uint c, uint l) = line.counts();
        uint count = 0;
        for(uint i = 0; i < l;) {
          if(line.ids(i) != bytes32(0)) { unchecked { ++count; } }
          unchecked { ++i; }
        }
        assertEq(c, count);
    }

    function test_line_is_uninitilized_if_escrow_not_owned() public {
        address mock = address(new MockLine(0, address(3)));
        Spigot s = new Spigot(address(this), beneficiaries, allocations, debtOwed, repaymentToken, _multisigAdmin);
        Escrow e = new Escrow(minCollateralRatio, address(oracle), mock, borrower, arbiter);
        SecuredLine l = new SecuredLine(
            address(oracle),
            arbiter,
            borrower,
            payable(address(0)),
            address(s),
            address(e),
            150 days,
            0
        );

        // configure other modules
        s.updateOwner(address(l));

        // assertEq(uint(l.init()), uint(LineLib.STATUS.UNINITIALIZED));
        vm.expectRevert(abi.encodeWithSelector(ILineOfCredit.BadModule.selector, address(e)));
        l.init();
    }

    function test_line_is_uninitilized_if_spigot_not_owned() public {
        Spigot s = new Spigot(address(this),  beneficiaries, allocations, debtOwed, repaymentToken, _multisigAdmin);
        Escrow e = new Escrow(minCollateralRatio, address(oracle), address(this), borrower, arbiter);
        SecuredLine l = new SecuredLine(
            address(oracle),
            arbiter,
            borrower,
            payable(address(0)),
            address(s),
            address(e),
            150 days,
            0
        );

        // configure other modules
        e.updateLine(address(l));

        // assertEq(uint(l.init()), uint(LineLib.STATUS.UNINITIALIZED));
        vm.expectRevert(abi.encodeWithSelector(ILineOfCredit.BadModule.selector, address(s)));
        l.init();
    }


    function setupQueueTest(uint amount) internal returns (address[] memory) {
      address[] memory tokens = new address[](amount);
      // generate token for simulating different repayment flows
      for(uint i = 0; i < amount; i++) {
        RevenueToken token = new RevenueToken();
        tokens[i] = address(token);

        token.mint(lender, mintAmount);
        token.mint(borrower, mintAmount);

        vm.startPrank(lender);
        token.approve(address(line), mintAmount);
        vm.startPrank(borrower);
        token.approve(address(line), mintAmount);

        vm.startPrank(lender);
        token.approve(address(escrow), mintAmount);

        vm.startPrank(borrower);
        token.approve(address(escrow), mintAmount);
        oracle.changePrice(address(token), 1 ether);
        escrow.enableCollateral(address(token));

        // add collateral for each token so we can borrow it during tests
        vm.startPrank(borrower);
        escrow.addCollateral(1 ether, address(token));
      }

      return tokens;
    }


    function test_cannot_borrow_from_credit_position_if_under_collateralised() public {

        _addCredit(address(supportedToken1), 100 ether);
        bytes32 id = line.ids(0);
        vm.expectRevert(ILineOfCredit.BorrowFailed.selector);
        vm.startPrank(borrower);
        line.borrow(id, 100 ether, borrower);
    }



    function test_cannot_borrow_if_not_active() public {
        assert(line.healthcheck() == LineLib.STATUS.ACTIVE);

        _addCredit(address(supportedToken1), 0.1 ether);
        bytes32 id = line.ids(0);
        vm.startPrank(borrower);
        line.borrow(id, 0.1 ether, borrower);
        oracle.changePrice(address(supportedToken2), 1);
        assert(line.healthcheck() == LineLib.STATUS.LIQUIDATABLE);
        vm.expectRevert(ILineOfCredit.NotActive.selector);
        line.borrow(id, 0.9 ether, borrower);
        vm.stopPrank();
    }

    function test_cannot_liquidate_if_no_debt_when_deadline_passes() public {
        vm.startPrank(arbiter);
        vm.warp(ttl+1);
        vm.expectRevert(ILineOfCredit.NotLiquidatable.selector);
        line.liquidate(1 ether, address(supportedToken2));
    }

    function test_health_becomes_liquidatable_if_cratio_below_min() public {
        assertEq(uint(line.healthcheck()), uint(LineLib.STATUS.ACTIVE));
        _addCredit(address(supportedToken1), 1 ether);
        bytes32 id = line.ids(0);
        vm.startPrank(borrower);
        line.borrow(id, 1 ether, borrower);
        oracle.changePrice(address(supportedToken2), 1);
        assertEq(uint(line.healthcheck()), uint(LineLib.STATUS.LIQUIDATABLE));
    }


    function test_can_liquidate_if_debt_when_deadline_passes() public {
        vm.startPrank(borrower);
        line.addCredit(dRate, fRate, 1 ether, address(supportedToken1), lender);
        vm.stopPrank();
        vm.startPrank(lender);
        bytes32 id = line.addCredit(dRate, fRate, 1 ether, address(supportedToken1), lender);
        vm.stopPrank();
        vm.startPrank(borrower);
        line.borrow(id, 1 ether, borrower);
        vm.stopPrank();
        vm.warp(ttl + 1);
        line.liquidate(0.9 ether, address(supportedToken2));
    }

    // test should succeed to liquidate when no debt (but positions exist) and passed deadline
    function test_can_liquidate_if_no_debt_but_positions_exist_when_deadline_passes() public {
        vm.startPrank(borrower);
        line.addCredit(dRate, fRate, 1 ether, address(supportedToken1), lender);
        vm.stopPrank();
        vm.startPrank(lender);
        bytes32 id = line.addCredit(dRate, fRate, 1 ether, address(supportedToken1), lender);
        vm.stopPrank();
        vm.warp(ttl + 1);
        line.liquidate(1 ether, address(supportedToken2));
    }

    // test should fail to liquidate when no debt / no positions at deadline
    function test_cannot_liquidate_when_no_debt_or_positions_after_deadline() public {
        vm.warp(ttl + 1);
        vm.expectRevert(ILineOfCredit.NotLiquidatable.selector);
        line.liquidate(1 ether, address(supportedToken2));
    }

    // test should liquidate if above cratio after deadline
    function test_can_liquidate_after_deadline_if_above_min_cRatio() public {
        _addCredit(address(supportedToken2), 1 ether);
        bytes32 id = line.ids(0);

        vm.startPrank(borrower);
        line.borrow(id, 1 ether, borrower);
        vm.stopPrank();

        (uint p, uint i) = line.updateOutstandingDebt();
        emit log_named_uint("principal", p);
        emit log_named_uint("interest", i);
        assertGt(p, 0);

        uint32 cRatio = Escrow(address(line.escrow())).minimumCollateralRatio();
        emit log_named_uint("cRatio before", cRatio);

        // increase the cRatio
        oracle.changePrice(address(supportedToken2), 990 * 1e8);

        vm.warp(ttl + 1);
        line.liquidate(1 ether, address(supportedToken2));
    }

    // should not be liquidatable if all positions closed (needs mo's PR)

    // CONDITIONS for liquidation:
    // dont pay debt by deadline
    // under minimum collateral value ( changing the oracle price )

    // test should fail to liquidate if above cratio before deadline
    function test_cannot_liquidate_escrow_if_cratio_above_min() public {
        vm.startPrank(borrower);
        line.addCredit(dRate, fRate, 1 ether, address(supportedToken1), lender);
        vm.stopPrank();
        vm.startPrank(lender);
        bytes32 id = line.addCredit(dRate, fRate, 1 ether, address(supportedToken1), lender);
        vm.stopPrank();
        vm.startPrank(borrower);
        line.borrow(id, 1 ether, borrower);
        vm.stopPrank();
        vm.expectRevert(ILineOfCredit.NotLiquidatable.selector);
        line.liquidate(1 ether, address(supportedToken2));
    }

    function test_health_is_not_liquidatable_if_cratio_above_min() public {
        assertTrue(line.healthcheck() != LineLib.STATUS.LIQUIDATABLE);
    }

       // test should succeed to liquidate when collateral ratio is below min cratio
    function test_can_liquidate_anytime_if_escrow_cratio_below_min() public {
        _addCredit(address(supportedToken1), 1 ether);
        uint balanceOfEscrow = supportedToken2.balanceOf(address(escrow));
        uint balanceOfArbiter = supportedToken2.balanceOf(arbiter);
        bytes32 id = line.ids(0);
        vm.startPrank(borrower);
        line.borrow(id, 1 ether, borrower);
        vm.stopPrank();
        (uint p, uint i) = line.updateOutstandingDebt();
        assertGt(p, 0);
        oracle.changePrice(address(supportedToken2), 1);
        line.liquidate(1 ether, address(supportedToken2));
        assertEq(balanceOfEscrow, supportedToken1.balanceOf(address(escrow)) + 1 ether, "Escrow balance should have increased by 1e18");
        assertEq(balanceOfArbiter, supportedToken2.balanceOf(arbiter) - 1 ether, "Arbiter balance should have decreased by 1e18");
    }


    function test_health_becomes_liquidatable_when_cratio_below_min() public {
        _addCredit(address(supportedToken1), 1 ether);
        bytes32 id = line.ids(0);
        vm.startPrank(borrower);
        line.borrow(id, 1 ether, borrower);
        oracle.changePrice(address(supportedToken2), 1);
        assert(line.healthcheck() == LineLib.STATUS.LIQUIDATABLE);
    }

    function test_cannot_liquidate_as_anon() public {
        vm.startPrank(borrower);
        line.addCredit(dRate, fRate, 1 ether, address(supportedToken1), lender);
        vm.stopPrank();

        vm.startPrank(lender);
        bytes32 id = line.addCredit(dRate, fRate, 1 ether, address(supportedToken1), lender);
        vm.stopPrank();

        vm.startPrank(borrower);
        line.borrow(id, 1 ether, borrower);
        vm.stopPrank();

        vm.startPrank(address(0xdead));
        vm.expectRevert(ILineOfCredit.CallerAccessDenied.selector);
        line.liquidate(1 ether, address(supportedToken2));
        vm.stopPrank();
    }

    function test_cannot_liquidate_as_borrower() public {
        // borrow so we can be liqudiated
        _addCredit(address(supportedToken1), 1 ether);
        vm.startPrank(borrower);
        line.borrow(line.ids(0), 1 ether, borrower);

        vm.warp(ttl+1);
        vm.expectRevert(ILineOfCredit.CallerAccessDenied.selector);
        line.liquidate(1 ether, address(supportedToken2));
        vm.stopPrank();
    }

    // Native ETH support

    // function test_cannot_depositAndClose_when_sending_ETH() public {
    //     _addCredit(address(supportedToken1), 1 ether);
    //     bytes32 id = line.ids(0);
    //     vm.startPrank(borrower);
    //     line.borrow(id, 1 ether);
    //     vm.stopPrank();
    //     vm.startPrank(borrower);
    //     vm.expectRevert(LineLib.EthSentWithERC20.selector);
    //     line.depositAndClose{value: 0.1 ether}();
    //     vm.stopPrank();
    // }





// declareInsolvent
    function test_must_be_in_debt_to_go_insolvent() public {
        vm.expectRevert(ILineOfCredit.NotLiquidatable.selector);
        line.declareInsolvent();
    }

    function test_only_arbiter_can_delcare_insolvency() public {
        _addCredit(address(supportedToken1), 1 ether);

        bytes32 id = line.ids(0);
        vm.startPrank(borrower);
        line.borrow(id, 1 ether, borrower);
        vm.stopPrank();

        vm.startPrank(address(0xdebf));
        vm.expectRevert(ILineOfCredit.CallerAccessDenied.selector);
        line.declareInsolvent();
    }

    function test_cant_delcare_insolvency_if_not_liquidatable() public {
        _addCredit(address(supportedToken1), 1 ether);
        bytes32 id = line.ids(0);
        vm.startPrank(borrower);
        line.borrow(id, 1 ether, borrower);
        vm.stopPrank();

        vm.startPrank(arbiter);
        vm.expectRevert(ILineOfCredit.NotLiquidatable.selector);
        line.declareInsolvent();
        vm.stopPrank();
    }



    function test_cannot_insolve_until_liquidate_all_escrowed_tokens() public {
        _addCredit(address(supportedToken1), 1 ether);
        bytes32 id = line.ids(0);
        vm.startPrank(borrower);
        line.borrow(id, 1 ether, borrower);
        vm.warp(ttl+1);
        vm.stopPrank();

        vm.startPrank(arbiter);

        // ensure spigot insolvency check passes
        assertTrue(line.releaseSpigot(arbiter));
        // "sell" spigot off
        line.spigot().updateOwner(address(0xf1c0));

        assertEq(0.9 ether, line.liquidate(0.9 ether, address(supportedToken2)));

        vm.expectRevert(
          abi.encodeWithSelector(ILineOfCredit.NotInsolvent.selector, line.escrow())
        );
        line.declareInsolvent();
    }

    function test_cannot_insolve_until_liquidate_spigot() public {
        _addCredit(address(supportedToken1), 1 ether);
        bytes32 id = line.ids(0);
        vm.startPrank(borrower);
        line.borrow(id, 1 ether, borrower);
        vm.stopPrank();

        vm.warp(ttl+1);
        vm.startPrank(arbiter);
        // ensure escrow insolvency check passes
        assertEq(1 ether, line.liquidate(1 ether, address(supportedToken2)));

        vm.expectRevert(
          abi.encodeWithSelector(ILineOfCredit.NotInsolvent.selector, line.spigot())
        );

        line.declareInsolvent();
    }

    function test_can_delcare_insolvency_when_all_assets_liquidated() public {
        _addCredit(address(supportedToken1), 1 ether);
        bytes32 id = line.ids(0);
        vm.startPrank(borrower);

        line.borrow(id, 1 ether, borrower);
        console.log('check');

        vm.warp(ttl+1);
        vm.stopPrank();

        vm.startPrank(arbiter);
        assertTrue(line.releaseSpigot(arbiter));
        assertTrue(line.spigot().updateOwner(address(0xf1c0)));
        assertEq(1 ether, line.liquidate(1 ether, address(supportedToken2)));
        // release spigot + liquidate

        line.declareInsolvent();
        assertEq(uint(LineLib.STATUS.INSOLVENT), uint(line.status()));
        vm.stopPrank();
    }

    // amendAndExtend()

    function test_only_borrower_can_amend_and_extend() public {
        address[] memory revenueContracts;
        uint8[] memory ownerSplits;

        vm.startPrank(lender);
        vm.expectRevert(ILineOfCredit.CallerAccessDenied.selector);
        line.amendAndExtend(borrower, 1, 0, revenueContracts, ownerSplits);
        vm.stopPrank();

        vm.startPrank(arbiter);
        vm.expectRevert(ILineOfCredit.CallerAccessDenied.selector);
        line.amendAndExtend(borrower, 1, 0, revenueContracts, ownerSplits);
        vm.stopPrank();
    }

    function test_cannot_amend_and_extend_if_active_positions() public {
        _addCredit(address(supportedToken1), 1 ether);
        address[] memory revenueContracts;
        uint8[] memory ownerSplits;

        vm.startPrank(borrower);
        vm.expectRevert(ISecuredLine.CannotAmendAndExtendLine.selector);
        line.amendAndExtend(borrower, 1, 0, revenueContracts, ownerSplits);
        vm.stopPrank();
    }

    // TODO: implement this test
    // TODO: test w/ 1 and 2 proposals
    // TODO: end-to-end test where user has accepted positions in the past and repaid the line and positions
    function test_amend_and_extend_clears_credit_proposals() public {
        address[] memory revenueContracts;
        uint8[] memory ownerSplits;

        _addCredit(address(supportedToken1), 1 ether);
        bytes32 id = line.ids(0);

        // borrower repays and closes line
        vm.startPrank(borrower);
        line.borrow(id, 1 ether, borrower);
        line.depositAndClose();
        vm.stopPrank();
        // amend and extend #1: borrower setting line status to ACTIVE
        vm.startPrank(borrower);
        // TODO: tests that event emitted (add the other tests here)
        // uint256 deadline = line.deadline();
        emit log_named_uint("Status: ", uint(line.status()));
        // TODO: add back expectEmit
        // vm.expectEmit(line, borrower, deadline + 1);
        // emit Events.AmendAndExtendLine(line, borrower, deadline + 1);
        line.amendAndExtend(borrower, 1, 0, revenueContracts, ownerSplits);
        assertEq(line.proposalCount(), 0);
        // assertEq(line.mutualConsentProposals(proposalId), address(0));
        // TODO: add test that line status is active
        // assertEq(line.)

        vm.stopPrank();

        // lender proposes credit position
        vm.startPrank(lender);
        line.addCredit(dRate, fRate, 100 ether, address(supportedToken1), lender);
        vm.stopPrank();

        bytes32 proposalId = line.mutualConsentProposalIds(0);

        // amend and extend #2: borrower amends and extends the line removing the proposed credit position
        vm.startPrank(borrower);
        // TODO: tests that event emitted (add the other tests here)
        // uint256 deadline = line.deadline();
        // TODO: add back expectEmit
        // vm.expectEmit(line, borrower, deadline + 1);
        // emit Events.AmendAndExtendLine(line, borrower, deadline + 1);
        line.amendAndExtend(borrower, 1, 0, revenueContracts, ownerSplits);
        assertEq(line.proposalCount(), 0);
        assertEq(line.mutualConsentProposals(proposalId), address(0));

        vm.stopPrank();

    }

    function test_can_amend_and_extend_if_active_line_w_no_active_positions() public {
        emit log_named_uint("status 1", uint(line.status()));
        emit log_named_uint("ttl 1", line.deadline());
        emit log_named_uint("defaultSplit 1", uint(line.defaultRevenueSplit()));
        emit log_named_uint("minCRatio 1", uint(escrow.minimumCollateralRatio()));
        emit log_named_uint("# active positions 1", line.count());
        uint256 deadline1 = line.deadline();
        address[] memory revenueContracts;
        uint8[] memory ownerSplits;

        vm.startPrank(borrower);
        line.amendAndExtend(borrower, 1, 0, revenueContracts, ownerSplits);
        assertEq(uint(line.count()), 0);
        assertEq(uint(line.deadline()), deadline1 + 1);
        // assertEq(line.defaultRevenueSplit(), 10);
        assertEq(escrow.minimumCollateralRatio(), 0);
        vm.stopPrank();

        emit log_named_uint("\nstatus 2", uint(line.status()));
        emit log_named_uint("ttl 2", line.deadline());
        // emit log_named_uint("defaultSplit 2", uint(line.defaultRevenueSplit()));
        emit log_named_uint("minCRatio 2", uint(escrow.minimumCollateralRatio()));
        emit log_named_uint("# active positions 2", line.count());

        vm.startPrank(borrower);
        line.amendAndExtend(borrower, 1, 100, revenueContracts, ownerSplits);
        vm.stopPrank();

        emit log_named_uint("\nstatus 3", uint(line.status()));
        emit log_named_uint("ttl 3", line.deadline());
        emit log_named_uint("defaultSplit 3", uint(line.defaultRevenueSplit()));
        emit log_named_uint("minCRatio 3", uint(escrow.minimumCollateralRatio()));
        emit log_named_uint("# active positions 3", line.count());
    }

    function test_can_amend_and_extend_if_repaid_line() public {
        emit log_named_uint("status 1", uint(line.status()));
        emit log_named_uint("ttl 1", line.deadline());
        emit log_named_uint("defaultSplit 1", uint(line.defaultRevenueSplit()));
        emit log_named_uint("minCRatio 1", uint(escrow.minimumCollateralRatio()));
        // emit log_named_uint("# active positions", uint(line.ids().length));

        address[] memory revenueContracts;
        uint8[] memory ownerSplits;

        vm.startPrank(borrower);
        // vm.expectRevert(ISecuredLine.CannotAmendAndExtendLine.selector);
        line.amendAndExtend(borrower, 1, 0, revenueContracts, ownerSplits);
        vm.stopPrank();

        emit log_named_uint("status 2", uint(line.status()));
        emit log_named_uint("ttl 2", line.deadline());
        emit log_named_uint("defaultSplit 2", uint(line.defaultRevenueSplit()));
        emit log_named_uint("minCRatio 2", uint(escrow.minimumCollateralRatio()));

        vm.startPrank(borrower);
        // vm.expectRevert(ISecuredLine.CannotAmendAndExtendLine.selector);
        line.amendAndExtend(borrower, 1, 0, revenueContracts, ownerSplits);
        vm.stopPrank();

        emit log_named_uint("status 3", uint(line.status()));
        emit log_named_uint("ttl 3", line.deadline());
        emit log_named_uint("defaultSplit 3", uint(line.defaultRevenueSplit()));
        emit log_named_uint("minCRatio 3", uint(escrow.minimumCollateralRatio()));
    }

    function test_amend_and_extend_does_not_update_owner_splits_0_revenue_contracts() public {}
    function test_amend_and_extend_updates_owner_splits_1_revenue_contracts() public {}
    function test_amend_and_extend_updates_owner_splits_2_revenue_contracts() public {}
    // TODO: what happens if invalid array inputs?
    // TODO: what happens if invalid default split
    // TODO: what happens if invalid minCRatio


    // update beneficiaries
    function test_can_update_beneficiary_settings_if_repaid_line() public {
        address[] memory newBeneficiaries = new address[](2);
        newBeneficiaries[0] = address(line);
        newBeneficiaries[1] = address(externalLender);

        address[] memory newOperators = new address[](2);
        newOperators[0] = address(line);
        newOperators[1] = address(externalLender);

        uint256[] memory newAllocations = new uint256[](2);
        newAllocations[0] = 50000;
        newAllocations[1] = 50000;

        address[] memory newRepaymentTokens = new address[](2);
        newRepaymentTokens[0] = address(0);
        newRepaymentTokens[1] = address(supportedToken1);

        uint256 usdcDebtOwed = 100000;
        uint256[] memory newOutstandingDebts = new uint256[](2);
        newOutstandingDebts[0] = 0;
        newOutstandingDebts[1] = usdcDebtOwed;

        // update beneficiary settings the first time
        vm.startPrank(borrower);
        line.updateBeneficiarySettings(newBeneficiaries, newOperators, newAllocations, newRepaymentTokens, newOutstandingDebts);

        (address locBennyOperator, uint256 locAllocation, address locRepaymentToken, uint256 locDebtOwed) = line.spigot().getBeneficiaryBasicInfo(address(line));
        emit log_named_address('LoC Benny: ', locBennyOperator);
        emit log_named_uint('LoC Allocation: ', locAllocation);
        emit log_named_address('LoC Repayment Token: ', locRepaymentToken);
        emit log_named_uint('LoC Debt Owed: ', locDebtOwed);

        (address elBennyOperator, uint256 elAllocation, address elRepaymentToken, uint256 elDebtOwed) = line.spigot().getBeneficiaryBasicInfo(address(externalLender));
        emit log_named_address('EL Benny: ', elBennyOperator);
        emit log_named_uint('EL Allocation: ', elAllocation);
        emit log_named_address('EL Repayment Token: ', elRepaymentToken);
        emit log_named_uint('EL Debt Owed: ', elDebtOwed);

        assertEq(locBennyOperator, address(line));
        assertEq(elBennyOperator, address(externalLender));
        assertEq(locAllocation, 50000);
        assertEq(elAllocation, 50000);
        assertEq(locAllocation + elAllocation, FULL_ALLOC);
        assertEq(locRepaymentToken, address(0));
        assertEq(elRepaymentToken, address(supportedToken1));
        assertEq(locDebtOwed, 0);
        assertEq(elDebtOwed, usdcDebtOwed);

        // console.log('LoC Beneficiary Basic Info: ', locBennyOperator, locAllocation, locRepaymentToken, locDebtOwed);


        vm.stopPrank();
    }





    // TODO: implement this function
    function test_arbiter_can_set_beneficiary_debt_to_zero() public {

        // arbiter sets beneficiary debt to zero and allocation dynamically adjusts to 100% to the LoC

    }



    // Rollover()

    function test_cant_rollover_if_not_repaid() public {
      // ACTIVE w/o debt
      vm.startPrank(borrower);
      vm.expectRevert(ISecuredLine.DebtOwed.selector);
      line.rollover(address(line));

      // ACTIVE w/ debt
      _addCredit(address(supportedToken1), 1 ether);
      bytes32 id = line.ids(0);
      line.borrow(id, 1 ether, borrower);

      vm.expectRevert(ISecuredLine.DebtOwed.selector);
      line.rollover(address(line));

      oracle.changePrice(address(supportedToken2), 1);
      assertFalse(line.status() == LineLib.STATUS.REPAID);
      // assertEq(uint(line.status()), uint(LineLib.STATUS.REPAID));

      // LIQUIDATABLE w/ debt
      vm.expectRevert(ISecuredLine.DebtOwed.selector);
      line.rollover(address(line));
      line.depositAndClose();

      // REPAID (test passes if next error)
      vm.expectRevert(ISecuredLine.BadNewLine.selector);
      line.rollover(address(line));
      vm.stopPrank();
    }

    function test_cant_rollover_if_newLine_already_initialized() public {
      _addCredit(address(supportedToken1), 1 ether);
      bytes32 id = line.ids(0);
      vm.startPrank(borrower);
      line.borrow(id, 1 ether, borrower);
      line.depositAndClose();
      vm.stopPrank();
      // create and init new line with new modules
      Spigot s = new Spigot(address(this), beneficiaries, allocations, debtOwed, repaymentToken, _multisigAdmin);
      Escrow e = new Escrow(minCollateralRatio, address(oracle), arbiter, borrower, arbiter);
      SecuredLine l = new SecuredLine(
        address(oracle),
        arbiter,
        borrower,
        payable(address(0)),
        address(s),
        address(e),
        150 days,
        0
      );

      e.updateLine(address(l));
      s.updateOwner(address(l));
      l.init();

      // giving our modules should fail because taken already
      vm.expectRevert(ISecuredLine.BadNewLine.selector);
      vm.startPrank(borrower);
      line.rollover(address(l));
    }

    function test_cant_rollover_if_newLine_not_line() public {
      _addCredit(address(supportedToken1), 1 ether);
      bytes32 id = line.ids(0);
      vm.startPrank(borrower);
      line.borrow(id, 1 ether, borrower);
      line.depositAndClose();

      vm.expectRevert(); // evm revert, .init() does not exist on address(this)
      line.rollover(address(this));
    }


    function test_cant_rollover_if_newLine_not_expeciting_modules() public {
      _addCredit(address(supportedToken1), 1 ether);
      bytes32 id = line.ids(0);
      vm.startPrank(borrower);
      line.borrow(id, 1 ether, borrower);
      line.depositAndClose();

      // create and init new line with new modules
      Spigot s = new Spigot(address(this), beneficiaries, allocations, debtOwed, repaymentToken, _multisigAdmin);
      Escrow e = new Escrow(minCollateralRatio, address(oracle), arbiter, borrower, arbiter);
      SecuredLine l = new SecuredLine(
        address(oracle),
        arbiter,
        borrower,
        payable(address(0)),
        address(s),
        address(e),
        150 days,
        0
      );

      // giving our modules should fail because taken already
      vm.expectRevert(ISecuredLine.BadRollover.selector);
      line.rollover(address(l));
    }


   function test_cant_rollover_if_not_borrower() public {
      vm.startPrank(address(0xdeaf));
      vm.expectRevert(ILineOfCredit.CallerAccessDenied.selector);
      line.rollover(arbiter);
    }

    function test_rollover_gives_modules_to_new_line() public {
      _addCredit(address(supportedToken1), 1 ether);
      bytes32 id = line.ids(0);
      vm.startPrank(borrower);
      line.borrow(id, 1 ether, borrower);
      line.depositAndClose();

      SecuredLine l = new SecuredLine(
        address(oracle),
        arbiter,
        borrower,
        payable(address(0)),
        address(spigot),
        address(escrow),
        150 days,
        0
      );
      line.rollover(address(l));

      assertEq(address(l.spigot()) , address(spigot));
      assertEq(address(l.escrow()) , address(escrow));
      vm.stopPrank();
    }
    receive() external payable {}
}
