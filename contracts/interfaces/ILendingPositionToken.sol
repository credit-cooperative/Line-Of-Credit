// make a new interface for the lending position token

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface ILendingPositionToken {
    function mint(address to) external returns (uint256);
    function getUnderlyingAssets(uint256 tokenId) external view returns (address[] memory);
}