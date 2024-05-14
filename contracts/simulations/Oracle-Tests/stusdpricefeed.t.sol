   pragma solidity ^0.8.9;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";
import {Spigot} from "../../modules/spigot/Spigot.sol";
import {IArbitrumOracle} from "../../interfaces/IArbitrumOracle.sol";
import {stUSDPriceFeedArbitrum} from "../../modules/oracle/stUSDPriceFeedArbitrum.sol";


contract stUSDPriceFeedArbitrumTest is Test {

    IArbitrumOracle public oracle;
    stUSDPriceFeedArbitrum public priceFeed;
    address public arbOracle = 0x47B005bC1AD130D6a61c2d21047Ee84e03e5Aa8f;
    address public stUSD = 0x0022228a2cc5E7eF0274A7Baa600d44da5aB5776;
    address public owner = 0x539E70A18073436Eef2E3314A540A7c71dD4B57B;

    uint256 FORK_BLOCK_NUMBER = 211_276_876;
    uint256 arbitrumFork;

    function setUp() public {
        arbitrumFork = vm.createFork(vm.envString("ARBITRUM_RPC_URL"), FORK_BLOCK_NUMBER);
        vm.selectFork(arbitrumFork);

        oracle = IArbitrumOracle(arbOracle);
    }

    function test_Latest_Round_Data() public {
        priceFeed = new stUSDPriceFeedArbitrum();
       (,int256 price,,,) = priceFeed.latestRoundData();
       console.log("Price: ", uint256(price)); 
        assertTrue(price > 1, "Price should be greater than 0");
    }

    function test_Decimals() public {
        priceFeed = new stUSDPriceFeedArbitrum();
        uint8 decimals = priceFeed.decimals();
        assertTrue(decimals > 0, "Decimals should be greater than 0");
        assertEq(decimals, 18, "Decimals should be 18");
    }

    function test_Oracle() public {
        priceFeed = new stUSDPriceFeedArbitrum();
        vm.startPrank(owner);
        oracle.setPriceFeed(stUSD, address(priceFeed));
        vm.stopPrank();

        int256 price = oracle.getLatestAnswer(stUSD);
        assertTrue(price > 0, "Price should be greater than 0");

    }




}
   