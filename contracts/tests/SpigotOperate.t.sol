// SPDX-License-Identifier: GPL-3.0
// Copyright: https://github.com/credit-cooperative/Line-Of-Credit/blob/master/COPYRIGHT.md

 pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import {Spigot} from "../modules/spigot/Spigot.sol";
import {SpigotLib} from "../utils/SpigotLib.sol";
import {ISpigot} from "../interfaces/ISpigot.sol";

import {IERC721} from "openzeppelin/token/ERC721/IERC721.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import "forge-std/console.sol";

interface Uni_V3_Manager {
    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }
    
    struct DecreaseLiquidityParams {
        uint256 tokenId;
        uint128 liquidity;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    struct IncreaseLiquidityParams {
        uint256 tokenId;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    struct CollectParams {
        uint256 tokenId;
        address recipient;
        uint128 amount0Max;
        uint128 amount1Max;
    }

    function mint(MintParams calldata params)
        external
        payable
        returns (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        );

    function increaseLiquidity(IncreaseLiquidityParams calldata params)
        external
        payable
        returns (
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        );
    
    function decreaseLiquidity(DecreaseLiquidityParams calldata params)
        external
        payable
        returns (uint256 amount0, uint256 amount1);

    function positions(uint256 tokenId)
        external
        view
        returns (
            uint96 nonce,
            address operator,
            address token0,
            address token1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        );

    function collect(CollectParams calldata params) external payable returns (uint256 amount0, uint256 amount1);
}

contract SpigotOperateTest is Test {
    
    // https://etherscan.io/address/0xc36442b4a4522e871399cd717abdd847ab11fe88#writeProxyContract

    // spigot contracts/configurations to test against
    address private revenueContract;
    Spigot private spigot;
    ISpigot.Setting private settings;

    Uni_V3_Manager.MintParams private mintParams;
    Uni_V3_Manager.DecreaseLiquidityParams private decreaseLiquidityParams;
    Uni_V3_Manager.IncreaseLiquidityParams private increaseLiquidityParams;
    Uni_V3_Manager.CollectParams private collectParams;

    // Named vars for common inputs
    uint256 constant MAX_REVENUE = type(uint256).max / 100;
    // function signatures for mock revenue contract to pass as params to spigot
    bytes4 constant decreaseLiquidityFunc = Uni_V3_Manager.decreaseLiquidity.selector;
    bytes4 constant transferNFTFunc = bytes4(keccak256("transferFrom(address from, address to, uint256 tokenId)"));
    bytes4 constant claimFeesFunc = Uni_V3_Manager.collect.selector;
    bytes4 constant getPosiionData = bytes4(keccak256("positions(uint256 tokenId)"));
    bytes4 constant approveTransferFunc = bytes4(keccak256("approve(address to, uint256 tokenId)"));
    bytes4 constant mint = bytes4(keccak256("mint(MintParams calldata params)"));
    bytes4 constant burn = bytes4(keccak256("burn(uint256 tokenId)"));
    bytes4 constant newOwnerFunc = bytes4(0x12345678);
    bytes4 constant claimFunc = bytes4(0x00000000);

    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    address constant UNI_V3_POSITION_MANAGER = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;

    uint256 tokenId = 644806;

    // create dynamic arrays for function args
    // Mostly unused in tests so convenience for empty array
    bytes4[] private whitelist;
    address[] private c;
    ISpigot.Setting[] private s;

    // Spigot Controller access control vars
    address owner = 0x9832FD4537F3143b5C2989734b11A54D4E85eEF6;
    address operator = 0xf44B95991CaDD73ed769454A03b3820997f00873;
    address oldNFTOOwner = 0xFeDeA1edcc9a5303ade7bcA74edDeC32fcCC73D8;

    uint256 MAX_INT =
        115792089237316195423570985008687907853269984665640564039457584007913129639935;
    uint256 mintAmount = 100000 ether;

    // Fork Settings
    uint256 constant FORK_BLOCK_NUMBER = 18_984_654; // Forking mainnet at block on 7/6/23 at 7 40 PM EST
    uint256 ethMainnetFork;


    function setUp() public {
        ethMainnetFork = vm.createFork(vm.envString("MAINNET_RPC_URL"), FORK_BLOCK_NUMBER);
        vm.selectFork(ethMainnetFork);
        
        spigot = new Spigot(owner, operator);
        
        // _mintAndApprove();
        _configureSpigot();
             
    }

    function _mintAndApprove() public {
        
        // deal(WETH, (spigot), mintAmount);
        // deal(USDC, operator, mintAmount);
        
        vm.startPrank(owner);
        IERC20(WETH).approve(address(spigot), MAX_INT);
        IERC20(USDC).approve(address(spigot), MAX_INT);
        
        IERC20(WETH).approve(UNI_V3_POSITION_MANAGER, MAX_INT);
        IERC20(USDC).approve(UNI_V3_POSITION_MANAGER, MAX_INT);
        
        vm.stopPrank();
    }

    function _configureSpigot() public {
        vm.startPrank(owner);
        settings = ISpigot.Setting(0, claimFunc, newOwnerFunc);
        spigot.addSpigot(UNI_V3_POSITION_MANAGER, settings);
        
        spigot.updateWhitelistedFunction(decreaseLiquidityFunc, true);
        spigot.updateWhitelistedFunction(transferNFTFunc, true);
        spigot.updateWhitelistedFunction(claimFeesFunc, true);

        spigot.updateWhitelistedFunction(approveTransferFunc, false);
        spigot.updateWhitelistedFunction(transferNFTFunc, false);
        vm.stopPrank();
    }

    function test_transfer_ownership() public {
        _transferOwnership();
    }

    function test_claim_fees_univ3() public {

        vm.startPrank(oldNFTOOwner);
        collectParams = Uni_V3_Manager.CollectParams({
            tokenId: tokenId,
            recipient: address(spigot),
            amount0Max: 340282366920938463463374607431768211455,
            amount1Max: 340282366920938463463374607431768211455
        });

        Uni_V3_Manager(UNI_V3_POSITION_MANAGER).collect(collectParams);
        vm.stopPrank();
    }

    function test_operate_univ3() public {
        _transferOwnership();

        vm.startPrank(operator);
        console.log("Spigot address: ", address(spigot));
        console.log("owner", IERC721(UNI_V3_POSITION_MANAGER).ownerOf(tokenId));
        bytes memory functionData = generateClaimFeesData();
        spigot.operate(UNI_V3_POSITION_MANAGER, functionData);
        vm.stopPrank();
    }

    // UTILS

    function _transferOwnership() public {
        vm.startPrank(oldNFTOOwner);
        assertEq(IERC721(UNI_V3_POSITION_MANAGER).ownerOf(tokenId), oldNFTOOwner);

        IERC721(UNI_V3_POSITION_MANAGER).approve(address(spigot), tokenId);
        IERC721(UNI_V3_POSITION_MANAGER).transferFrom(oldNFTOOwner, address(spigot), tokenId);

        assertEq(IERC721(UNI_V3_POSITION_MANAGER).ownerOf(tokenId), address(spigot));
        vm.stopPrank();
    }

    function increaseLiquidity() public {
        increaseLiquidityParams = Uni_V3_Manager.IncreaseLiquidityParams({
            tokenId: tokenId,
            amount0Desired: 1000000000000000000,
            amount1Desired: 1000000000000000000,
            amount0Min: 0,
            amount1Min: 0,
            deadline: block.timestamp + 1000000000000000000
        });

        Uni_V3_Manager(UNI_V3_POSITION_MANAGER).increaseLiquidity(increaseLiquidityParams);
    }

    function generateClaimFeesData() public returns (bytes memory) {
        collectParams = Uni_V3_Manager.CollectParams({
            tokenId: tokenId,
            recipient: address(spigot),
            amount0Max: 340282366920938463463374607431768211455,
            amount1Max: 340282366920938463463374607431768211455
        });
        return abi.encodeWithSelector(claimFeesFunc, collectParams);
    }

    function generateDecreaseLiquidityData() public returns (bytes memory) {
        decreaseLiquidityParams = Uni_V3_Manager.DecreaseLiquidityParams({
            tokenId: tokenId,
            liquidity: 1000000000000000000,
            amount0Min: 0,
            amount1Min: 0,
            deadline: block.timestamp + 1000 seconds
        });

        return abi.encodeWithSelector(decreaseLiquidityFunc, decreaseLiquidityParams);
    }

    function generateTransferNFTData() public returns (bytes memory) {
        return abi.encodeWithSelector(transferNFTFunc, owner, address(spigot), 0);
    }

    function generateApproveTransferData() public returns (bytes memory) {
        return abi.encodeWithSelector(approveTransferFunc, address(spigot), 0);
    }

}
