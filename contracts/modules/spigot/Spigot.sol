// SPDX-License-Identifier: GPL-3.0
// Copyright: https://github.com/credit-cooperative/Line-Of-Credit/blob/master/COPYRIGHT.md

pragma solidity ^0.8.16;
import {MutualConsent} from "../../utils/MutualConsent.sol";
import {AccessControl} from "openzeppelin/access/AccessControl.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";
import {ERC1155} from "openzeppelin/token/ERC1155/ERC1155.sol";
import {IERC1155} from "openzeppelin/token/ERC1155/IERC1155.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "openzeppelin/utils/ReentrancyGuard.sol";
import {LineLib} from "../../utils/LineLib.sol";
import {SpigotState, SpigotLib} from "../../utils/SpigotLib.sol";

import {ISpigot} from "../../interfaces/ISpigot.sol";


contract Spigot is ISpigot, ReentrancyGuard, AccessControl {
    using SpigotLib for SpigotState;

    SpigotState private state;

    uint128 constant MAX_BENEFICIARIES = 5;
    uint128 constant MIN_BENEFICIARIES = 2;
    uint256 constant FULL_ALLOC = 100000;


    modifier onlyAdmin {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Unauthorised");
        _;
    }

    constructor(
        address owner,
        address[] memory _startingBeneficiaries,
        uint256[] memory _startingAllocations,
        uint256[] memory _debtOwed,
        address[] memory _repaymentToken,
        address _adminMultisig
        ) {
        require(_startingBeneficiaries.length == _startingAllocations.length, "Beneficiaries and allocations must be equal length");
        require(_startingAllocations[0] == 0, "operator must always have 0% allocation. Their split is determined by the rev contracts");
        require(_startingBeneficiaries.length <= MAX_BENEFICIARIES, "Max beneficiaries");
        require(_startingBeneficiaries.length == _debtOwed.length, "Debt owed array and beneficiaries must be equal length");
        require(_startingBeneficiaries.length == _repaymentToken.length, "Repayment token and beneficiaries must be equal length");
        require(_startingBeneficiaries.length >= MIN_BENEFICIARIES, "Must have at least 2 beneficiaries");

        uint256 sum=0;
        for (uint256 i=0; i<_startingAllocations.length; i++) {
            sum = sum + _startingAllocations[i];
        }

        require(sum == FULL_ALLOC, "Ratio does not equal 100000");

        // setup multisig as admin that has signers from the borrower and lenders.
        // _setRoleAdmin(DEFAULT_ADMIN_ROLE, _adminMultisig); 

        for (uint256 i = 0; i < _startingBeneficiaries.length; i++) {
            state.beneficiaries[i] = _startingBeneficiaries[i];
            state.beneficiaryInfo[_startingBeneficiaries[i]].allocation = _startingAllocations[i];
            state.beneficiaryInfo[_startingBeneficiaries[i]].debtOwed = _debtOwed[i];
            state.beneficiaryInfo[_startingBeneficiaries[i]].desiredRepaymentToken = _repaymentToken[i];
        }

        state.operator = _startingBeneficiaries[0];
        state.ccLoc = _startingBeneficiaries[1];
    }

    function lineAddress() external view returns (address) {
        return state.ccLoc;
    }

    function operator() external view returns (address) {
        return state.operator;
    }

    // ##########################
    // #####   Claimoooor   #####
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
    ) external nonReentrant returns (uint256 claimed) {
        return state.claimRevenue(revenueContract, token, data);
    }


    /**
     * @notice - Allows Spigot Operqtor to claim escrowed revenue tokens
     * @dev - callable by `operator`
     * @param token - address of revenue token that is being escrowed by spigot
     * @return claimed -  The amount of tokens claimed by the `operator`
     */

     // claim position 1
    function claimOperatorTokens(address token) external nonReentrant returns (uint256 claimed) {
        return state.claimOperatorTokens(token); // maybe need to pass in token
    }
    /*//////////////////////////////////////////////////////
                        PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////*/

    function distributeFunds(address token) external returns (uint256[] memory) {
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
        @param _newBeneficiary The new beneficiary to add
        @param _newAllocation The new allocation of repayments including the new beneficiary
   */

    function addBeneficiaryAddress(address _newBeneficiary, uint256[] calldata _newAllocation) external onlyAdmin() {
        state.addBeneficiaryAddress(_newBeneficiary, _newAllocation);
    }


    function replaceBeneficiaryAt(uint256 _index, address _newBeneficiary, uint256[] calldata _newAllocation) external onlyAdmin() {
        state.replaceBeneficiaryAt(_index, _newBeneficiary, _newAllocation);
    }

    /*//////////////////////////////////////////////////////
                        I N T E R N A L                    
    //////////////////////////////////////////////////////*/

    



        // ##########################
    // ##### *ring* *ring*  #####
    // #####  OPERATOOOR    #####
    // #####  OPERATOOOR    #####
    // ##########################

    /**
     * @notice  - Allows Operator to call whitelisted functions on revenue contracts to maintain their product
     *          - while still allowing Spigot Owner to receive its revenue stream
     * @dev     - cannot call revenueContracts claim or transferOwner functions
     * @dev     - callable by `operator`
     * @param revenueContract   - contract to call. Must have existing settings added by Owner
     * @param data              - tx data, including function signature, to call contract with
     */
    function operate(address revenueContract, bytes calldata data) external returns (bool) {
        return state.operate(revenueContract, data);
    }

    // ##########################
    // #####  Maintainooor  #####
    // ##########################

    /**
     * @notice  - allows Owner to add a new revenue stream to the Spigot
     * @dev     - revenueContract cannot be address(this)
     * @dev     - callable by `owner`
     * @param revenueContract   - smart contract to claim tokens from
     * @param setting           - Spigot settings for smart contract
     */
    function addSpigot(address revenueContract, Setting memory setting) external returns (bool) {
        return state.addSpigot(revenueContract, setting);
    }

    /**

     * @notice  - Uses predefined function in revenueContract settings to transfer complete control and ownership from this Spigot to the Operator
     * @dev     - revenuContract's transfer func MUST only accept one paramteter which is the new owner's address.
     * @dev     - callable by `owner`
     * @param revenueContract - smart contract to transfer ownership of
     */
    function removeSpigot(address revenueContract) external returns (bool) {
        return state.removeSpigot(revenueContract);
    }

    /**
     * @notice  - Update Owner role of Spigot contract.
     *          - New Owner receives revenue stream split and can control Spigot
     * @dev     - callable by `owner`
     * @param newOwner - Address to give control to
     */
    function updateOwner(address newOwner) external returns (bool) {
        return state.updateOwner(newOwner);
    }

    /**
     * @notice  - Update Operator role of Spigot contract.
     *          - New Operator can interact with revenue contracts.
     * @dev     - callable by `operator`
     * @param newOperator - Address to give control to
     */
    function updateOperator(address newOperator) external returns (bool) {
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
    function updateWhitelistedFunction(bytes4 func, bool allowed) external returns (bool) {
        return state.updateWhitelistedFunction(func, allowed);
    }
     /**
     * @notice  - Changes the revenue split between the Treasury and the Owner based upon the status of the Line of Credit
     *          - or otherwise if the Owner and Borrower wish to change the split.
     * @dev     - callable by `owner`
     * @param revenueContract - Address of spigoted revenue generating contract
     * @param ownerSplit - new % split to give owner
     */

    function updateOwnerSplit(address revenueContract, uint8 ownerSplit) external returns (bool) {
        return state.updateOwnerSplit(revenueContract, ownerSplit);
    }

    /**
     * @notice - Retrieve amount of revenue tokens escrowed waiting for claim
     * @param token - Revenue token that is being garnished from spigots
     */
    function getOperatorTokens(address token) external view returns (uint256) {
        return state.operatorTokens[token];
    }

        /**
     * @notice - Returns if the function is whitelisted for an Operator to call
               - on the spigoted revenue generating smart contracts.
     * @param func - Function signature to check on whitelist
    */
    function isWhitelisted(bytes4 func) external view returns (bool) {
        return state.isWhitelisted(func);
    }

    function getSetting(address revenueContract) external view returns (uint8, bytes4, bytes4) {
        return state.getSetting(revenueContract);
    }

    receive() external payable {
        return;
    }
 
    

 ///////////////////////// VIEW FUNCS //////////////////////////

    function getBeneficiaries() public view returns (address[] memory) { return (state.beneficiaries); }

    function getLenderTokens(address token, address lender) external view returns (uint256) { 
        return state.getLenderTokens(token, lender);
    }
    // function getSplitAllocation() public view returns (uint256[] memory) { return (allocations); }   
}
