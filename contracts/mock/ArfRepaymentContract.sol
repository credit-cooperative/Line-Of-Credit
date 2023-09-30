// SPDX-License-Identifier: GPL-3.0
// Copyright: https://github.com/credit-cooperative/Line-Of-Credit/blob/master/COPYRIGHT.md

pragma solidity ^0.8.16;
import {Denominations} from "chainlink/Denominations.sol";
import {MutualConsent} from "../utils/MutualConsent.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";
import {ERC1155} from "openzeppelin/token/ERC1155/ERC1155.sol";
import {IERC1155} from "openzeppelin/token/ERC1155/IERC1155.sol";


// Interface for the ERC-1155 token contract
interface IERC1155 {
    function balanceOf(address account, uint256 id) external view returns (uint256);
    // Add any other necessary functions you might need to interact with
}

contract ArfRepaymentContract is Ownable, MutualConsent {

    // able to perform certain admin actions
    address public manager;
    IERC20 repaymentToken;

    // ERC1155 token contract address
    IERC1155 public erc1155Token;

        // Mapping of loanId to its respective lenders
    mapping(uint256 => Lender[]) public loanLenders;


    // Events (most likely will be emitted by the 1155 tokens)
    event Repaid(address indexed payer, uint256 amount, uint256 tokenId);
    event MetadataUpdated(uint256 tokenId, string newMetadata);

    constructor(address _owner, address token, address _erc1155Address) Ownable(_owner) {
        manager = _owner;
        repaymentToken = IERC20(token);
        erc1155Token = IERC1155(_erc1155Address);
    }

    // Function to repay a loan. Called by Sender
    function repayLoan(string memory newMetadata, uint256 amount) external payable {

        // based on metadata, update loan to reflect whether or not loan has been fully repaid
        // calls internal function to update metadata
        // Transfer repaid funds to the owner
        repaymentToken.transferFrom(msg.sender, address(this), amount);
    }

    // Function to update metadata of a token
    function updateMetadata(uint256 tokenId, string memory newMetadata) external {
        // calls internal upate metadata function
        // allows the updating of info on a 1155 token stored in contract based on off chain activity 
    }

    function _updateMetadata(uint256 tokenId, string memory newMetadata) internal {
        // do stuff to metadata
    }


    // callable by anyone to sends funds to spigot/owner
    function distributeRevenue(uint256 loanId) external {
        (uint256 totalLoanAmount, uint256 amountRepaid) = erc1155Token.getLoanData(loanId); // assuming this function exists in some form
        require(amountRepaid == totalLoanAmount, "Loan not fully repaid yet");

        (address[] memory lenders, uint256[] memory contributions) = erc1155Token.getLenders(loanId); // getting claims from 1155 token

        // does not handle partial repayments very elegantly. Need to collab with Arf on this.
        uint256 totalRevenue = erc20Token.balanceOf(address(this));
        for (uint i = 0; i < lenders.length; i++) {
            uint256 owed = (contributions[i] * totalRevenue) / totalLoanAmount;
            erc20Token.transfer(lenders[i], owed);
        }
    }
    

    // Sets a new manager. This is useful for certain functions that need to be called by a manager that is seperate from the spigot
    // Example: updating metadata
    function setManager(address newManager) external mutualConsent(manager, owner()) {
        require(newManager != address(0), "Zero address not valid");
        manager = newManager;
    }
}
