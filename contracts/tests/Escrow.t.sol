// SPDX-License-Identifier: GPL-3.0
// Copyright: https://github.com/credit-cooperative/Line-Of-Credit/blob/master/COPYRIGHT.md

 pragma solidity ^0.8.16;

import { Test } from "forge-std/Test.sol";
import { Denominations } from "chainlink/Denominations.sol";

import { IEscrow } from "../interfaces/IEscrow.sol";

import { Escrow } from "../modules/escrow/Escrow.sol";

import { LineLib } from "../utils/LineLib.sol";

import { EscrowLib } from "../utils/EscrowLib.sol";

import { MockLine } from "../mock/MockLine.sol";
import { RevenueToken } from "../mock/RevenueToken.sol";
import { SimpleOracle } from "../mock/SimpleOracle.sol";
import { RevenueToken4626 } from "../mock/RevenueToken4626.sol";

contract EscrowTest is Test {

    Escrow escrow;
    Escrow badEscrow;

    RevenueToken supportedToken1;
    RevenueToken supportedToken2;
    RevenueToken unsupportedToken;
    RevenueToken4626 token4626;
    SimpleOracle oracle;
    SimpleOracle badOracle;
    MockLine line;
    MockLine badLine;

    uint mintAmount = 100 ether;
    uint MAX_INT = type(uint256).max;
    uint32 minCollateralRatio = 10000; // 100%

    address borrower = address(this);
    address arbiter = address(20);

    address invalidToken = makeAddr("invalidToken");

    function setUp() public {
        // deploy tokens and add oracle prices for valid collateral
        supportedToken1 = new RevenueToken();
        supportedToken2 = new RevenueToken();
        unsupportedToken = new RevenueToken();
        token4626 = new RevenueToken4626(address(supportedToken1));
        oracle = new SimpleOracle(address(supportedToken1), address(supportedToken2));
        badOracle = new SimpleOracle(invalidToken, invalidToken);

        line = new MockLine(1, arbiter);
        badLine = new MockLine(0, arbiter);

        // deploy and save escrow
        address _escrow = _createEscrow(minCollateralRatio, address(oracle), address(line), borrower);

        badEscrow = new Escrow(minCollateralRatio, address(badOracle), address(badLine), borrower);

        // add escrow to mock line
        line.setEscrow(_escrow);
        badLine.setEscrow(address(badEscrow));

        _mintAndApprove();
    }

    function _enableCollateral(address token) internal {
        startHoax(arbiter); // only arbiter can enable
        escrow.enableCollateral(address(token));
        vm.stopPrank(); // revert to old
    }

    function _mintAndApprove() internal {
        deal(borrower, MAX_INT);
        deal(address(this), MAX_INT);

        supportedToken1.mint(borrower, mintAmount);
        supportedToken1.approve(address(escrow), MAX_INT);
        supportedToken2.mint(borrower, mintAmount);
        supportedToken2.approve(address(escrow), MAX_INT);
        unsupportedToken.mint(borrower, mintAmount);
        unsupportedToken.approve(address(escrow), MAX_INT);
        token4626.mint(borrower, mintAmount);
        token4626.approve(address(escrow), MAX_INT);

        // allow tokens to be deposited as collateral
        _enableCollateral(address(supportedToken2));
        _enableCollateral(address(supportedToken1));

        // Native Eth support is disabled
        vm.expectRevert(EscrowLib.EthSupportDisabled.selector);
        _enableCollateral(Denominations.ETH);
    }

    function _createEscrow(
        uint32 _minimumCollateralRatio,
        address _oracle,
        address _line,
        address _borrower
    ) internal returns(address) {
        escrow = new Escrow(_minimumCollateralRatio, _oracle, _line, _borrower);

        return address(escrow);
    }

    function test_enable_valid_collateral_as_arbiter() public {
        RevenueToken token = new RevenueToken();

        token.mint(address(this), mintAmount);
        oracle.changePrice(address(token), 1 ether); // need oracle price to enable
        _enableCollateral(address(token));
    }

    function testFail_enable_invalid_collateral_as_arbiter() public {
        RevenueToken token = new RevenueToken();
        token.mint(address(this), mintAmount);
        _enableCollateral(address(token));
    }

    function test_cannot_enable_collateral_when_not_arbiter() public {

        address eoa = makeAddr("eoa");
        vm.startPrank(eoa);
        vm.expectRevert(EscrowLib.ArbiterOnly.selector);
        escrow.enableCollateral(address(supportedToken1));
        vm.stopPrank();

        vm.startPrank(borrower);
        vm.expectRevert(EscrowLib.ArbiterOnly.selector);
        escrow.enableCollateral(address(supportedToken1));
        vm.stopPrank();

    }

    function testFail_enable_collateral_as_anon() public {
        hoax(address(0xf1c0));
        escrow.enableCollateral(address(supportedToken1));
    }

    function test_can_get_correct_collateral_value() public {
        escrow.addCollateral(mintAmount, address(supportedToken1));
        uint collateralValue = escrow.getCollateralValue();
        assertEq(collateralValue, (1000 * 1e8) * (mintAmount / 1 ether), "collateral value should equal the mint amount * price");
    }
    function test_can_get_correct_collateral_value_eip4626() public {
        token4626.setAssetAddress(address(supportedToken1));
        _enableCollateral(address(token4626));  // must enable after setAssetAddress for proper token to be used
        escrow.addCollateral(mintAmount, address(token4626));
        uint collateralValue = escrow.getCollateralValue();
        assertEq(collateralValue, (1000 * 1e8) * (mintAmount / 1 ether), "collateral value should equal the mint amount * price");
    }

    function test_can_add_collateral_token() public {
        uint borrowerBalance = supportedToken1.balanceOf(borrower);
        escrow.addCollateral(mintAmount, address(supportedToken1));
        assertEq(borrowerBalance, supportedToken1.balanceOf(borrower) + mintAmount, "borrower should have decreased with collateral deposit");
        uint borrowerBalance2 = supportedToken2.balanceOf(borrower);
        escrow.addCollateral(mintAmount, address(supportedToken2));
        assertEq(borrowerBalance2, supportedToken2.balanceOf(borrower) + mintAmount, "borrower should have decreased with collateral deposit");
    }

    function test_adding_collateral_with_ETH_should_fail() public {
        vm.expectRevert(EscrowLib.InvalidCollateral.selector);
        escrow.addCollateral{value: mintAmount}(mintAmount, Denominations.ETH);
    }

    function test_adding_collateral_ETH_token_should_fail() public {
        vm.expectRevert(EscrowLib.InvalidCollateral.selector);
        escrow.addCollateral(mintAmount, Denominations.ETH);
    }

    function test_adding_collateral_with_bad_decimals_should_fail() public {
        vm.startPrank(arbiter);
        vm.expectRevert(EscrowLib.InvalidTokenDecimals.selector);
        badEscrow.enableCollateral(invalidToken);
        vm.stopPrank();
    }

    function test_can_add_collateral_eip4626() public {
        uint borrowerBalance = token4626.balanceOf(borrower);
        token4626.setAssetAddress(address(supportedToken2));
        _enableCollateral(address(token4626));
        escrow.addCollateral(mintAmount, address(token4626));
        assertEq(borrowerBalance, token4626.balanceOf(borrower) + mintAmount, "borrower balance should have been reduced by mintAmount");
    }

    function test_can_remove_collateral_eip4626() public {
        token4626.setAssetAddress(address(supportedToken2));
        _enableCollateral(address(token4626));
        escrow.addCollateral(mintAmount, address(token4626));
        escrow.releaseCollateral(1 ether, address(token4626), borrower);
        assertEq(1 ether, token4626.balanceOf(borrower), "should have returned collateral");
    }

    function test_can_remove_collateral_token() public {
        escrow.addCollateral(mintAmount, address(supportedToken1));
        uint borrowerBalance = supportedToken1.balanceOf(borrower);
        escrow.releaseCollateral(1 ether, address(supportedToken1), borrower);
        assertEq(borrowerBalance + 1 ether, supportedToken1.balanceOf(borrower), "borrower should have released collateral");
    }

    function test_cannot_remove_collateral_ETH() public {
        vm.expectRevert(EscrowLib.InvalidCollateral.selector);
        escrow.releaseCollateral(1 ether, Denominations.ETH, borrower);
    }

    function test_cratio_adjusts_when_collateral_changes() public {
        line.setDebtValue(1 ether);
        escrow.addCollateral(1 ether, address(supportedToken1));
        uint escrowRatio = escrow.getCollateralRatio();
        escrow.addCollateral(1 ether, address(supportedToken1));
        assertEq(escrow.getCollateralRatio(), escrowRatio * 2, "cratio should be 2x the original");
        escrow.addCollateral(1 ether, address(supportedToken2));
        assertEq(escrow.getCollateralRatio(), escrowRatio * 4, "cratio should be 4x the original");
    }

    function test_cratio_adjusts_when_collateral_price_changes() public {
        escrow.addCollateral(1 ether, address(supportedToken1));
        line.setDebtValue(1000);
        uint escrowRatio = escrow.getCollateralRatio();
        oracle.changePrice(address(supportedToken1), 10000 * 1e8);
        uint newEscrowRatio = escrow.getCollateralRatio();
        assertEq(newEscrowRatio, escrowRatio * 10, "new cratio should be 10x the original");
    }

    function test_cratio_adjusts_when_collateral_price_changes_eip4626() public {
        token4626.setAssetAddress(address(supportedToken1));
        _enableCollateral(address(token4626));  // must enable after setAssetAddress for proper token to be used
        escrow.addCollateral(1 ether, address(token4626));
        line.setDebtValue(1000);
        uint escrowRatio = escrow.getCollateralRatio();
        oracle.changePrice(address(supportedToken1), 10000 * 1e8);
        uint newEscrowRatio = escrow.getCollateralRatio();
        assertEq(newEscrowRatio, escrowRatio * 10, "new cratio should be 10x the original");
    }

    function test_can_liquidate_token() public {
        escrow.addCollateral(1 ether, address(supportedToken1));
        escrow.addCollateral(0.9 ether, address(supportedToken2));
        line.setDebtValue(2000 ether);
        assertGt(minCollateralRatio, escrow.getCollateralRatio(), "should be below the liquidation threshold");
        startHoax(arbiter);
        line.liquidate(0, 1 ether, address(supportedToken1), arbiter);
        line.liquidate(0, 0.9 ether, address(supportedToken2), arbiter);
        vm.stopPrank();
        assertEq(supportedToken1.balanceOf(arbiter), 1 ether, "arbiter should have received token 1");
        assertEq(supportedToken2.balanceOf(arbiter), 0.9 ether, "arbiter should have received token 2");
    }

    function test_cannot_liquidate_zero_amount() public {
        escrow.addCollateral(1 ether, address(supportedToken1));
        line.setDebtValue(2000 ether);
        assertGt(minCollateralRatio, escrow.getCollateralRatio(), "should be below the liquidation threshold");
        vm.startPrank(arbiter);
        vm.expectRevert(EscrowLib.InvalidZeroAmount.selector);
        line.liquidate(0, 0, address(supportedToken1), arbiter);
        vm.stopPrank();
    }

    function test_can_liquidate_eip4626() public {
        token4626.setAssetAddress(address(supportedToken1));
        _enableCollateral(address(token4626));  // must enable after setAssetAddress for proper token to be used
        token4626.setAssetMultiplier(5);
        _enableCollateral(address(token4626));
        escrow.addCollateral(1 ether, address(token4626));
        line.setDebtValue(2000 ether);
        assertGt(minCollateralRatio, escrow.getCollateralRatio(), "should be below the liquidation threshold");
        startHoax(arbiter);
        line.liquidate(0, 1 ether, address(token4626), arbiter);
        vm.stopPrank();
        assertEq(token4626.balanceOf(arbiter), 1 ether, "arbiter should have received 1e18 worth of the 4626 token");
    }

    function test_cannot_add_ETH_collateral() public {
        vm.startPrank(arbiter);
        vm.expectRevert(EscrowLib.EthSupportDisabled.selector);
        escrow.enableCollateral(Denominations.ETH);
        vm.stopPrank();

        vm.startPrank(borrower);
        vm.expectRevert(EscrowLib.InvalidCollateral.selector);
        escrow.addCollateral(mintAmount, Denominations.ETH);
        vm.stopPrank();
    }

    function test_cannot_liquidate_ETH() public {
        vm.startPrank(arbiter);
        vm.expectRevert(EscrowLib.InvalidCollateral.selector);
        line.liquidate(0, 1, Denominations.ETH, arbiter);
        vm.stopPrank();

    }

    function test_cratio_should_be_max_int_if_no_debt() public {
        escrow.addCollateral(1 ether, address(supportedToken1));
        line.setDebtValue(0);
        assertEq(escrow.getCollateralRatio(), MAX_INT, "cratio should be set to MAX");
    }

    function test_cratio_values() public {
        escrow.addCollateral(1 ether, address(supportedToken1));
        line.setDebtValue(1000 * 1e8); // 1e18 of supportedToken1 == 1000 * 1e8 (1000 USD)
        assertEq(escrow.getCollateralRatio(), 10000, "cratio should be at 100%"); // cratio is at 100%
        line.setDebtValue(10 * (1000 * 1e8)); // 10x the collateral value (10000 USD)
        assertEq(escrow.getCollateralRatio(), 1000, "cratio should be at 10%"); // 10%
        escrow.addCollateral(1 ether, address(supportedToken2)); // worth 2000 * 1e8 (2000 USD)
        assertEq(escrow.getCollateralRatio(), 3000, "cratio should be at 30%"); // 30%
        escrow.addCollateral(10 ether, address(supportedToken2));
        assertEq(escrow.getCollateralRatio(), 23000, "cratio should be at 230%"); // 230%
    }

    function test_cratio_should_be_0_if_no_collateral() public {
        line.setDebtValue(1000);
        assertEq(escrow.getCollateralRatio(), 0, "cratio should be 0");
    }

    function test_cratio_values_with_eip4626() public {
        token4626.setAssetAddress(address(supportedToken2));
        token4626.setAssetMultiplier(2); // share token should be worth double the underlying (which is now supportedToken2)
        _enableCollateral(address(token4626)); // must enable after setAssetAddress for proper token to be used
        escrow.addCollateral(1 ether, address(token4626));
        line.setDebtValue(4000 * 1e8); // 1e18 of supportedToken2 * 2 == 4000 * 1e8 (4000 USD)
        assertEq(escrow.getCollateralRatio(), 10000, "cratio should be 100%");
        line.setDebtValue(10 * (4000 * 1e8)); // 10x the collateral value (40000 USD)
        assertEq(escrow.getCollateralRatio(), 1000, "cratio should be 10%");
        escrow.addCollateral(1 ether, address(supportedToken2)); // worth 2000 * 1e8 (2000 USD)
        assertEq(escrow.getCollateralRatio(), 1500, "cratio should be 15%");
        escrow.addCollateral(10 ether, address(supportedToken2));
        assertEq(escrow.getCollateralRatio(), 6500, "cratio should be 65%");
    }

    function test_can_remove_all_collateral_when_line_repaid() public {
        uint balance = supportedToken1.balanceOf(address(this));
        escrow.addCollateral(1 ether, address(supportedToken1));
        uint balance2 = supportedToken1.balanceOf(address(this));
        assertEq(balance - 1 ether, balance2);

        line.setStatus(LineLib.STATUS.REPAID);
        escrow.releaseCollateral(1 ether, address(supportedToken1), borrower);

        uint balance3 = supportedToken1.balanceOf(address(this));
        assertEq(balance, balance3);
        assertEq(balance2 + 1 ether, balance3);
    }

    function test_cannot_remove_collateral_as_anon() public {
        escrow.addCollateral(1 ether, address(supportedToken1));
        line.setDebtValue(2000 ether);
        hoax(address(0xdebf));
        vm.expectRevert(IEscrow.CallerAccessDenied.selector);
        escrow.releaseCollateral(1 ether, address(supportedToken1), borrower);
    }

    function test_cannot_remove_collateral_when_under_collateralized() public {
        escrow.addCollateral(1 ether, address(supportedToken1));
        line.setDebtValue(2000 ether);
        vm.expectRevert(IEscrow.UnderCollateralized.selector);
        escrow.releaseCollateral(1 ether, address(supportedToken1), borrower);
    }

    function test_cannot_remove_collateral_when_under_collateralized_eip4626() public {
        token4626.setAssetAddress(address(supportedToken1));
        _enableCollateral(address(token4626));  // must enable after setAssetAddress for proper token to be used
        escrow.addCollateral(1 ether, address(token4626));
        line.setDebtValue(2000 ether);
        vm.expectRevert(IEscrow.UnderCollateralized.selector);
        escrow.releaseCollateral(1 ether, address(token4626), borrower);
    }

    function test_can_liquidate_when_cratio_healthy() public {
        escrow.addCollateral(1 ether, address(supportedToken1));
        hoax(arbiter);
        line.liquidate(0, 1 ether, address(supportedToken1), arbiter);
    }

    function test_can_liquidate_when_line_healthy_eip4626() public {
        token4626.setAssetAddress(address(supportedToken1));
        _enableCollateral(address(token4626));  // must enable after setAssetAddress for proper token to be used
        escrow.addCollateral(1 ether, address(token4626));
        hoax(arbiter);
        line.liquidate(0, 1 ether, address(token4626), arbiter);
    }

    function testFail_cannot_add_collateral_if_unsupported_by_oracle() public {
        escrow.addCollateral(1000, address(unsupportedToken));
    }

    function testFail_cannot_add_collateral_if_unsupported_by_oracle_eip4626() public {
        token4626.setAssetAddress(address(unsupportedToken));
        _enableCollateral(address(token4626));
        escrow.addCollateral(1000, address(token4626));
    }

    function test_cannot_send_eth_and_token() public {
        uint borrowerBalance = borrower.balance;
        uint borrowerTokenBalance = supportedToken1.balanceOf(borrower);
        uint escrowBalance = address(escrow).balance;
        vm.expectRevert(LineLib.EthSentWithERC20.selector);
        escrow.addCollateral{value: mintAmount}(mintAmount, address(supportedToken1));
    }





    receive() external payable {}
}
