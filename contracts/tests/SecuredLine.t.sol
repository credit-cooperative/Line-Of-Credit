// SPDX-License-Identifier: GPL-3.0
// Copyright: https://github.com/credit-cooperative/Line-Of-Credit/blob/master/COPYRIGHT.md

 pragma solidity ^0.8.16;

import "forge-std/Test.sol";
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

    address borrower;
    address arbiter;
    address lender;

    function setUp() public {
        borrower = address(20);
        lender = address(10);
        arbiter = address(this);
        supportedToken1 = new RevenueToken();
        supportedToken2 = new RevenueToken();
        unsupportedToken = new RevenueToken();

        spigot = new Spigot(arbiter, borrower);
        oracle = new SimpleOracle(address(supportedToken1), address(supportedToken2));

        escrow = new Escrow(minCollateralRatio, address(oracle), arbiter, borrower);

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
        line.borrow(id, 1 ether);
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
        Spigot s = new Spigot(arbiter, borrower);
        Escrow e = new Escrow(minCollateralRatio, address(oracle), arbiter, borrower);
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
        Spigot s = new Spigot(arbiter, borrower);
        Escrow e = new Escrow(minCollateralRatio, address(oracle), mock, borrower);
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
        Spigot s = new Spigot(arbiter, borrower);
        Escrow e = new Escrow(minCollateralRatio, address(oracle), address(this), borrower);
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
        line.borrow(id, 100 ether);
    }



    function test_cannot_borrow_if_not_active() public {
        assert(line.healthcheck() == LineLib.STATUS.ACTIVE);

        _addCredit(address(supportedToken1), 0.1 ether);
        bytes32 id = line.ids(0);
        vm.startPrank(borrower);
        line.borrow(id, 0.1 ether);
        oracle.changePrice(address(supportedToken2), 1);
        assert(line.healthcheck() == LineLib.STATUS.LIQUIDATABLE);
        vm.expectRevert(ILineOfCredit.NotActive.selector);
        vm.startPrank(borrower);
        line.borrow(id, 0.9 ether);
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
        line.borrow(id, 1 ether);
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
        line.borrow(id, 1 ether);
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
        line.borrow(id, 1 ether);
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
        line.borrow(id, 1 ether);
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
        line.borrow(id, 1 ether);
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
        line.borrow(id, 1 ether);
        oracle.changePrice(address(supportedToken2), 1);
        assert(line.healthcheck() == LineLib.STATUS.LIQUIDATABLE);
    }

    function test_cannot_liquidate_as_anon() public {
        vm.startPrank(borrower);
        line.addCredit(dRate, fRate, 1 ether, address(supportedToken1), lender);
        vm.startPrank(lender);
        bytes32 id = line.addCredit(dRate, fRate, 1 ether, address(supportedToken1), lender);
        vm.startPrank(borrower);
        line.borrow(id, 1 ether);

        vm.startPrank(address(0xdead));
        vm.expectRevert(ILineOfCredit.CallerAccessDenied.selector);
        line.liquidate(1 ether, address(supportedToken2));
    }

    function test_cannot_liquidate_as_borrower() public {
        // borrow so we can be liqudiated
        _addCredit(address(supportedToken1), 1 ether);
        vm.startPrank(borrower);
        line.borrow(line.ids(0), 1 ether);

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
        line.borrow(id, 1 ether);

        vm.startPrank(address(0xdebf));
        vm.expectRevert(ILineOfCredit.CallerAccessDenied.selector);
        line.declareInsolvent();
    }

    function test_cant_delcare_insolvency_if_not_liquidatable() public {
        _addCredit(address(supportedToken1), 1 ether);
        bytes32 id = line.ids(0);
        vm.startPrank(borrower);
        line.borrow(id, 1 ether);

        vm.startPrank(arbiter);
        vm.expectRevert(ILineOfCredit.NotLiquidatable.selector);
        line.declareInsolvent();
    }



    function test_cannot_insolve_until_liquidate_all_escrowed_tokens() public {
        _addCredit(address(supportedToken1), 1 ether);
        bytes32 id = line.ids(0);
        vm.startPrank(borrower);
        line.borrow(id, 1 ether);

        vm.warp(ttl+1);

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
        line.borrow(id, 1 ether);

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

        line.borrow(id, 1 ether);
        console.log('check');

        vm.warp(ttl+1);
        //vm.startPrank(arbiter);

        vm.startPrank(arbiter);
        assertTrue(line.releaseSpigot(arbiter));
        assertTrue(line.spigot().updateOwner(address(0xf1c0)));
        assertEq(1 ether, line.liquidate(1 ether, address(supportedToken2)));
        // release spigot + liquidate

        line.declareInsolvent();
        assertEq(uint(LineLib.STATUS.INSOLVENT), uint(line.status()));
    }





    // Rollover()

    function test_cant_rollover_if_not_repaid() public {
      // ACTIVE w/o debt
      vm.expectRevert(ISecuredLine.DebtOwed.selector);
      vm.startPrank(borrower);
      line.rollover(address(line));

      // ACTIVE w/ debt
      _addCredit(address(supportedToken1), 1 ether);
      bytes32 id = line.ids(0);
      vm.startPrank(borrower);
      line.borrow(id, 1 ether);

      vm.expectRevert(ISecuredLine.DebtOwed.selector);
      vm.startPrank(borrower);
      line.rollover(address(line));

      oracle.changePrice(address(supportedToken2), 1);
      assertFalse(line.status() == LineLib.STATUS.REPAID);
      // assertEq(uint(line.status()), uint(LineLib.STATUS.REPAID));

      // LIQUIDATABLE w/ debt
      vm.expectRevert(ISecuredLine.DebtOwed.selector);
      vm.startPrank(borrower);
      line.rollover(address(line));
      vm.startPrank(borrower);
      line.depositAndClose();

      // REPAID (test passes if next error)
      vm.expectRevert(ISecuredLine.BadNewLine.selector);
      vm.startPrank(borrower);
      line.rollover(address(line));
    }

    function test_cant_rollover_if_newLine_already_initialized() public {
      _addCredit(address(supportedToken1), 1 ether);
      bytes32 id = line.ids(0);
      vm.startPrank(borrower);
      line.borrow(id, 1 ether);
      vm.stopPrank();
      vm.startPrank(borrower);
      line.depositAndClose();
      vm.stopPrank();
      // create and init new line with new modules
      Spigot s = new Spigot(arbiter, borrower);
      Escrow e = new Escrow(minCollateralRatio, address(oracle), arbiter, borrower);
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
      line.borrow(id, 1 ether);
      vm.startPrank(borrower);
      line.depositAndClose();

      vm.expectRevert(); // evm revert, .init() does not exist on address(this)
      vm.startPrank(borrower);
      line.rollover(address(this));
    }


    function test_cant_rollover_if_newLine_not_expeciting_modules() public {
      _addCredit(address(supportedToken1), 1 ether);
      bytes32 id = line.ids(0);
      vm.startPrank(borrower);
      line.borrow(id, 1 ether);
      vm.startPrank(borrower);
      line.depositAndClose();

      // create and init new line with new modules
      Spigot s = new Spigot(arbiter, borrower);
      Escrow e = new Escrow(minCollateralRatio, address(oracle), arbiter, borrower);
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
      vm.startPrank(borrower);
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
      line.borrow(id, 1 ether);

      vm.startPrank(borrower);
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
      vm.startPrank(borrower);
      line.rollover(address(l));

      assertEq(address(l.spigot()) , address(spigot));
      assertEq(address(l.escrow()) , address(escrow));
    }
    receive() external payable {}
}
