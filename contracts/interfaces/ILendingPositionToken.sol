// make a new interface for the lending position token

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;


interface ILendingPositionToken {

    struct UnderlyingInfo {
        address line;
        bytes32 id;
        uint256 deposit;
        uint256 principal;
        uint256 interestAccrued;
        uint256 interestRepaid;
        uint128 dRate;
        uint128 fRate;
        uint256 deadline;
        uint256 split;
        uint256 mincratio;
    }

    function mint(address to, address line) external returns (uint256);
    function getUnderlyingInfo(uint256 tokenId) external view returns (UnderlyingInfo memory);
    function getCRatio(uint256 tokenId) external returns (uint256);
    function openProposal(uint256 tokenId) external;
    function closeProposal(uint256 tokenId) external;
}