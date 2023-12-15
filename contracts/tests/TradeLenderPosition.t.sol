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
import {InterestRateCredit} from "../modules/interest-rate/InterestRateCredit.sol";
import {SecuredLine} from "../modules/credit/SecuredLine.sol";
import {Spigot} from "../modules/spigot/Spigot.sol";
import {SimpleRevenueContract} from "../mock/SimpleRevenueContract.sol";
import {IEscrowedLine} from "../interfaces/IEscrowedLine.sol";



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

    address borrower;
    address arbiter;
    address lender;
    address externalLender;
    address lender2;
    address LPTAddress;

    RevenueToken supportedToken1;
    RevenueToken supportedToken2;
    RevenueToken unsupportedToken;


    bytes32 id;

    Escrow escrow;
    Spigot spigot;

    SimpleRevenueContract revenueContract;
    SimpleOracle oracle;
    SecuredLine line;
    uint mintAmount = 1000 ether;
    uint MAX_INT = 115792089237316195423570985008687907853269984665640564039457584007913129639935;
    uint32 minCollateralRatio = 0; // 100%
    uint128 dRate = 1500; // 15%
    uint128 fRate = 1500; // 15%
    uint ttl = 60 days;
    uint8 constant ownerSplit = 50; // 50% of all borrower revenue goes to spigot

    uint256 FULL_ALLOC = 100000;
    uint256 constant REVENUE_EARNED = 500 ether;


    uint256 tokenId;
    uint256 tokenId2;


    address[] beneficiaries;
    uint256[] allocations;
    uint256[] debtOwed;
    address[] creditTokens;

    function setUp() public {
        borrower = address(20);

        lender = address(10);
        lender2 = address(11);
        externalLender = address(30);
        arbiter = address(this);

        supportedToken1 = new RevenueToken();
        supportedToken2 = new RevenueToken();
        unsupportedToken = new RevenueToken();

        revenueContract = new SimpleRevenueContract(borrower, address(supportedToken1));
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

        LPTAddress = address(_deployLendingPositionToken());
        line.initTokenizedPosition(LPTAddress);
        

        allocations = new uint256[](2);
        allocations[0] = 50000;
        allocations[1] = 50000;

        debtOwed = new uint256[](2);
        debtOwed[0] = 0;
        debtOwed[1] = 102.5 ether;
        

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

    function test_token_info_is_same_as_position_info() public {
        _addCredit(address(supportedToken1), 100 ether);

        (uint256 d, uint256 p, uint256 ia, uint256 ir,,,,) = line.credits(id);
        (uint128 dr, uint128 fr) = line.getRates(id);
        uint256 deadline = line.getDeadline();
        uint256 split = line.defaultRevenueSplit();
        uint256 mincratio = escrow.minimumCollateralRatio();


        ILendingPositionToken.UnderlyingInfo memory info = ILendingPositionToken(LPTAddress).getUnderlyingInfo(tokenId);

        assertEq(info.line, address(line));
        assertEq(info.id, id);
        assertEq(info.deposit, d);
        assertEq(info.principal, p);
        assertEq(info.interestAccrued, ia);
        assertEq(info.interestRepaid, ir);
        assertEq(info.dRate, dr);
        assertEq(info.fRate, fr);
        assertEq(info.deadline, deadline);
        assertEq(info.split, split);
        assertEq(info.mincratio, mincratio);
    }

    function test_cannot_trade_if_open_proposal() public {
        _addCredit(address(supportedToken1), 100 ether);

        vm.startPrank(borrower);
        line.borrow(id, 100 ether, address(this));
        vm.stopPrank();

        vm.startPrank(lender);
        line.increaseCredit(tokenId, 100 ether);
        vm.stopPrank();

        vm.startPrank(lender);
        IERC721(LPTAddress).approve(lender2, tokenId);
        vm.stopPrank();

        vm.startPrank(lender2);
        vm.expectRevert(ILendingPositionToken.OpenProposals.selector);
        IERC721(LPTAddress).transferFrom(lender, lender2, tokenId);
        vm.stopPrank();
    }

    function test_can_trade_if_borrower_makes_proposal() public {
        _addCredit(address(supportedToken1), 100 ether);

        vm.startPrank(borrower);
        line.borrow(id, 100 ether, address(this));
        vm.stopPrank();

        vm.startPrank(borrower);
        line.increaseCredit(tokenId, 100 ether);
        vm.stopPrank();

        vm.startPrank(lender);
        IERC721(LPTAddress).approve(lender2, tokenId);
        vm.stopPrank();

        vm.startPrank(lender2);
        IERC721(LPTAddress).transferFrom(lender, lender2, tokenId);
        vm.stopPrank();

        assertEq(IERC721(LPTAddress).ownerOf(tokenId), lender2);
    }

    function test_can_trade_if_proposal_is_made_and_concluded() public {
        _addCredit(address(supportedToken1), 100 ether);

        vm.startPrank(borrower);
        line.borrow(id, 100 ether, address(this));
        vm.stopPrank();

        vm.startPrank(lender);
        line.increaseCredit(tokenId, 10 ether);
        vm.stopPrank();

        vm.startPrank(borrower);
        console.log(supportedToken1.balanceOf(lender));
        line.increaseCredit(tokenId, 10 ether);
        vm.stopPrank();

        vm.startPrank(lender);
        IERC721(LPTAddress).approve(lender2, tokenId);
        vm.stopPrank();

        vm.startPrank(lender2);
        IERC721(LPTAddress).transferFrom(lender, lender2, tokenId);
        vm.stopPrank();

        assertEq(IERC721(LPTAddress).ownerOf(tokenId), lender2);
    }

    function test_can_trade_if_proposal_is_made_and_revoked() public {
        _addCredit(address(supportedToken1), 100 ether);

        vm.startPrank(borrower);
        line.borrow(id, 100 ether, address(this));
        vm.stopPrank();

        vm.startPrank(lender);
        line.increaseCredit(tokenId, 10 ether);
        vm.stopPrank();

        vm.startPrank(lender);
        bytes memory msgData = _generateIncreaseCreditMutualConsentMessageData(
            ILineOfCredit.increaseCredit.selector,
            tokenId,
            10 ether
        );
        line.revokeConsent(tokenId, msgData);
        vm.stopPrank();

        vm.startPrank(lender);
        IERC721(LPTAddress).approve(lender2, tokenId);
        vm.stopPrank();

        vm.startPrank(lender2);
        IERC721(LPTAddress).transferFrom(lender, lender2, tokenId);
        vm.stopPrank();

        assertEq(IERC721(LPTAddress).ownerOf(tokenId), lender2);
    }

    function _generateSetRatesMutualConsentMessageData(
        bytes4 fnSelector,
        uint256 tokenId,
        uint128 drate,
        uint128 frate
    ) internal returns (bytes memory msgData) {
        bytes memory reconstructedArgs = abi.encode(id, drate, frate);
        msgData = abi.encodePacked(fnSelector, reconstructedArgs);
    }

    function _generateIncreaseCreditMutualConsentMessageData(
        bytes4 fnSelector,
        uint256 tokenId,
        uint256 theAmount
    ) internal returns (bytes memory msgData) {
        bytes memory reconstructedArgs = abi.encode(tokenId, theAmount);
        msgData = abi.encodePacked(fnSelector, reconstructedArgs);
    }

}