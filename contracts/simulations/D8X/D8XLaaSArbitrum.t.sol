pragma solidity ^0.8.9;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";
import {LineFactory} from "../../modules/factories/LineFactory.sol";
import {Spigot} from "../../modules/spigot/Spigot.sol";
import {IArbitrumOracle} from "../../interfaces/IArbitrumOracle.sol";
import {zkEVMOracle} from "../../modules/oracle/zkEVMOracle.sol";
import {LineOfCredit} from "../../modules/credit/LineOfCredit.sol";
import {SpigotedLine} from "../../modules/credit/SpigotedLine.sol";
import {SecuredLine} from "../../modules/credit/SecuredLine.sol";
import {ISpigotedLine} from "../../interfaces/ISpigotedLine.sol";
import {IEscrow} from "../../interfaces/IEscrow.sol";
import {Escrow} from "../../modules/escrow/Escrow.sol";
import {ISpigot} from "../../interfaces/ISpigot.sol";
import {Spigot} from "../../modules/spigot/Spigot.sol";
import {ILineOfCredit} from "../../interfaces/ILineOfCredit.sol";
import {ISecuredLine} from "../../interfaces/ISecuredLine.sol";
import {ILineFactory} from "../../interfaces/ILineFactory.sol";
import {stUSDPriceFeedArbitrum} from "../../modules/oracle/stUSDPriceFeedArbitrum.sol";

// zkevm chainlink usdc price feed 0x0167D934CB7240e65c35e347F00Ca5b12567523a

interface IPerpetualTreasury {
    function addLiquidity(uint8 _poolId, uint256 _tokenAmount) external ;
    function withdrawLiquidity(uint8 _poolId, uint256 _shareAmount) external;
    function executeLiquidityWithdrawal(uint8 _poolId, address _lpAddr) external;
    function getShareTokenPriceD18(uint8 _poolId) external returns (uint256 price);
    function getTokenAmountToReturn(uint8 _poolId, uint256 _shareAmount) external ;
}

contract D8XLaaSArbitrum is Test {
    IPerpetualTreasury public treasury;
    IArbitrumOracle public oracle;
    IERC20 public usdc;
    IERC20 public lp;
    ISecuredLine public securedLine;
    ISpigotedLine public spigotedLine;
    IEscrow public escrow;
    ISpigot public spigot;
    ISpigot.Setting private settings;
    ILineFactory public lineFactory;
    SecuredLine public line;

    uint256 MAX_INT =
        115792089237316195423570985008687907853269984665640564039457584007913129639935;

    address constant lineFactoryAddress = 0xF36399Bf8CB0f47e6e79B1F615385e3A94C8473a;
    uint256 ttl = 30 days;
    
    address constant treasuryAddress = 0x8f8BccE4c180B699F81499005281fA89440D1e95; //proxy
    address stUSD = 0x0022228a2cc5E7eF0274A7Baa600d44da5aB5776; 
    address constant LPShares = 0xC09258f1069a95A489B6E52436f88aC77ffb06db; // stUSD d8x lp shares
    address constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

    address constant arbiter = 0xFE002526dEc5B3e4b5134b75b20c065178323343;
    address constant borrower = 0xf44B95991CaDD73ed769454A03b3820997f00873;
    address constant lender = 0x9832FD4537F3143b5C2989734b11A54D4E85eEF6;
    address constant operator = 0x97fCbc96ed23e4E9F0714008C8f137D57B4d6C97;
    address constant zeroExSwapTarget = 0xDef1C0ded9bec7F1a1670819833240f027b25EfF;
    

    bytes4 constant increaseLiquidity = IPerpetualTreasury.addLiquidity.selector;
    bytes4 constant decreaseLiquidity = IPerpetualTreasury.withdrawLiquidity.selector;
    bytes4 constant executeLiquidityWithdrawal = IPerpetualTreasury.executeLiquidityWithdrawal.selector;
    bytes4 constant getTokenAmountToReturn = IPerpetualTreasury.getTokenAmountToReturn.selector;
    bytes4 constant approveFunc = IERC20.approve.selector;
    bytes4 constant transferFunc = IERC20.transfer.selector;
    bytes4 constant newOwnerFunc = bytes4(0x12345678);
    bytes4 constant claimFunc = bytes4(0x00000000);

    stUSDPriceFeedArbitrum public priceFeed;
    address public arbOracle = 0x47B005bC1AD130D6a61c2d21047Ee84e03e5Aa8f;
    address public owner = 0x539E70A18073436Eef2E3314A540A7c71dD4B57B;

    uint256 FORK_BLOCK_NUMBER = 211_276_876;
    uint256 arbitrumFork;
    uint256 lentAmount = 400000 * 10**18;
    address lineAddress; 

    function setUp() public {
        arbitrumFork = vm.createFork(vm.envString("ARBITRUM_RPC_URL"), FORK_BLOCK_NUMBER);
        vm.selectFork(arbitrumFork);
        
        oracle = IArbitrumOracle(arbOracle);

        priceFeed = new stUSDPriceFeedArbitrum();
        vm.startPrank(owner);
        oracle.setPriceFeed(stUSD, address(priceFeed));
        vm.stopPrank();
        
        console.log("here");

        deal(stUSD, lender, lentAmount);

        console.log("here 2");

        lineAddress = _deployLoCWithConfig(LineFactory(lineFactoryAddress));

        line = SecuredLine(payable(lineAddress));

        spigot = ISpigotedLine(line).spigot();

        console.log("here 2");

        _initSpigot();
        _mintAndApprove();

    }

    function _deployLoCWithConfig(LineFactory lineFactory) internal returns (address){
        // create Escrow and Spigot
        escrow = new Escrow(0, address(oracle), borrower, borrower);
        spigot = new Spigot(borrower, operator);

        // create SecuredLine
        securedLine = new SecuredLine(address(oracle), arbiter, borrower, payable(zeroExSwapTarget), address(spigot), address(escrow), ttl, 100);

        // transfer ownership of both Spigot and Escrow to SecuredLine
        vm.startPrank(borrower);
        spigot.updateOwner(address(securedLine));
        escrow.updateLine(address(securedLine));
        vm.stopPrank();

        // call init() on Line of Credit, register on Line Factory
        ILineOfCredit(address(securedLine)).init();
        console.log("3");

        // Arbiter registers Spigot, Escrow, and SecuredLine using Factory Contracts to appear in Subgraph & Dapp
        vm.startPrank(arbiter);

        lineFactory.registerSecuredLine(address(securedLine), address(spigot), address(escrow), borrower, operator, 100, 0);

        vm.stopPrank();

        return address(securedLine);
    }

    function _mintAndApprove() public {
        
        vm.startPrank(lender);
        IERC20(stUSD).approve(address(spigot), MAX_INT);
        IERC20(stUSD).approve(address(line), MAX_INT);
        vm.stopPrank();

        vm.startPrank(borrower);
        IERC20(stUSD).approve(address(spigot), MAX_INT);
        vm.stopPrank();


    }

    function _initSpigot() public {
        vm.startPrank(arbiter);
        settings = ISpigot.Setting(0, claimFunc, newOwnerFunc);
        line.addSpigot(treasuryAddress, settings);
        
        line.updateWhitelist(increaseLiquidity, true);
        line.updateWhitelist(decreaseLiquidity, true);
        line.updateWhitelist(executeLiquidityWithdrawal, true);
        vm.stopPrank();
    }

    function _addCredit() internal {
        vm.startPrank(lender);
        ILineOfCredit(lineAddress).addCredit(700, 700, lentAmount, stUSD, lender);
        vm.stopPrank();

        vm.startPrank(borrower);
        ILineOfCredit(lineAddress).addCredit(700, 700, lentAmount, stUSD, lender);
        vm.stopPrank();
    }

    // NOTE: This is a simple end to end test of D8X

    function test_add_liquidity_with_spigot_and_then_remove_liquidity_arb() public {
        _addCredit();

        bytes32 id = line.ids(0);

        vm.startPrank(borrower);
        ILineOfCredit(lineAddress).borrow(id, lentAmount);
        
        IERC20(stUSD).transfer(address(spigot), lentAmount);
        vm.stopPrank();

        vm.startPrank(address(spigot));
        IERC20(stUSD).approve(treasuryAddress, MAX_INT);
        vm.stopPrank();

        vm.startPrank(operator);
        uint8 poolId = 3;
        uint256 tokenAmount = lentAmount;
        bytes memory data = abi.encodeWithSelector(increaseLiquidity, poolId, tokenAmount);
        spigot.operate(treasuryAddress, data);
        vm.stopPrank();

        uint256 balanceAfter = IERC20(LPShares).balanceOf(address(spigot));
        uint8 decimals = IERC20Metadata(LPShares).decimals();
        console.log(balanceAfter/(10**decimals));
        uint256 price =  IPerpetualTreasury(treasuryAddress).getShareTokenPriceD18(poolId);
        console.log("price of LP tokens",price);
        console.log("balance of LP tokens",balanceAfter);
        console.log("value of LP tokens",balanceAfter*price/(10**decimals));

        bytes memory rmLiquidityData = abi.encodeWithSelector(decreaseLiquidity, poolId, balanceAfter);
        vm.startPrank(operator);
        spigot.operate(treasuryAddress, rmLiquidityData);
        vm.stopPrank();

        uint256 balanceAfterRm = IERC20(LPShares).balanceOf(address(spigot));

        // should be equal bc we need to execute the liquidity withdrawal
        assertEq(balanceAfterRm, balanceAfter);

        vm.roll(block.number + 15000);
        vm.warp(block.timestamp + 50 hours);

        bytes memory executeLiquidityData = abi.encodeWithSelector(executeLiquidityWithdrawal, poolId, address(spigot));
        vm.startPrank(operator);
        spigot.operate(treasuryAddress, executeLiquidityData);
        vm.stopPrank();

        uint256 balanceAfterExec = IERC20(LPShares).balanceOf(address(spigot));
        assertEq(balanceAfterExec, 0);

        uint256 stUSDBalance = IERC20(stUSD).balanceOf(address(spigot));
        console.log(stUSDBalance);

        assertEq(stUSDBalance, lentAmount - 1); // lost a tiny amount to a withdrawal fee maybe?
    }

    function test_add_liquidity_with_EOA() public {
        vm.startPrank(lender);
        IERC20(stUSD).approve(treasuryAddress, lentAmount);
        uint8 poolId = 3;
        uint256 tokenAmount = lentAmount;
        IPerpetualTreasury(treasuryAddress).addLiquidity(poolId, tokenAmount);
    }

    function test_get_share_price() public {
        uint8 poolId = 3;
        IPerpetualTreasury(treasuryAddress).getShareTokenPriceD18(poolId);
        // bytes memory data = abi.encodeWithSelector(IPerpetualTreasury.getShareTokenPriceD18.selector, poolId);
        // (bool success, bytes memory priceData)= treasuryAddress.call(data);
        //require(success, "failed to get share price");
        // uint256 price = abi.decode(priceData, (uint256));
        // console.log(price);
    }

    function test_read_treasury() public {
        uint8 poolId = 3;
        uint256 price =  IPerpetualTreasury(treasuryAddress).getShareTokenPriceD18(poolId);
        console.log(price);

    }
}