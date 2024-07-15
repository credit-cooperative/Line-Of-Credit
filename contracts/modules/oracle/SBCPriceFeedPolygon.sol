// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;
import {IERC20Metadata} from "openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";


// Price feed for Arbitrum stUSD
 contract stUSDPriceFeedArbitrum {

    address sbcUSD = 0xfdcC3dd6671eaB0709A4C0f3F53De9a333d80798;
    constructor () {
    }

    function latestRoundData() external view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) {
        return (0, 1 * 1e18, 0, block.timestamp, 0);
    }

    function decimals() external pure returns (uint8) {
        return IERC20Metadata(sbcUSD).decimals();
    }
 }