// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "openzeppelin/token/ERC721/ERC721.sol";
import "openzeppelin/interfaces/IERC721Enumerable.sol";
import "forge-std/console.sol";
import {ILineOfCredit} from "../../interfaces/ILineOfCredit.sol";
import {ISpigotedLine} from "../../interfaces/ISpigotedLine.sol";
import {IEscrowedLine} from "../../interfaces/IEscrowedLine.sol";
import {IEscrow} from "../../interfaces/IEscrow.sol";
import {ILendingPositionToken} from "../../interfaces/ILendingPositionToken.sol";

// TODO: Add back IERC721Enumerable and functions or use https://docs.simplehash.com/reference/nfts-by-owners to get owner of token

contract LendingPositionToken is ERC721, ILendingPositionToken {
    uint256 private _tokenIds;
    mapping(uint256 => address) private tokenToLine;
    mapping(uint256 => uint256) private tokenToOpenProposals;

    // Token Restiction
    mapping(address => bool) private _isTokenRestricted;
    mapping(uint256 => mapping(address => bool)) private _transferApproval;

    constructor() ERC721("LendingPositionToken", "LPT") {}

    function mint(address to, address line, bool iRestricted) public returns (uint256) {
        _tokenIds++;
        uint256 newItemId = _tokenIds;
        tokenToLine[newItemId] = line;
        if (iRestricted) {
            _isTokenRestricted[newItemId] = true;
        }
        _mint(to, newItemId);
        return newItemId;
    }

    function openProposal(uint256 tokenId) public {
        if (msg.sender != tokenToLine[tokenId]){
            revert CallerIsNotLine();
        }
        tokenToOpenProposals[tokenId]++;
    }

    function closeProposal(uint256 tokenId) public {
        if (msg.sender != tokenToLine[tokenId]){
            revert CallerIsNotLine();
        }
        tokenToOpenProposals[tokenId]--;
    }

    function approveTokenTransfer(uint256 tokenId, address to) public {
        if (msg.sender != tokenToLine[tokenId]){
            revert CallerIsNotLine();
        }
        _transferApproval[tokenId][to] = true;
    }

    // checks count for a tokenId
    // if count != 0, do not transfer the token

    function _update(address to, uint256 tokenId, address auth) internal override(ERC721) returns (address) {
        if (tokenToOpenProposals[tokenId] > 0) {
            revert OpenProposals();
        }

        if (_isTokenRestricted[tokenId]) {
            if (_transferApproval[tokenId][to] == false) {
                revert TokenIsRestricted();
            }
        }
        return super._update(to, tokenId, auth);
    }


    function getPositionInfo(uint256 tokenId)
        public
        view
        returns (ILendingPositionToken.PositionInfo memory)
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
        uint256 split = ISpigotedLine(line).defaultRevenueSplit();

        address escrow = address(IEscrowedLine(line).escrow());
        uint256 mincratio = IEscrow(escrow).minimumCollateralRatio();

        return
            ILendingPositionToken.PositionInfo(
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