// SPDX-License-Identifier: GPL-3.0
// Copyright: https://github.com/credit-cooperative/Line-Of-Credit/blob/master/COPYRIGHT.md

pragma solidity ^0.8.16;
import {Denominations} from "chainlink/Denominations.sol";
import {MutualConsent} from "../utils/MutualConsent.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";
import {ERC1155} from "openzeppelin/token/ERC1155/ERC1155.sol";
import {IERC1155} from "openzeppelin/token/ERC1155/IERC1155.sol";


contract ArfRevenueContract is Ownable, MutualConsent {

    // able to perform certain admin actions
    address public manager;
    IERC20 revenueToken;

    // ERC1155 token contract address
    address public erc1155Address;


    // Events
    event Repaid(address indexed payer, uint256 amount, uint256 tokenId);
    event MetadataUpdated(uint256 tokenId, string newMetadata);

    constructor(address _owner, address token, address _erc1155Address) Ownable(_owner) {
        manager = _owner;
        revenueToken = IERC20(token);
        erc1155Address = _erc1155Address;
    }


    function setERC1155Address(address _erc1155Address) external mutualConsent(manager, owner()) {
        erc1155Address = _erc1155Address;
    }

    // Function to repay a loan
    function repayLoan(string memory newMetadata, uint256 amount) external payable {

        // based on metadata, update loan to reflect whether or not loan has been fully repaid

        // Transfer repaid funds to the owner
        revenueToken.transferFrom(msg.sender, address(this), amount);
    }

    // Function to update metadata of a token
    function updateMetadata(uint256 tokenId, string memory newMetadata) external {
        // allows the updating of info on a 1155 token stored in contract based on off chain activity 
    }

    // Functions to withdraw funds from contract
    function claimPullPayment() external returns (bool) {
        require(msg.sender == owner(), "Revenue: Only owner can claim");
        if (address(revenueToken) != Denominations.ETH) {
            require(revenueToken.transfer(owner(), revenueToken.balanceOf(address(this))), "Revenue: bad transfer");
        } else {
            payable(owner()).transfer(address(this).balance);
        }
        return true;
    }

    function sendPushPayment() external returns (bool) {
        if (address(revenueToken) != Denominations.ETH) {
            require(revenueToken.transfer(owner(), revenueToken.balanceOf(address(this))), "Revenue: bad transfer");
        } else {
            payable(owner()).transfer(address(this).balance);
        }
        return true;
    }
    

    // set a new manager
    function setManager(address newManager) external mutualConsent(manager, owner()) {
        require(newManager != address(0), "Zero address not valid");
        manager = newManager;
    }
}
