// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "openzeppelin/token/ERC721/ERC721.sol";
import "openzeppelin/interfaces/IERC721Enumerable.sol";
import "forge-std/console.sol";
import {ILineOfCredit} from "../../interfaces/ILineOfCredit.sol";
import {ISpigotedLine} from "../../interfaces/ISpigotedLine.sol";
import {IEscrowedLine} from "../../interfaces/IEscrowedLine.sol";
import {IEscrow} from "../../interfaces/IEscrow.sol";

// TODO: Add back IERC721Enumerable and functions or use https://docs.simplehash.com/reference/nfts-by-owners
contract LendingPositionToken is ERC721 {
    uint256 private _tokenIds;
    mapping(uint256 => address) private tokenToLine;

    struct UnderlyingPositionInfo {
        address line;
        bytes32 id;
        uint256 deposit;
        uint256 principal;
        uint256 interestAccrued;
        uint256 interestRepaid;
    }

    struct UnderlyingLineInfo {
        uint256 deadline;
        uint256 split;
        uint256 cratio;
    }
    constructor() ERC721("LendingPositionToken", "LPT") {}

    function mint(address to, address line) public returns (uint256) {
        _tokenIds++;
        uint256 newItemId = _tokenIds;
        tokenToLine[newItemId] = line;
        _mint(to, newItemId);
        return newItemId;
    }

    function getUnderlyingPositionInfo(uint256 tokenId)
        public
        view
        returns (UnderlyingPositionInfo memory)
    {
        uint256 value = 0;
        address line = tokenToLine[tokenId];

        (ILineOfCredit.Credit memory credit, bytes32 id) = ILineOfCredit(line).getPositionFromTokenId(tokenId);

        
        
        (uint128 dRate, uint128 fRate) = ILineOfCredit(line).getRates(id);
        uint256 deposit = credit.deposit;
        uint256 principal = credit.principal;
        uint256 interestAccrued = credit.interestAccrued;
        uint256 interestRepaid = credit.interestRepaid;


        return
            UnderlyingPositionInfo(
                line,
                id,
                deposit,
                principal,
                interestAccrued,
                interestRepaid
            );
    }

    function getUnderlyingLineInfo(uint256 tokenId)
        public
        returns (UnderlyingLineInfo memory)
    {
        address line = tokenToLine[tokenId];
        uint256 deadline = ILineOfCredit(line).getDeadline();
        uint256 split = ISpigotedLine(line).getSplit();
        address escrow = address(IEscrowedLine(line).escrow());
        uint256 cratio = IEscrow(escrow).getCollateralRatio();
        return UnderlyingLineInfo(deadline, split, cratio);
    }
}