// SPDX-License-Identifier: GPL-3.0
// Copyright: https://github.com/credit-cooperative/Line-Of-Credit/blob/master/COPYRIGHT.md

 pragma solidity ^0.8.16;

import {ReentrancyGuard} from "openzeppelin/utils/ReentrancyGuard.sol";
import {LineLib} from "../utils/LineLib.sol";
import {ISpigot} from "../interfaces/ISpigot.sol";

struct SpigotState {
    address[] beneficiaries; // Claims on the repayment
    mapping(address => ISpigot.Beneficiary)  beneficiaryInfo; // beneficiary -> info
    address operator;
    address ccLoc; // aka the owner
    mapping(address => uint256) operatorTokens; 
    /// @notice Functions that the operator is allowed to run on all revenue contracts controlled by the Spigot
    mapping(bytes4 => bool) whitelistedFunctions; // function -> allowed
    /// @notice Configurations for revenue contracts related to the split of revenue, access control to claiming revenue tokens and transfer of Spigot ownership
    mapping(address => ISpigot.Setting) settings; // revenue contract -> settings
}

/**
 * @notice - helper lib for Spigot
 * @dev see Spigot docs
 */
library SpigotLib {
    // Maximum numerator for Setting.ownerSplit param to ensure that the Owner can't claim more than 100% of revenue
    uint8 constant MAX_SPLIT = 100;
    // cap revenue per claim to avoid overflows on multiplication when calculating percentages
    uint256 constant MAX_REVENUE = type(uint256).max / MAX_SPLIT;

    function _claimRevenue(
        SpigotState storage self,
        address revenueContract,
        address token,
        bytes calldata data
    ) public returns (uint256 claimed) {
        if (self.settings[revenueContract].transferOwnerFunction == bytes4(0)) {
            revert InvalidRevenueContract();
        }

        uint256 existingBalance = LineLib.getBalance(token);

        if (self.settings[revenueContract].claimFunction == bytes4(0)) {
            // push payments
            revert PushPayment();

            // underflow revert ensures we have more tokens than we started with and actually claimed revenue
        } else {
            // pull payments
            if (bytes4(data) != self.settings[revenueContract].claimFunction) {
                revert BadFunction();
            }
            (bool claimSuccess, ) = revenueContract.call(data);
            if (!claimSuccess) {
                revert ClaimFailed();
            }

            // claimed = total balance - existing balance
            claimed = LineLib.getBalance(token) - existingBalance;
            // underflow revert ensures we have more tokens than we started with and actually claimed revenue
        }

        if (claimed == 0) {
            revert NoRevenue();
        }

        // cap so uint doesnt overflow in split calculations.
        // can sweep by "attaching" a push payment spigot with same token
        if (claimed > MAX_REVENUE) claimed = MAX_REVENUE;

        return claimed;
    }

    /** see Spigot.claimRevenue */
    function claimRevenue(
        SpigotState storage self,
        address revenueContract,
        address token,
        bytes calldata data
    ) external returns (uint256 claimed) {
        claimed = _claimRevenue(self, revenueContract, token, data);

        // splits revenue stream according to Spigot settings
        uint256 operatorTokens = claimed - ((claimed * self.settings[revenueContract].ownerSplit) / 100);
        // update escrowed balance
        self.operatorTokens[token] = self.operatorTokens[token] + operatorTokens;

        emit ClaimRevenue(token, claimed, operatorTokens, revenueContract);

        return claimed;
    }

    /** see Spigot.claimOperatorTokens */
    function claimOperatorTokens(SpigotState storage self, address token) external returns (uint256 claimed) {
        if (msg.sender != self.operator) {
            revert CallerAccessDenied();
        }

        claimed = self.operatorTokens[token];

        if (claimed == 0) {
            revert ClaimFailed();
        }

        self.operatorTokens[token] = 0; // reset before send to prevent reentrancy

        LineLib.sendOutTokenOrETH(token, self.operator, claimed);

        emit ClaimOperatorTokens(token, claimed, self.operator);

        return claimed;
    }

    /** see Spigot.operate */
    function operate(SpigotState storage self, address revenueContract, bytes calldata data) external returns (bool) {
        if (msg.sender != self.operator) {
            revert CallerAccessDenied();
        }

        // extract function signature from tx data and check whitelist
        bytes4 func = bytes4(data);

        if (!self.whitelistedFunctions[func]) {
            revert OperatorFnNotWhitelisted();
        }

        // cant claim revenue via operate() because that fucks up accounting logic. Owner shouldn't whitelist it anyway but just in case
        // also can't transfer ownership so Owner retains control of revenue contract
        if (
            func == self.settings[revenueContract].claimFunction ||
            func == self.settings[revenueContract].transferOwnerFunction
        ) {
            revert OperatorFnNotValid();
        }

        (bool success, ) = revenueContract.call(data);
        if (!success) {
            revert OperatorFnCallFailed();
        }

        return true;
    }


    /** see Spigot.addSpigot */
    function addSpigot(
        SpigotState storage self,
        address revenueContract,
        ISpigot.Setting memory setting
    ) external returns (bool) {
        if (msg.sender != self.owner) {
            revert CallerAccessDenied();
        }

        if (revenueContract == address(this)) {
            revert InvalidRevenueContract();
        }

        // spigot setting already exists
        if (self.settings[revenueContract].transferOwnerFunction != bytes4(0)) {
            revert SpigotSettingsExist();
        }

        // must set transfer func
        if (setting.transferOwnerFunction == bytes4(0)) {
            revert BadSetting();
        }
        if (setting.ownerSplit > MAX_SPLIT) {
            revert BadSetting();
        }

        self.settings[revenueContract] = setting;
        emit AddSpigot(revenueContract, setting.ownerSplit, setting.claimFunction, setting.transferOwnerFunction);

        return true;
    }

    /** see Spigot.removeSpigot */
    function removeSpigot(SpigotState storage self, address revenueContract) external returns (bool) {
        if (msg.sender != self.owner) {
            revert CallerAccessDenied();
        }

        (bool success, ) = revenueContract.call(
            abi.encodeWithSelector(
                self.settings[revenueContract].transferOwnerFunction,
                self.operator // assume function only takes one param that is new owner address
            )
        );
        require(success);

        delete self.settings[revenueContract];
        emit RemoveSpigot(revenueContract);

        return true;
    }

    /** see Spigot.updateOwnerSplit */
    function updateOwnerSplit(
        SpigotState storage self,
        address revenueContract,
        uint8 ownerSplit
    ) external returns (bool) {
        if (msg.sender != self.owner) {
            revert CallerAccessDenied();
        }
        if (ownerSplit > MAX_SPLIT) {
            revert BadSetting();
        }

        self.settings[revenueContract].ownerSplit = ownerSplit;
        emit UpdateOwnerSplit(revenueContract, ownerSplit);

        return true;
    }

    /** see Spigot.updateOwner */
    function updateOwner(SpigotState storage self, address newOwner) external returns (bool) {
        if (msg.sender != self.owner) {
            revert CallerAccessDenied();
        }
        require(newOwner != address(0));
        self.owner = newOwner;
        emit UpdateOwner(newOwner);
        return true;
    }

    /** see Spigot.updateOperator */
    function updateOperator(SpigotState storage self, address newOperator) external returns (bool) {
        if (msg.sender != self.operator && msg.sender != self.owner) {
            revert CallerAccessDenied();
        }
        require(newOperator != address(0));
        self.operator = newOperator;
        emit UpdateOperator(newOperator);
        return true;
    }

    /** see Spigot.updateWhitelistedFunction*/
    function updateWhitelistedFunction(SpigotState storage self, bytes4 func, bool allowed) external returns (bool) {
        if (msg.sender != self.owner) {
            revert CallerAccessDenied();
        }
        self.whitelistedFunctions[func] = allowed;
        emit UpdateWhitelistFunction(func, allowed);
        return true;
    }

    /** see Spigot.isWhitelisted*/
    function isWhitelisted(SpigotState storage self, bytes4 func) external view returns (bool) {
        return self.whitelistedFunctions[func];
    }

    /** see Spigot.getSetting*/
    function getSetting(
        SpigotState storage self,
        address revenueContract
    ) external view returns (uint8, bytes4, bytes4) {
        return (
            self.settings[revenueContract].ownerSplit,
            self.settings[revenueContract].claimFunction,
            self.settings[revenueContract].transferOwnerFunction
        );
    }

    /**
    @dev needs tt
     */
    function _distributeFunds(address revToken) internal {

        uint256 _currentBalance;

        _currentBalance = IERC20(revToken).balanceOf(address(this)) - self.operatorTokens[revToken];

        if (_currentBalance > 0){
            // feeBalances[0] is fee sent to smartTreasury
            uint256[] memory feeBalances = _amountsFromAllocations(allocations, _currentBalance);
    
            for (uint256 a_index = 0; a_index < allocations.length; a_index++){
                // check if revtoken is the same as beneficiary desired token
                // if so, call the spigotTrade function, charge fee??
                IERC20(revToken).safeTransfer(beneficiaries[a_index], feeBalances[a_index]);
            }
        }
    }

        /**
  @notice Internal function to sets the split allocations of fees to send to fee beneficiaries
  @dev The split allocations must sum to 100000.
  @dev smartTreasury must be set for this to be called.
  @param _allocations The updated split ratio.
   */
    function _setSplitAllocation(uint256[] memory _allocations) internal {
        require(_allocations.length == beneficiaries.length, "Invalid length");
        require(_allocations[0] == 0, "operator must always have 0% allocation. Their split is determined by the rev contracts");
        uint256 sum=0;
        for (uint256 i=0; i<_allocations.length; i++) {
            sum = sum + _allocations[i];
        }
        require(sum == FULL_ALLOC, "Ratio does not equal 100000");

        for (uint256 i = 0; i < _startingBeneficiaries.length; i++) {
            state.beneficiaryInfo[i].allocation = _allocations[i];
        }
    }

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

    function addBeneficiaryAddress(address _newBeneficiary, uint256[] calldata _newAllocation) external onlyAdmin() {
        require(beneficiaries.length < MAX_BENEFICIARIES, "Max beneficiaries");
        require(_newBeneficiary!=address(0), "beneficiary cannot be 0 address");

        for (uint256 i = 0; i < beneficiaries.length; i++) {
            require(beneficiaries[i] != _newBeneficiary, "Duplicate beneficiary");
        }

        beneficiaries.push(_newBeneficiary);

        _setSplitAllocation(_newAllocation);
    }


    function replaceBeneficiaryAt(uint256 _index, address _newBeneficiary, uint256[] calldata _newAllocation) external onlyAdmin() {
        require(_index >= 1, "Invalid beneficiary to remove");
        require(_newBeneficiary!=address(0), "Beneficiary cannot be 0 address");

        for (uint256 i = 0; i < beneficiaries.length; i++) {
            require(beneficiaries[i] != _newBeneficiary, "Duplicate beneficiary");
        }
    
        beneficiaries[_index] = _newBeneficiary;

        _setSplitAllocation(_newAllocation);
    }

    function resetAllocation(uint256[] calldata _newAllocation) external onlyAdmin() {
        _setSplitAllocation(_newAllocation);
    }

    function resetDebtOwed(uint256[] calldata _newDebtOwed) external onlyAdmin() {
        require(_newDebtOwed.length == beneficiaries.length, "Invalid length");
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            state.beneficiaryInfo[i].debtOwed = _newDebtOwed[i];
        }
    }

    function updateDesiredRepaymentToken(address[] calldata _newToken) external onlyAdmin() {
        require(_newToken != address(0), "Invalid token");
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            state.beneficiaryInfo[i].desiredRepaymentToken = _newToken;
        }
    }

    // Spigot Events
    event AddSpigot(address indexed revenueContract, uint256 ownerSplit, bytes4 claimFnSig, bytes4 trsfrFnSig);

    event RemoveSpigot(address indexed revenueContract);

    event UpdateWhitelistFunction(bytes4 indexed func, bool indexed allowed);

    event UpdateOwnerSplit(address indexed revenueContract, uint8 indexed split);

    event ClaimRevenue(address indexed token, uint256 indexed amount, uint256 ownerTokens, address revenueContract);

    event ClaimOwnerTokens(address indexed token, uint256 indexed amount, address owner);

    event ClaimOperatorTokens(address indexed token, uint256 indexed amount, address ooperator);

    // Stakeholder Events

    event UpdateOwner(address indexed newOwner);

    event UpdateOperator(address indexed newOperator);

    event UpdateTreasury(address indexed newTreasury);

    // Errors

    error BadFunction();

    error OperatorFnNotWhitelisted();

    error OperatorFnNotValid();

    error OperatorFnCallFailed();

    error ClaimFailed();

    error NoRevenue();

    error UnclaimedRevenue();

    error CallerAccessDenied();

    error BadSetting();

    error InvalidRevenueContract();

    error SpigotSettingsExist();
}
