// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;
import {IERC20Metadata} from "openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";

// Price feed for SBC Polygon
 contract SBCPriceFeedPolygon {

    address SBC = 0xfdcC3dd6671eaB0709A4C0f3F53De9a333d80798; // polygon
    constructor () {}

    function latestRoundData() external view returns (
        uint80 roundId, 
        int256 answer, 
        uint256 startedAt, 
        uint256 updatedAt, 
        uint80 answeredInRound) {
        uint256 decimals = uint256(IERC20Metadata(SBC).decimals());
        return (0, int256(1 * 10 ** decimals), 0, block.timestamp, 0);
    }

    function decimals() external view returns (uint8) {
        return IERC20Metadata(SBC).decimals();
    }
 }