// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "openzeppelin/token/ERC721/ERC721.sol";

contract LendingPositionToken is ERC721 {
    uint256 private _tokenIds;

    constructor() ERC721("LendingPositionToken", "LPT") {}

    function mint(address to) public returns (uint256) {
        _tokenIds++;
        uint256 newItemId = _tokenIds;
        _mint(to, newItemId);
        return newItemId;
    }

    function getUnderlyingAssets(uint256 tokenId)
        public
        view
        returns (address[] memory)
    {
        // logic to get data from underlying position
    }
}