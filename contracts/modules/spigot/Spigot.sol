// SPDX-License-Identifier: GPL-3.0
// Copyright: https://github.com/credit-cooperative/Line-Of-Credit/blob/master/COPYRIGHT.md

pragma solidity ^0.8.16;
import {MutualConsent} from "../../utils/MutualConsent.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";
import {ERC1155} from "openzeppelin/token/ERC1155/ERC1155.sol";
import {IERC1155} from "openzeppelin/token/ERC1155/IERC1155.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "openzeppelin/utils/ReentrancyGuard.sol";
import {LineLib} from "../../utils/LineLib.sol";
import {SpigotState, SpigotLib} from "../../utils/SpigotLib.sol";

import {ISpigot} from "../../interfaces/ISpigot.sol";

import "forge-std/console.sol";

contract Spigot is ISpigot, ReentrancyGuard {
    using SpigotLib for SpigotState;

    SpigotState private state;

    uint128 constant MAX_BENEFICIARIES = 5;
    uint128 constant MIN_BENEFICIARIES = 1;
    uint256 constant FULL_ALLOC = 100000;
    bool init = false;

    constructor(
        address _owner,
        address _operator
        ) {
        state.owner = _owner;
        state.operator = _operator;
    }

    // only callable by owner
    function initialize(
        address[] memory _startingBeneficiaries,
        uint256[] memory _startingAllocations,
        uint256[] memory _debtOwed,
        address[] memory _creditToken,
        address _arbiter
    ) external onlyOwner returns (bool) {
        require(!init, "Already isInitializedialized");
        // TODO: multiple require() statements or single if() statement
        require(_startingBeneficiaries.length == _startingAllocations.length, "Beneficiaries and allocations must be equal length");
        require(_startingBeneficiaries.length <= MAX_BENEFICIARIES, "Max beneficiaries");
        require(_startingBeneficiaries.length == _debtOwed.length, "Debt owed array and beneficiaries must be equal length");
        require(_startingBeneficiaries.length == _creditToken.length, "Repayment token and beneficiaries must be equal length");
        require(_startingBeneficiaries.length >= MIN_BENEFICIARIES, "Must have at least 1 beneficiary");
        // require(_startingBeneficiaries[0] == _owner, "Owner must be the first beneficiary");

        uint256 sum=0;
        for (uint256 i=0; i<_startingAllocations.length; i++) {
            sum = sum + _startingAllocations[i];
        }

        require(sum == FULL_ALLOC, "Allocations array must sum to 100000");

        // setup multisig as admin that has signers from the borrower and lenders.
        // _setRoleAdmin(DEFAULT_ADMIN_ROLE, _adminMultisig);
        for (uint256 i = 0; i < _startingBeneficiaries.length; i++) {
            require(_startingBeneficiaries[i] != address(0), "beneficiary cannot be zero address");
            state.beneficiaries.push(_startingBeneficiaries[i]);
            state.beneficiaryInfo[_startingBeneficiaries[i]].allocation = _startingAllocations[i];
            state.beneficiaryInfo[_startingBeneficiaries[i]].debtOwed = _debtOwed[i];
            state.beneficiaryInfo[_startingBeneficiaries[i]].creditToken = _creditToken[i];
        }

        state.arbiter = _arbiter;
        state.owner = _startingBeneficiaries[0];
        init = true;
    }

    // Modifiers
    modifier onlyOwner() {
        if (msg.sender != state.owner) {
            revert CallerAccessDenied();
        }
        _;
    }

    modifier isInitialized() {
        if (!init) {
            revert NotInitialized();
        }
        _;
    }

    modifier onlyArbiter() {
        if (msg.sender != state.arbiter) {
            revert CallerAccessDenied();
        }
        _;
    }

    modifier onlyOwnerOrArbiter() {
        if (msg.sender != state.owner && msg.sender != state.arbiter) {
            revert CallerAccessDenied();
        }
        _;
    }

    function beneficiaries() external view returns (address[] memory) {
        return state.beneficiaries;
    }

    function owner() external view returns (address) {
        return state.owner;
    }

    function operator() external view returns (address) {
        return state.operator;
    }

    function arbiter() external view returns (address) {
        return state.arbiter;
    }

    // ##########################
    // #####     Claimer    #####
    // ##########################

    /**
     * @notice  - Claims revenue tokens from the Spigoted revenue contract and stores them for the Owner and Operator to withdraw later.
     *          - Accepts both push (tokens sent directly to Spigot) and pull payments (Spigot calls revenue contract to claim tokens)
     *          - Calls predefined function in contract settings to claim revenue.
     *          - Automatically sends portion to Treasury and then stores Owner and Operator shares
     *          - There is no conversion or trade of revenue tokens.
     * @dev     - Assumes the only side effect of calling claimFunc on revenueContract is we receive new tokens.
     *          - Any other side effects could be dangerous to the Spigot or upstream contracts.
     * @dev     - callable by anyone
     * @param revenueContract   - Contract with registered settings to claim revenue from
     * @param data              - Transaction data, including function signature, to properly claim revenue on revenueContract
     * @return claimed          -  The amount of revenue tokens claimed from revenueContract and split between `owner` and `treasury`
     */
    function claimRevenue(
        address revenueContract,
        address token,
        bytes calldata data
    ) external  nonReentrant isInitialized returns (uint256 claimed) {
        return state.claimRevenue(revenueContract, token, data);
    }

    /**
     * @notice  - Allows Spigot Owner to claim escrowed revenue tokens
     * @dev     - callable by `owner`
     * @param token     - address of revenue token that is being escrowed by spigot
     * @return claimed  -  The amount of tokens claimed by the `owner`
     */
    function claimOwnerTokens(address token) external isInitialized nonReentrant returns (uint256 claimed) {
        return state.claimOwnerTokens(token);
    }

    /**
     * @notice - Allows Spigot Operator to claim escrowed revenue tokens
     * @dev - callable by `operator`
     * @param token - address of revenue token that is being escrowed by spigot
     * @return claimed -  The amount of tokens claimed by the `operator`
     */
     // claim position 1
    function claimOperatorTokens(address token) external isInitialized nonReentrant returns (uint256 claimed) {
        return state.claimOperatorTokens(token); // maybe need to pass in token
    }
    /*//////////////////////////////////////////////////////
                        PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////*/

    function distributeFunds(address token) external isInitialized returns (uint256[] memory) {
        return state._distributeFunds(token);
    }


    /*//////////////////////////////////////////////////////
                       // ADMIN FUNCTIONS //
    //////////////////////////////////////////////////////*/

    /**
        @notice Adds an address as a beneficiary to the claims
        @dev The new beneficiary will be pushed to the end of the beneficiaries array.
        The new allocations must include the new beneficiary
        @dev There is a maximum of 5 beneficiaries which can be registered with the repayments collector
        @param beneficiary The new beneficiary to add
   */

    // TODO: add documentation
    // TODO: add limits to when/who can call this function
    function addBeneficiaryAddress(address beneficiary) external isInitialized {
        state.addBeneficiaryAddress(beneficiary);
    }


    // TODO: add documentation
    // TODO: add limits to when/who can call this function
    function replaceBeneficiaryAt(uint256 _index, address _newBeneficiary, uint256[] calldata _newAllocation) external isInitialized {
        state.replaceBeneficiaryAt(_index, _newBeneficiary, _newAllocation);
    }

    // TODO: add documentation
    function updateBeneficiaryInfo(address beneficiary, address newOperator, uint256 allocation, address creditToken, uint256 outstandingDebt) external isInitialized  onlyOwnerOrArbiter {
        state.updateBeneficiaryInfo(beneficiary, newOperator, allocation, creditToken, outstandingDebt);
    }

    // TODO: add docuemntation
    function removeBeneficiary(address beneficiary) external isInitialized onlyArbiter {
        state.removeBeneficiary(beneficiary);
    }


    // TODO: add documentation
    // TODO: add limits to when/who can call this function
    function deleteBeneficiaries() external isInitialized onlyOwner {
        state.deleteBeneficiaries();
    }


    /*//////////////////////////////////////////////////////
                        I N T E R N A L
    //////////////////////////////////////////////////////*/

    // ##########################
    // ##########################
    // #####  OPERATOR    #####
    // ##########################

    /**
     * @notice  - Allows Operator to call whitelisted functions on revenue contracts to maintain their product
     *          - while still allowing Spigot Owner to receive its revenue stream
     * @dev     - cannot call revenueContracts claim or transferOwner functions
     * @dev     - callable by `operator`
     * @param revenueContract   - contract to call. Must have existing settings added by Owner
     * @param data              - tx data, including function signature, to call contract with
     */
    function operate(address revenueContract, bytes calldata data) external isInitialized returns (bool) {
        return state.operate(revenueContract, data);
    }

    // ##########################
    // #####    Maintainer  #####
    // ##########################

    /**
     * @notice  - allows Owner to add a new revenue stream to the Spigot
     * @dev     - revenueContract cannot be address(this)
     * @dev     - callable by `owner`
     * @param revenueContract   - smart contract to claim tokens from
     * @param setting           - Spigot settings for smart contract
     */
    function addSpigot(address revenueContract, Setting memory setting) external isInitialized returns (bool) {
        return state.addSpigot(revenueContract, setting);
    }

    /**

     * @notice  - Uses predefined function in revenueContract settings to transfer complete control and ownership from this Spigot to the Operator
     * @dev     - revenueContract's transfer func MUST only accept one paramteter which is the new owner's address.
     * @dev     - callable by `owner`
     * @param revenueContract - smart contract to transfer ownership of
     */
    function removeSpigot(address revenueContract) external isInitialized returns (bool) {
        return state.removeSpigot(revenueContract);
    }

    // TODO: update this documentation
    /**
     * @notice  - Changes the revenue split between the Treasury and the Owner based upon the status of the Line of Credit
     *          - or otherwise if the Owner and Borrower wish to change the split.
     * @dev     - callable by `owner`
     * @param revenueContract - Address of spigoted revenue generating contract
     * @param ownerSplit - new % split to give owner
     */

    function updateOwnerSplit(address revenueContract, uint8 ownerSplit) external isInitialized returns (bool) {
        return state.updateOwnerSplit(revenueContract, ownerSplit);
    }


    /**
     * @notice  - Update Owner role of Spigot contract.
     *          - New Owner receives revenue stream split and can control Spigot
     * @dev     - callable by `owner`
     * @param newOwner - Address to give control to
     */
    function updateOwner(address newOwner) external isInitialized returns (bool) {
        return state.updateOwner(newOwner);
    }

    /**
     * @notice  - Update Operator role of Spigot contract.
     *          - New Operator can interact with revenue contracts.
     * @dev     - callable by `operator`
     * @param newOperator - Address to give control to
     */
    function updateOperator(address newOperator) external isInitialized returns (bool) {
        return state.updateOperator(newOperator);
    }

    /**
     * @notice  - Allows Owner to whitelist function methods across all revenue contracts for Operator to call.
     *          - Can whitelist "transfer ownership" functions on revenue contracts
     *          - allowing Spigot to give direct control back to Operator.
     * @dev     - callable by `owner`
     * @param func      - smart contract function signature to whitelist
     * @param allowed   - true/false whether to allow this function to be called by Operator
     */
    function updateWhitelistedFunction(bytes4 func, bool allowed) external isInitialized returns (bool) {
        return state.updateWhitelistedFunction(func, allowed);
    }

    // ##########################
    // #####     GETTERS    #####
    // ##########################

    /**
     * @notice  - Retrieve amount of revenue tokens escrowed waiting for claim
     * @param token - Revenue token that is being garnished from spigots
     */
     function getOwnerTokens(address token) external view returns (uint256) {
        return state.ownerTokens[token];
     }

    /**
     * @notice - Retrieve amount of revenue tokens escrowed waiting for claim
     * @param token - Revenue token that is being garnished from spigots
     */
    function getOperatorTokens(address token) external isInitialized view returns (uint256) {
        return state.operatorTokens[token];
    }

        /**
     * @notice - Returns if the function is whitelisted for an Operator to call
               - on the spigoted revenue generating smart contracts.
     * @param func - Function signature to check on whitelist
    */
    function isWhitelisted(bytes4 func) external isInitialized view returns (bool) {
        return state.isWhitelisted(func);
    }

    function getSetting(address revenueContract) external isInitialized view returns (uint8, bytes4, bytes4) {
        return state.getSetting(revenueContract);
    }

    function hasBeneficiaryDebtOutstanding() external  isInitialized view returns (bool) {
        return state.hasBeneficiaryDebtOutstanding();
    }

    receive() external payable {
        return;
    }



 ///////////////////////// VIEW FUNCS //////////////////////////

    function getBeneficiaries() public isInitialized view returns (address[] memory) { return (state.beneficiaries); }

    function getBeneficiaryBasicInfo(address beneficiary) external isInitialized view returns (
        address bennyOperator,
        uint256 allocation,
        address creditToken,
        uint256 debtOwed
    ) {
        return state.getBeneficiaryBasicInfo(beneficiary);
    }

    function getBennyTokenAmount(address beneficiary, address token) public  isInitialized view returns (uint256) {
        return state.getBennyTokenAmount(beneficiary, token);
    }

    function getLenderTokens(address token, address lender) external isInitialized view returns (uint256) {
        return state.getLenderTokens(token, lender);
    }
    // function getSplitAllocation() public view returns (uint256[] memory) { return (allocations); }
}
