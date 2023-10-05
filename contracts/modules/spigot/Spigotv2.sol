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


contract ArfRepaymentContract is AccessControl {
    using SafeERC20 for IERC20;

    uint256[] private allocations; // 100000 = 100%. allocation sent to beneficiaries
    address[] private beneficiaries; // Claims on the repayment
    // struct -> address, amount

    uint128 public constant MAX_BENEFICIARIES = 5;
    uint128 public constant MIN_BENEFICIARIES = 1;
    uint256 public constant FULL_ALLOC = 100000;

    // able to perform certain admin actions
    IERC20 repaymentToken;

    uint256 public creditExtended; //

    mapping (address => uint256) beneficiaryOutstandingDebt;

    // ERC1155 token contract address
    IERC1155 public erc1155Token;

    modifier onlyAdmin {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Unauthorised");
        _;
    }

    constructor(
        address _repaymentToken, 
        address _erc1155Address,
        bytes32 _adminMultisig,
        address[] memory _startingBeneficiaries,
        uint256[] memory _startingAllocations
        ) {
        require(_startingBeneficiaries.length == _startingAllocations.length, "Beneficiaries and allocations must be equal length");
        require(_startingBeneficiaries.length >= MIN_BENEFICIARIES, "Must have at least 2 beneficiaries");

        // setup multisig as admin that has signers from the borrower and lenders.
        _setRoleAdmin(DEFAULT_ADMIN_ROLE, _adminMultisig); 

        // What token is being used for repayment
        repaymentToken = IERC20(_repaymentToken);

        // For Arf use case only
        erc1155Token = IERC1155(_erc1155Address);

        allocations = new uint256[](_startingAllocations.length); // setup fee split ratio

        uint256 sum=0;
        for (uint256 i=0; i<allocations.length; i++) {
            sum = sum + allocations[i];
        }

        require(sum == FULL_ALLOC, "Ratio does not equal 100000");

        for (uint256 i = 0; i < _startingAllocations.length; i++) {
            allocations[i] = _startingAllocations[i];
        }

        beneficiaries = new address[](_startingBeneficiaries.length); // setup beneficiaries
        for (uint256 i = 0; i < _startingBeneficiaries.length; i++) {
            beneficiaries[i] = _startingBeneficiaries[i];
        }
    }




    // Split up functions for library: 
    //  - make a beneficiary library 
    //  - and spigot func library (existing spigot functions) 
    //  - and then an abstract for the actual customer implementation
    /*//////////////////////////////////////////////////////
                    BENEFCIARY/ALLOCATION WINDOW
    //////////////////////////////////////////////////////*/

    // do we need a window to add beneficiaries?



    /*//////////////////////////////////////////////////////
                        TRACK DEBT
    //////////////////////////////////////////////////////*/

    // For non CC lenders, we need to track debt as to not overpay. 
    // maybe CC is position 0, and then we can track the debt of the other lenders in the mapping

    
    // map beneficiary to outstanding debt

    /*//////////////////////////////////////////////////////
                        PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////*/

    function distributeFunds() external {
        _distributeFunds();
    }

    /**
        @notice These will differ for every use case. ideally we can make this a library/abstract 
        contract and implement a new one for each use case/borrower
    */

    // Perhaps this contract can hold the 1155 tokens? Kazim asked about this in our original call. 

    // Function to record when 'Request' 721 is minted
    
    // Function to associate 'Claims' 721 to beneficiaries and set the split allocation

    // When 'Credit' 721 is minted, add to 'creditExtended' variable

    // When 'Repayment' 721 is minted, subtract from 'creditExtended' variable and distribute funds to beneficiaries


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
        require(beneficiaries.length < MAX_BENEFICIARIES, "Max beneficiaries");
        require(_newBeneficiary!=address(0), "beneficiary cannot be 0 address");

        for (uint256 i = 0; i < beneficiaries.length; i++) {
            require(beneficiaries[i] != _newBeneficiary, "Duplicate beneficiary");
        }

        _distributeFunds();

        beneficiaries.push(_newBeneficiary);

        _setSplitAllocation(_newAllocation);
    }


    function replaceBeneficiaryAt(uint256 _index, address _newBeneficiary, uint256[] calldata _newAllocation) external onlyAdmin() {
        require(_index >= 1, "Invalid beneficiary to remove");
        require(_newBeneficiary!=address(0), "Beneficiary cannot be 0 address");

        for (uint256 i = 0; i < beneficiaries.length; i++) {
            require(beneficiaries[i] != _newBeneficiary, "Duplicate beneficiary");
        }

        _distributeFunds();
    
        beneficiaries[_index] = _newBeneficiary;

        _setSplitAllocation(_newAllocation);
    }

    /*//////////////////////////////////////////////////////
                        I N T E R N A L                    
    //////////////////////////////////////////////////////*/

    function _amountsFromAllocations(uint256[] memory _allocations, uint256 total) internal pure returns (uint256[] memory newAmounts) {
        newAmounts = new uint256[](_allocations.length);
        uint256 currBalance;
        uint256 allocatedBalance;

        for (uint256 i = 0; i < _allocations.length; i++) {
            if (i == _allocations.length - 1) {
                newAmounts[i] = total - allocatedBalance;
            } else {
                currBalance = (total * _allocations[i]) / (FULL_ALLOC);
                allocatedBalance = allocatedBalance + currBalance;
                newAmounts[i] = currBalance;
            }
        }
        return newAmounts;
    }

    /**
  @notice Internal function to sets the split allocations of fees to send to fee beneficiaries
  @dev The split allocations must sum to 100000.
  @dev smartTreasury must be set for this to be called.
  @param _allocations The updated split ratio.
   */
    function _setSplitAllocation(uint256[] memory _allocations) internal {
        require(_allocations.length == beneficiaries.length, "Invalid length");
        uint256 sum=0;
        for (uint256 i=0; i<_allocations.length; i++) {
            sum = sum + _allocations[i];
        }
        require(sum == FULL_ALLOC, "Ratio does not equal 100000");

        allocations = _allocations;
    }


  /**
  @dev implements deposit()
   */

    function _distributeFunds() internal {

        uint256 _currentBalance;
        _currentBalance = repaymentToken.balanceOf(address(this));

        if (_currentBalance > 0){
            // feeBalances[0] is fee sent to smartTreasury
            uint256[] memory feeBalances = _amountsFromAllocations(allocations, _currentBalance);
    
            for (uint256 a_index = 0; a_index < allocations.length; a_index++){
                repaymentToken.safeTransfer(beneficiaries[a_index], feeBalances[a_index]);
            }
        }
    }
    

 ///////////////////////// VIEW FUNCS //////////////////////////

    function getBeneficiaries() public view returns (address[] memory) { return (beneficiaries); }

    function getSplitAllocation() public view returns (uint256[] memory) { return (allocations); }   
}
