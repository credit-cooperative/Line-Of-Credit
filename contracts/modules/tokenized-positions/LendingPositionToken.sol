// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "openzeppelin/token/ERC721/ERC721.sol";
import "openzeppelin/interfaces/IERC721Enumerable.sol";
import {ILineOfCredit} from "../../interfaces/ILineOfCredit.sol";
import {InterestRateCredit} from "../interest-rate/InterestRateCredit.sol";

// TODO: Add back IERC721Enumerable and functions or use https://docs.simplehash.com/reference/nfts-by-owners
contract LendingPositionToken is ERC721 {
    uint256 private _tokenIds;
    mapping(uint256 => address) private tokenToLine;
    InterestRateCredit private interestRateCredit;


    constructor() ERC721("LendingPositionToken", "LPT") {}

    function mint(address to, address line) public returns (uint256) {
        _tokenIds++;
        uint256 newItemId = _tokenIds;
        tokenToLine[newItemId] = line;
        _mint(to, newItemId);
        return newItemId;
    }

    function getUnderlyingAssets(uint256 tokenId)
        public
        view
        returns (uint256)
    {
        uint256 value = 0;
        address line = tokenToLine[tokenId];

        (ILineOfCredit.Credit memory credit, bytes32 id) = ILineOfCredit(line).getPositionFromTokenId(tokenId);
        // TODO: How to get interest rate contract instance?

        (uint128 dRate, uint128 fRate) = ILineOfCredit(line).getRates(id);
        uint256 deposit = credit.deposit;
        uint256 principal = credit.principal;
        uint256 interestAccrued = credit.interestAccrued;
        uint256 interestRepaid = credit.interestRepaid;

        return value;
    }
}