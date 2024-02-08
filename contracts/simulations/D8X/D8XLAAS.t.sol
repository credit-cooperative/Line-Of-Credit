pragma solidity ^0.8.9;

import "forge-std/Test.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {Spigot} from "../../modules/spigot/Spigot.sol";
import {IOracle} from "../../interfaces/IOracle.sol";
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

// zkevm chainlink usdc price feed 0x0167D934CB7240e65c35e347F00Ca5b12567523a

interface IPerpetualTreasury {
    function addLiquidity(uint8 _poolId, uint256 _tokenAmount) external ;
    function withdrawLiquidity(uint8 _poolId, uint256 _shareAmount) external;
    function executeLiquidityWithdrawal(uint8 _poolId, address _lpAddr) external;
    function getShareTokenPriceD18(uint8 _poolId) external returns (uint256 price);
    function getTokenAmountToReturn(uint8 _poolId, uint256 _shareAmount) external ;
}

contract D8XLAAS is Test {
    IPerpetualTreasury public treasury;
    IOracle public oracle;
    IERC20 public usdc;
    IERC20 public lp;
    ISecuredLine public securedLine;
    ISpigotedLine public spigotedLine;
    IEscrow public escrow;
    ISpigot public spigot;
    ISpigot.Setting private settings;

    uint256 MAX_INT =
        115792089237316195423570985008687907853269984665640564039457584007913129639935;

    address constant treasuryAddress = 0xaB7794EcD2c8e9Decc6B577864b40eBf9204720f; //proxy
    //address constant treasuryAddress = 0xa598F5B8336fDD330e7E9AfFb7a19705310fb43F; // implementation
    address USDC = 0xA8CE8aee21bC2A48a5EF670afCc9274C7bbbC035;
    address constant LPShares = 0x7948b01062fc562FA50De8D53e4d6ac1Fa39C7bC;

    address constant borrower = 0xf44B95991CaDD73ed769454A03b3820997f00873;
    address constant lender = 0x9832FD4537F3143b5C2989734b11A54D4E85eEF6;
    address constant operator = 0x97fCbc96ed23e4E9F0714008C8f137D57B4d6C97;

    bytes4 constant increaseLiquidity = IPerpetualTreasury.addLiquidity.selector;
    bytes4 constant decreaseLiquidity = IPerpetualTreasury.withdrawLiquidity.selector;
    bytes4 constant executeLiquidityWithdrawal = IPerpetualTreasury.executeLiquidityWithdrawal.selector;
    bytes4 constant getTokenAmountToReturn = IPerpetualTreasury.getTokenAmountToReturn.selector;
    bytes4 constant approveFunc = IERC20.approve.selector;
    bytes4 constant transferFunc = IERC20.transfer.selector;
    bytes4 constant newOwnerFunc = bytes4(0x12345678);
    bytes4 constant claimFunc = bytes4(0x00000000);

    uint256 FORK_BLOCK_NUMBER = 9619636;
    uint256 zkEVMMainnetFork;

    function setUp() public {
        zkEVMMainnetFork = vm.createFork(vm.envString("ZKEMV_RPC_URL"), FORK_BLOCK_NUMBER);
        vm.selectFork(zkEVMMainnetFork);

        deal(USDC, lender, 500000000000);

        spigot = new Spigot(borrower, operator);

        _initSpigot();
        _mintAndApprove();


    }

    function _mintAndApprove() public {
        
        vm.startPrank(lender);
        IERC20(USDC).approve(address(spigot), MAX_INT);
        vm.stopPrank();
    }

    function _initSpigot() public {
        vm.startPrank(borrower);
        settings = ISpigot.Setting(0, claimFunc, newOwnerFunc);
        spigot.addSpigot(treasuryAddress, settings);
        
        spigot.updateWhitelistedFunction(increaseLiquidity, true);
        spigot.updateWhitelistedFunction(decreaseLiquidity, true);
        spigot.updateWhitelistedFunction(executeLiquidityWithdrawal, true);
        vm.stopPrank();
    }

    function test_add_liquidity_with_spigot() public {
        vm.startPrank(lender);
        IERC20(USDC).transfer(address(spigot), 500000000000);
        vm.stopPrank();

        vm.startPrank(address(spigot));
        IERC20(USDC).approve(treasuryAddress, MAX_INT);
        vm.stopPrank();

        vm.startPrank(operator);
        uint8 poolId = 2;
        uint256 tokenAmount = 500000000000;
        bytes memory data = abi.encodeWithSelector(increaseLiquidity, poolId, tokenAmount);
        spigot.operate(treasuryAddress, data);
        vm.stopPrank();
    }

    function test_add_liquidity_with_EOA() public {
        vm.startPrank(lender);
        IERC20(USDC).approve(treasuryAddress, 500000000000);
        uint8 poolId = 2;
        uint256 tokenAmount = 500000000000;
        IPerpetualTreasury(treasuryAddress).addLiquidity(poolId, tokenAmount);
    }

    function test_get_share_price() public {
        uint8 poolId = 2;
        IPerpetualTreasury(treasuryAddress).getShareTokenPriceD18(poolId);
        // bytes memory data = abi.encodeWithSelector(IPerpetualTreasury.getShareTokenPriceD18.selector, poolId);
        // (bool success, bytes memory priceData)= treasuryAddress.call(data);
        //require(success, "failed to get share price");
        // uint256 price = abi.decode(priceData, (uint256));
        // console.log(price);
    }
}