pragma solidity ^0.8.9;

import "forge-std/Test.sol";
import {ISpigotedLine} from "contracts/interfaces/ISpigotedLine.sol";
import {ILineOfCredit} from "contracts/interfaces/ILineOfCredit.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";

contract RainRe7Sim is Test {
    ISpigotedLine spigotedLine;

    // Fork Settings
    uint256 constant FORK_BLOCK_NUMBER = 20_565_270; // Forking mainnet at block on 7/6/23 at 7 40 PM EST
    uint256 ethMainnetFork;

    address Rainline = 0x49845fcf0934a3114424fcf4a0ebf7f537d24dae;
    address spigot = 0x78176f8723F48a72FE9d2bE10D456529a77F7458;
    address servicer = 0xeb0566b1EF38B95da2ed631eBB8114f3ac7b9a8a;

    address claimToken = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address creditToken = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    bytes memory tradeData = hex"d9627aa400000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000178000000000000000000000000000000000000000000000000000000000000017200000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000002000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec7000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48869584cd00000000000000000000000002a4d738d10c6560516fe4a4748d2f7a8bac24e700000000000000000000000000000000000000003adff5d9ea08dbb81bd2904b";

    function setUp() public {
        ethMainnetFork = vm.createFork(vm.envString("MAINNET_RPC_URL"), FORK_BLOCK_NUMBER);
        vm.selectFork(ethMainnetFork);

        spigotedLine = ISpigotedLine(Rainline);
    }

    function test_claim_and_trade_and_repay() public {
        uint256 claimAmount = IERC20(claimToken).balanceOf(spigot);
        uint256 balanceOfLineBefore = IERC20(creditToken).balanceOf(spigotedLine);

        vm.prank(servicer);
        spigotedLine.claimAndRepay(claimToken, tradeData);

        uint256 balanceOfLineAfter = IERC20(creditToken).balanceOf(spigotedLine);

        assertEq(IERC20(claimToken).balanceOf(spigot), 0);

        assertGt(balanceOfLineAfter, balanceOfLineBefore);






    }

    function test_claim_and_trade() public {
        vm.prank(servicer);
}