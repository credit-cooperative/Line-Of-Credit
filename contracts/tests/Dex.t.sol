// SPDX-License-Identifier: GPL-3.0
// Copyright: https://github.com/credit-cooperative/Line-Of-Credit/blob/master/COPYRIGHT.md

 pragma solidity ^0.8.16;

import "forge-std/Test.sol";

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";

import {Denominations} from "chainlink/Denominations.sol";
import {ZeroEx} from "../mock/ZeroEx.sol";
// import {SimpleOracle} from "../mock/SimpleOracle.sol";
import {Oracle} from "../modules/oracle/Oracle.sol";
import {RevenueToken} from "../mock/RevenueToken.sol";
import {SimpleRevenueContract} from "../mock/SimpleRevenueContract.sol";
// import {ILineFactory} from "../interfaces/ILineFactory.sol";
// import {LineFactory} from "../modules/factories/LineFactory.sol";
import {ModuleFactory} from "../modules/factories/ModuleFactory.sol";
import {Spigot} from "../modules/spigot/Spigot.sol";
import {Escrow} from "../modules/escrow/Escrow.sol";
import {SpigotedLine} from "../modules/credit/SpigotedLine.sol";
import {SecuredLine} from "../modules/credit/SecuredLine.sol";
import {ISecuredLine} from "../interfaces/ISecuredLine.sol";
import {LineLib} from "../utils/LineLib.sol";
import {SpigotedLineLib} from "../utils/SpigotedLineLib.sol";
import {ISpigot} from "../interfaces/ISpigot.sol";
import {IEscrow} from "../interfaces/IEscrow.sol";
import {ISpigotedLine} from "../interfaces/ISpigotedLine.sol";
import {ILineOfCredit} from "../interfaces/ILineOfCredit.sol";

/**
 * @dev -   This file tests functionality relating to the removal of native Eth support
 *      -   and scenarios in which native Eth is generated as revenue
 */
contract EthRevenue is Test {
    ModuleFactory moduleFactory;
    // LineFactory lineFactory;

    Oracle oracle;

    Escrow escrow;
    Spigot spigot;

    uint256 mainnetFork;
    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");

    RevenueToken creditToken1;
    RevenueToken creditToken2;

    // Named vars for common inputs
    SimpleRevenueContract revenueContract;

    uint128 constant dRate = 100;
    uint128 constant fRate = 1;
    uint256 constant ttl = 150 days; // allows us t
    uint8 constant ownerSplit = 10; // 10% of all borrower revenue goes to spigot

    uint256 constant MAX_INT = type(uint256).max;
    uint256 constant MAX_REVENUE = MAX_INT / 100;
    uint256 constant REVENUE_EARNED = 100 ether;

    address constant feedRegistry = 0x47Fb2585D2C56Fe188D0E6ec628a38b74fCeeeDf; // Chainlink
    address constant swapTarget = 0xDef1C0ded9bec7F1a1670819833240f027b25EfF; // 0x
    address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    // Line access control vars
    address private arbiter = makeAddr("arbiter");
    address private borrower = makeAddr("borrower");
    address private lender = makeAddr("lender");
    address private externalLender = makeAddr("externalLender");
    address anyone = makeAddr("anyone");

    address[] beneficiaries;
    uint256[] allocations;
    uint256[] debtOwed;
    address[] creditTokens;
    address[] poolAddresses;
    bytes4[] repaymentFuncs;

    // uint256 constant initialBlockNumber = 16_082_690; // Nov-30-2022 12:05:23 PM +UTC
    // uint256 constant finalBlockNumber = 16_155_490; // Dec-24-2022 03:28:23 PM +UTC

    uint256 constant initialBlockNumber = 18_565_510; // Nov-09-2023 12:05:23 PM +UTC

    uint256 constant BORROW_AMOUNT_DAI = 10_000 * 10**18; // $10k USD

    // local vars to prevent stack too deep
    int256 ethPrice;
    int256 daiPrice;
    uint256 tokensBought;
    uint256 ownerTokens;
    uint256 debtUSD;
    uint256 interest;
    uint256 numTokensToRepayDebt;
    uint256 unusedTradedTokens;

    // credit position
    bytes32 id;
    uint256 deposit;
    uint256 principal;
    uint256 interestAccrued;
    uint256 interestRepaid;
    address creditLender;
    bool isOpen;

    RevenueToken supportedToken1;
    RevenueToken supportedToken2;
    RevenueToken unsupportedToken;
    // SimpleOracle oracle;
    SecuredLine line;
    uint mintAmount = 100 ether;
    uint32 minCollateralRatio = 0; // 0%

    uint256 FULL_ALLOC = 100000;



    /**
        In this scenario, a borrower borrows ~$10k worth of DAI (10k DAI).
        Interest is accrued over 24 hours.
        Revenue of 100 Eth is claimed from the revenue contract.
        10% (10 Eth) is stored in spigot as owner tokens.
        90% (90 Eth) is stored in spigot as operator tokens.
        10 Eth is claimed from the Spigot and traded for DAI.
    */

    function setUp() public {
        // create fork at specific block (16_082_690) so we always know the price
        mainnetFork = vm.createFork(MAINNET_RPC_URL, initialBlockNumber);
        vm.selectFork(mainnetFork);
        revenueContract = new SimpleRevenueContract(borrower, Denominations.ETH);

        moduleFactory = new ModuleFactory();
        // lineFactory = new LineFactory(address(moduleFactory), arbiter, address(oracle), payable(swapTarget));

        // ILineFactory.CoreLineParams memory params = ILineFactory.CoreLineParams({
        //     borrower: borrower,
        //     ttl: ttl,
        //     cratio: 0,
        //     revenueSplit: ownerSplit
        // });

        // address securedLine = lineFactory.deploySecuredLineWithConfig(params);

        // Deploy LoC w/o Line Factory


        allocations = new uint256[](1);
        allocations[0] = 100000;

        debtOwed = new uint256[](1);
        debtOwed[0] = 0;

        creditTokens = new address[](1);
        creditTokens[0] = Denominations.ETH;

        poolAddresses = new address[](1);
        poolAddresses[0] = address(0xdedad);

        repaymentFuncs = new bytes4[](1);
        repaymentFuncs[0] = bytes4(keccak256("repay(uint256)"));

        spigot = new Spigot(address(this), borrower);
        oracle = new Oracle(feedRegistry);

        escrow = new Escrow(minCollateralRatio, address(oracle), arbiter, borrower, arbiter);
        line = new SecuredLine(
          address(oracle),
          arbiter,
          borrower,
          payable(swapTarget),
          address(spigot),
          address(escrow),
          150 days,
          0
        );

        beneficiaries = new address[](1);
        beneficiaries[0] = address(line);
        spigot.initialize(beneficiaries, allocations, debtOwed, creditTokens, poolAddresses, repaymentFuncs, arbiter);

        vm.startPrank(arbiter);
        escrow.updateLine(address(line));
        // TODO: is this necessary given the spigot was initialized?
        spigot.updateBeneficiaryInfo(address(line), address(line), allocations[0], creditTokens[0], 0);
        vm.stopPrank();

        line.init();
        vm.startPrank(borrower);
        revenueContract.transferOwnership(address(spigot));
        vm.stopPrank();

        ISpigot.Setting memory settings = ISpigot.Setting({
            ownerSplit: ownerSplit,
            claimFunction: SimpleRevenueContract.sendPushPayment.selector,
            transferOwnerFunction: SimpleRevenueContract.transferOwnership.selector
        });

        vm.startPrank(arbiter);


        line.addSpigot(address(revenueContract), settings);
        vm.stopPrank();

        vm.startPrank(borrower);

        address[] memory newBeneficiaries = new address[](1);
        newBeneficiaries[0] = address(line);

        address[] memory newOperators = new address[](1);
        newOperators[0] = address(line);

        uint256[] memory newAllocations = new uint256[](1);
        newAllocations[0] = 100000;

        address[] memory newCreditTokens = new address[](1);
        newCreditTokens[0] = address(0);

        uint256[] memory newOutstandingDebts = new uint256[](1);

        newOutstandingDebts[0] = 0;
        line.updateBeneficiarySettings(newBeneficiaries, newOperators, newAllocations, newCreditTokens, newOutstandingDebts);
        vm.stopPrank();

        _setupSimulation();
    }

    /*////////////////////////////////////////////////
    ////////////////    TESTS   //////////////////////
    ////////////////////////////////////////////////*/

    function test_can_claimAndTrade_using_0x_mainnet_fork_with_sellAmount_set() public {
        // TODO: figure out why rolling fork doesn't work, causes oracle.getLatestAnswer to revert without reason
        // vm.selectFork(mainnetFork);

        // // move forward in time to accrue interest
        // emit log_named_uint("timestamp before", block.timestamp);
        // vm.rollFork(mainnetFork, finalBlockNumber);
        // emit log_named_uint("timestamp after", block.timestamp);

        vm.warp(block.timestamp + 24 hours);
        (principal, interest) = line.updateOutstandingDebt();
        debtUSD = principal + interest;
        emit log_named_uint("debtUSD", debtUSD);

        // Claim revenue to the spigot
        spigot.claimRevenue(
            address(revenueContract),
            Denominations.ETH,
            abi.encode(SimpleRevenueContract.sendPushPayment.selector)
        );
        assertEq(address(spigot).balance, REVENUE_EARNED);

        // Distribute funds from the spigot to beneficiaries (just the line)
        spigot.distributeFunds(Denominations.ETH);

        // owner split should be 10% of claimed revenue
        // ownerTokens = spigot.getLenderTokens(spigot.owner(), Denominations.ETH);
        ownerTokens = spigot.getOwnerTokens(Denominations.ETH);
        emit log_named_uint("ownerTokens ETH", ownerTokens);
        emit log_named_uint("line balance: ", address(line).balance);
        assertEq(ownerTokens, REVENUE_EARNED / ownerSplit);

        /*
            0x API call designating the sell amount:
            https://api.0x.org/swap/v1/quote?buyToken=DAI&sellToken=ETH&sellAmount=10000000000000000000
        */
        bytes memory tradeData = hex"415565b0000000000000000000000000eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee0000000000000000000000006b175474e89094c44da98b954eedeac495271d0f0000000000000000000000000000000000000000000000008ac7230489e8000000000000000000000000000000000000000000000000045000fd3924d78851da00000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000005000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000040000000000000000000000000eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee0000000000000000000000000000000000000000000000008ac7230489e8000000000000000000000000000000000000000000000000000000000000000000210000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000038000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20000000000000000000000006b175474e89094c44da98b954eedeac495271d0f00000000000000000000000000000000000000000000000000000000000001400000000000000000000000000000000000000000000000000000000000000340000000000000000000000000000000000000000000000000000000000000034000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000008ac7230489e80000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003400000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000012556e69737761705633000000000000000000000000000000000000000000000000000000000000008ac7230489e80000000000000000000000000000000000000000000000000451a990416f1edff3a0000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000e0000000000000000000000000e592427a0aece92de3edee1f18e0157c05861564000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000042c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20001f4a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000646b175474e89094c44da98b954eedeac495271d0f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001b000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000010000000000000000000000006b175474e89094c44da98b954eedeac495271d0f000000000000000000000000000000000000000000000001a893084a4757a1c6000000000000000000000000ad01c20d5886137e056775af56915de824c8fce5000000000000000000000000000000000000000000000000000000000000001c000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000002000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2000000000000000000000000eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee0000000000000000000000000000000000000000000000000000000000000000869584cd00000000000000000000000010000000000000000000000000000000000000110000000000000000000000000000000028769eaf5ed14bd276e61ad288d36389";

        vm.startPrank(arbiter);
        tokensBought = line.claimAndTrade(Denominations.ETH, tradeData);
        vm.stopPrank();

        ownerTokens = spigot.getLenderTokens(spigot.owner(), Denominations.ETH);
        assertEq(ownerTokens, 0);
        assertEq(line.unused(DAI), tokensBought);

        (, uint256 principalTokens, uint256 interestAccruedTokens, , , , , ) = line.credits(line.ids(0));

        numTokensToRepayDebt = principalTokens + interestAccruedTokens;
        emit log_named_uint("numTokensToRepayDebt", numTokensToRepayDebt);

        unusedTradedTokens = tokensBought - numTokensToRepayDebt;
        emit log_named_uint("unusedTradedTokens", unusedTradedTokens);

        vm.startPrank(borrower);
        line.useAndRepay(numTokensToRepayDebt);
        vm.stopPrank();

        uint256 unusedDai = line.unused(DAI);
        emit log_named_uint("unusedDai", unusedDai);

        (principal, interest) = line.updateOutstandingDebt();
        debtUSD = principal + interest;

        emit log_named_uint("principal", principal);
        emit log_named_uint("interest", interest);
        emit log_named_uint("debtUSD", debtUSD);

        uint256 borrowerDaiBalance = IERC20(DAI).balanceOf(borrower);
        vm.startPrank(borrower);
        line.close(line.ids(0));
        line.sweep(borrower, DAI, 0);
        uint256 claimedEth = spigot.claimOperatorTokens(Denominations.ETH);
        vm.stopPrank();

        assertEq(IERC20(DAI).balanceOf(borrower), borrowerDaiBalance + unusedDai);
        assertEq(claimedEth, (REVENUE_EARNED / 100) * 90);

        // withdraw the lender's funds + profit using the original position ID (line.ids(0) is now empty)
        (deposit, , , interestRepaid, , , , ) = line.credits(id);
        vm.startPrank(lender);
        line.withdraw(id, deposit + interestRepaid);
        vm.stopPrank();

        assertEq(address(line).balance, 0, "line should have no more Eth");
        assertEq(IERC20(DAI).balanceOf(address(line)), 0, "line should have no more DAI");
    }

    function test_can_claimAndTrade_using_0x_with_buyAmount_set() public {
        // can't warp more than 24 hours or we get a stale price
        vm.warp(block.timestamp + 24 hours);
        (uint256 principal, uint256 interest) = line.updateOutstandingDebt();
        uint256 debtUSD = principal + interest;

        // Claim revenue to the spigot
        spigot.claimRevenue(
            address(revenueContract),
            Denominations.ETH,
            abi.encode(SimpleRevenueContract.sendPushPayment.selector)
        );
        assertEq(address(spigot).balance, REVENUE_EARNED);

        // Distribute funds from the spigot to beneficiaries (just the line)
        spigot.distributeFunds(Denominations.ETH);

        // owner split should be 10% of claimed revenue
        uint256 ownerTokens = spigot.getOwnerTokens(Denominations.ETH);
        assertEq(ownerTokens, REVENUE_EARNED / ownerSplit);

        // anyonemly send to the contract to see if it affects the trade
        deal(anyone, 25 ether);
        vm.prank(anyone);
        (bool sendSuccess, ) = payable(address(line)).call{value: 25 ether}("");
        assertTrue(sendSuccess);

        /*
            0x API call designating the buy amount:
            https://api.0x.org/swap/v1/quote?buyToken=DAI&sellToken=ETH&buyAmount=20000000000000000000000
        */
        bytes memory tradeData = hex"3598d8ab000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000043c33c193756480000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000042c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20001f4dac17f958d2ee523a2206206994597c13d831ec70000646b175474e89094c44da98b954eedeac495271d0f000000000000000000000000000000000000000000000000000000000000869584cd000000000000000000000000100000000000000000000000000000000000001100000000000000000000000000000000343075906c3c18571ea1fd54f6c2a70a";

        vm.startPrank(arbiter);
        tokensBought = line.claimAndTrade(Denominations.ETH, tradeData);
        vm.stopPrank();
        ownerTokens = spigot.getOwnerTokens(Denominations.ETH);
        emit log_named_uint("tokensBought", tokensBought);
        assertEq(ownerTokens, 0);
        assertEq(line.unused(DAI), tokensBought);

        (, uint256 principalTokens, uint256 interestAccruedTokens, , , , , ) = line.credits(line.ids(0));

        numTokensToRepayDebt = principalTokens + interestAccruedTokens;
        unusedTradedTokens = tokensBought - numTokensToRepayDebt;

        uint256 lineDaiBalance = IERC20(DAI).balanceOf(address(line));
        uint256 unusedDai = line.unused(DAI);

        // repay the full debt
        vm.startPrank(borrower);
        bool repaid = line.useAndRepay(numTokensToRepayDebt);
        assertTrue(repaid);
        vm.stopPrank();

        (principal, interest) = line.updateOutstandingDebt();
        assertEq(principal, 0);
        assertEq(interest, 0);

        // lender withdraws their deposit + interest earned
        (deposit, , , interestRepaid, , , , ) = line.credits(line.ids(0));
        vm.startPrank(lender);
        line.withdraw(line.ids(0), deposit + interestRepaid); //10000.27
        vm.stopPrank();

        vm.startPrank(borrower);
        line.close(line.ids(0));
        vm.stopPrank();
        (, , , , , , , isOpen) = line.credits(line.ids(0));
        assertFalse(isOpen);

        unusedDai = line.unused(DAI);
        uint256 unusedEth = line.unused(Denominations.ETH);
        lineDaiBalance = IERC20(DAI).balanceOf(address(line));

        // check the line's accounting
        assertEq(unusedDai, IERC20(DAI).balanceOf(address(line)), "unused dai should match the dai balance"); // the balance does not match because it hasn't been withdrawn
        // assertEq(unusedEth, address(line).balance, "unused ETH should match the ETH balance");

        // line should be closed anad interest should be 0
        (, , uint256 interestAccruedTokensAfter, , , , , bool lineIsOpen) = line.credits(line.ids(0));
        assertFalse(lineIsOpen);
        assertEq(interestAccruedTokensAfter, 0);

        LineLib.STATUS status = line.status();
        emit log_named_uint("status", uint256(status));
        assertEq(uint256(line.status()), uint256(LineLib.STATUS.REPAID), "Line not repaid");

        uint256 borrowerDaiBalance = IERC20(DAI).balanceOf(borrower);
        uint256 borrowerEthBalance = borrower.balance;

        unusedEth = line.unused(Denominations.ETH);
        emit log_named_uint("unused eth", unusedEth);

        // borrower retrieve the remaining funds from the Line
        emit log_named_uint("status", uint256(line.status()));
        vm.startPrank(borrower);
        line.sweep(borrower, DAI, 0);
        line.sweep(borrower, Denominations.ETH, 0);
        vm.stopPrank();

        assertEq(
            IERC20(DAI).balanceOf(borrower),
            borrowerDaiBalance + unusedDai,
            "borrower DAI balance should have increased"
        );
        assertEq(IERC20(DAI).balanceOf(address(line)), 0, "line's DAI balance should be 0");
        assertEq(borrower.balance, borrowerEthBalance + unusedEth, "borrower's ETH balance should increase");

        // the money sent directly to the contract is locked
        assertEq(address(line).balance, 25 ether, "Line's ETH balance should equal the locked amount after sweep");

        // The line was closed when lender withdrew, so expect a revert
        vm.startPrank(borrower);
        vm.expectRevert(ILineOfCredit.PositionIsClosed.selector);
        line.close(id);
        vm.stopPrank();

    }

    function test_cannot_claim_and_trade_with_insufficient_balance() public {
        // can't warp more than 24 hours or we get a stale price
        vm.warp(block.timestamp + 24 hours);
        (uint256 principal, uint256 interest) = line.updateOutstandingDebt();
        uint256 debtUSD = principal + interest;

        // Claim revenue to the spigot
        spigot.claimRevenue(
            address(revenueContract),
            Denominations.ETH,
            abi.encode(SimpleRevenueContract.sendPushPayment.selector)
        );
        assertEq(address(spigot).balance, REVENUE_EARNED);

        // Distribute funds from the spigot to beneficiaries (just the line)
        spigot.distributeFunds(Denominations.ETH);

        // owner split should be 10% of claimed revenue
        uint256 ownerTokens = spigot.getOwnerTokens(Denominations.ETH);
        assertEq(ownerTokens, REVENUE_EARNED / ownerSplit);

        // anyonemly send to the contract to see if it affects the trade
        deal(anyone, 25 ether);
        vm.prank(anyone);
        (bool sendSuccess, ) = payable(address(line)).call{value: 25 ether}("");
        assertTrue(sendSuccess);

        /*
            0x API call designating the buy amount:
            https://api.0x.org/swap/v1/quote?buyToken=DAI&sellToken=ETH&sellAmount=10000000000000000000
        */
        bytes memory tradeData = hex"415565b0000000000000000000000000eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee0000000000000000000000006b175474e89094c44da98b954eedeac495271d0f0000000000000000000000000000000000000000000000008ac7230489e8000000000000000000000000000000000000000000000000045000fd3924d78851da00000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000005000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000040000000000000000000000000eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee0000000000000000000000000000000000000000000000008ac7230489e8000000000000000000000000000000000000000000000000000000000000000000210000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000038000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20000000000000000000000006b175474e89094c44da98b954eedeac495271d0f00000000000000000000000000000000000000000000000000000000000001400000000000000000000000000000000000000000000000000000000000000340000000000000000000000000000000000000000000000000000000000000034000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000008ac7230489e80000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003400000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000012556e69737761705633000000000000000000000000000000000000000000000000000000000000008ac7230489e80000000000000000000000000000000000000000000000000451a990416f1edff3a0000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000e0000000000000000000000000e592427a0aece92de3edee1f18e0157c05861564000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000042c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20001f4a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000646b175474e89094c44da98b954eedeac495271d0f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001b000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000010000000000000000000000006b175474e89094c44da98b954eedeac495271d0f000000000000000000000000000000000000000000000001a893084a4757a1c6000000000000000000000000ad01c20d5886137e056775af56915de824c8fce5000000000000000000000000000000000000000000000000000000000000001c000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000002000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2000000000000000000000000eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee0000000000000000000000000000000000000000000000000000000000000000869584cd00000000000000000000000010000000000000000000000000000000000000110000000000000000000000000000000028769eaf5ed14bd276e61ad288d36389";

        vm.startPrank(arbiter);
        tokensBought = line.claimAndTrade(Denominations.ETH, tradeData);

        emit log_named_uint("tokens Bought", tokensBought);
        emit log_named_uint("line balance", address(line).balance);
        vm.stopPrank();
    }

    // /*////////////////////////////////////////////////
    // ////////////////    UTILS   //////////////////////
    // ////////////////////////////////////////////////*/

    function _setupSimulation() internal {
        ethPrice = oracle.getLatestAnswer(Denominations.ETH);
        daiPrice = oracle.getLatestAnswer(DAI);
        emit log_named_int("eth price", ethPrice);
        emit log_named_int("dai price", daiPrice);

        deal(DAI, lender, BORROW_AMOUNT_DAI);
        emit log_named_uint("lender dai balance", IERC20(DAI).balanceOf(lender));
        uint256 loanValueUSD = (IERC20(DAI).balanceOf(lender) * uint256(oracle.getLatestAnswer(DAI))) / 10**18; // convert to 8 decimals
        emit log_named_uint("DAI loan value in USD", loanValueUSD);

        // Create the position
        vm.startPrank(borrower);
        line.addCredit(dRate, fRate, BORROW_AMOUNT_DAI, DAI, lender);
        vm.stopPrank();

        startHoax(lender);
        IERC20(DAI).approve(address(line), BORROW_AMOUNT_DAI);
        id = line.addCredit(dRate, fRate, BORROW_AMOUNT_DAI, DAI, lender);
        emit log_named_bytes32("position id", id);
        vm.stopPrank();

        assertEq(IERC20(DAI).balanceOf(address(line)), BORROW_AMOUNT_DAI);
        assertEq(IERC20(DAI).balanceOf(lender), 0);

        // borrow
        vm.startPrank(borrower);
        line.borrow(line.ids(0), BORROW_AMOUNT_DAI, borrower);
        vm.stopPrank();

        assertEq(IERC20(DAI).balanceOf(address(line)), 0);
        assertEq(IERC20(DAI).balanceOf(borrower), BORROW_AMOUNT_DAI);

        // Simulate ETH revenue generation
        deal(address(revenueContract), REVENUE_EARNED);
    }
}
