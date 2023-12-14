// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "openzeppelin/token/ERC721/ERC721.sol";
import "openzeppelin/interfaces/IERC721Enumerable.sol";
import "openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
import "forge-std/console.sol";
import {ILineOfCredit} from "../../interfaces/ILineOfCredit.sol";
import {ISpigotedLine} from "../../interfaces/ISpigotedLine.sol";
import {IEscrowedLine} from "../../interfaces/IEscrowedLine.sol";
import {IEscrow} from "../../interfaces/IEscrow.sol";
import {ILendingPositionToken} from "../../interfaces/ILendingPositionToken.sol";

// TODO: Add back IERC721Enumerable and functions or use https://docs.simplehash.com/reference/nfts-by-owners to get owner of token

contract LendingPositionToken is ERC721Pausable, ILendingPositionToken {
    uint256 private _tokenIds;
    mapping(uint256 => address) private tokenToLine;
    mapping(uint256 => uint256) private tokenToOpenProposals;

    
    constructor() ERC721("LendingPositionToken", "LPT") {}

    function mint(address to, address line) public returns (uint256) {
        _tokenIds++;
        uint256 newItemId = _tokenIds;
        tokenToLine[newItemId] = line;
        _mint(to, newItemId);
        return newItemId;
    }

    function openProposal(uint256 tokenId) public {
        require(msg.sender == tokenToLine[tokenId], "Only line can open proposal");
        tokenToOpenProposals[tokenId]++;
    }

    function closeProposal(uint256 tokenId) public {
        require(msg.sender == tokenToLine[tokenId], "Only line can close proposal");
        tokenToOpenProposals[tokenId]--;
    }

    // _beforeTokenTransfer func goes here
    // checks count for a tokenId
    // if count != 0, do not transfer the token


    function getUnderlyingInfo(uint256 tokenId)
        public
        view
        returns (ILendingPositionToken.UnderlyingInfo memory)
    {
        uint256 value = 0;
        address line = tokenToLine[tokenId];

        (ILineOfCredit.Credit memory credit, bytes32 id) = ILineOfCredit(line).getPositionFromTokenId(tokenId);
        
        (uint128 dRate, uint128 fRate) = ILineOfCredit(line).getRates(id);
        uint256 deposit = credit.deposit;
        uint256 principal = credit.principal;
        uint256 interestAccrued = credit.interestAccrued;
        uint256 interestRepaid = credit.interestRepaid;
        uint256 deadline = ILineOfCredit(line).getDeadline();
        uint256 split = ISpigotedLine(line).getSplit();

        address escrow = address(IEscrowedLine(line).escrow());
        uint256 mincratio = IEscrow(escrow).minimumCollateralRatio();

        return
            ILendingPositionToken.UnderlyingInfo(
                line,
                id,
                deposit,
                principal,
                interestAccrued,
                interestRepaid,
                dRate,
                fRate,
                deadline,
                split,
                mincratio
            );
    }

    
    // NOTE: seperate func bc this function changes state
    function getCRatio(uint256 tokenId)
        public
        returns (uint256 )
    {
        address line = tokenToLine[tokenId];
        
        address escrow = address(IEscrowedLine(line).escrow());
        uint256 cratio = IEscrow(escrow).getCollateralRatio();
        return cratio;
    }
}