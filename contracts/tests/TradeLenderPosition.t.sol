// SPDX-License-Identifier: GPL-3.0
// Copyright: https://github.com/credit-cooperative/Line-Of-Credit/blob/master/COPYRIGHT.md

 pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import {Denominations} from "chainlink/Denominations.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {IERC721} from "openzeppelin/token/ERC721/IERC721.sol";

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

contract LenderPositionTest is Test, Events {
    SimpleOracle oracle;
    address borrower;
    address arbiter;
    address lender;
    address lender2;
    address LPTAddress;
    uint256 ttl = 150 days;
    RevenueToken supportedToken1;
    RevenueToken supportedToken2;
    RevenueToken unsupportedToken;
    LineOfCredit line;
    uint256 mintAmount = 100 ether;
    uint256 MAX_INT =
        115792089237316195423570985008687907853269984665640564039457584007913129639935;
    uint256 minCollateralRatio = 1 ether; // 100%
    uint128 dRate = 100;
    uint128 fRate = 1;
    uint256 tokenId;
    bytes32 id;

    function setUp() public {
        borrower = address(10);
        arbiter = address(this);
        lender = address(20);
        lender2 = address(30);

        supportedToken1 = new RevenueToken();
        supportedToken2 = new RevenueToken();
        unsupportedToken = new RevenueToken();

        oracle = new SimpleOracle(
            address(supportedToken1),
            address(supportedToken2)
        );

        line = new LineOfCredit(address(oracle), arbiter, borrower, ttl);
        line.init();

        LPTAddress = address(_deployLendingPositionToken());
        line.initTokenizedPosition(LPTAddress);
        // assertEq(uint256(line.init()), uint256(LineLib.STATUS.ACTIVE));
        _mintAndApprove();
    }

    function _deployLendingPositionToken() internal returns (LendingPositionToken) {
        return new LendingPositionToken();
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
        supportedToken1.approve(address(line), MAX_INT);
        supportedToken2.approve(address(line), MAX_INT);
        unsupportedToken.approve(address(line), MAX_INT);
        vm.stopPrank();

        vm.startPrank(lender);
        supportedToken1.approve(address(line), MAX_INT);
        supportedToken2.approve(address(line), MAX_INT);
        unsupportedToken.approve(address(line), MAX_INT);
        vm.stopPrank();
    }

    function _addCredit(address token, uint256 amount) public {
        vm.startPrank(borrower);
        line.addCredit(dRate, fRate, amount, token, lender);
        vm.stopPrank();
        vm.startPrank(lender);
        vm.expectEmit(false, true, true, false);
        emit Events.SetRates(bytes32(0), dRate, fRate);
        tokenId = line.addCredit(dRate, fRate, amount, token, lender);
        id = line.tokenToPosition(tokenId);
        vm.stopPrank();
    }

    // write a test where a lender adds credit, then the borrower borrows, then the lender trades the nft to lender2
    // then lender2 redeems the nft

    function test_trade_lender_position() public {
        _addCredit(address(supportedToken1), 100 ether);
        vm.startPrank(borrower);
        line.borrow(id, 100 ether, address(this));
        vm.stopPrank();
        vm.startPrank(lender);
        IERC721(LPTAddress).approve(lender2, tokenId);
        vm.stopPrank();
        vm.startPrank(lender2);
        IERC721(LPTAddress).transferFrom(lender, lender2, tokenId);
        vm.stopPrank();

        vm.startPrank(borrower);
        line.depositAndRepay(100 ether);
        vm.stopPrank();

        vm.startPrank(lender);
        vm.expectRevert(ILineOfCredit.CallerAccessDenied.selector);
        line.withdraw(tokenId, 100 ether);
        vm.stopPrank();

        vm.startPrank(lender2);
        line.withdraw(tokenId, 100 ether);
        vm.stopPrank();

    }
}