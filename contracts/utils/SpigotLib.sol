// SPDX-License-Identifier: GPL-3.0
// Copyright: https://github.com/credit-cooperative/Line-Of-Credit/blob/master/COPYRIGHT.md

 pragma solidity ^0.8.16;

import {ReentrancyGuard} from "openzeppelin/utils/ReentrancyGuard.sol";
import {LineLib} from "../utils/LineLib.sol";
import {ISpigot} from "../interfaces/ISpigot.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {Denominations} from "chainlink/Denominations.sol";

struct SpigotState {
    address[] beneficiaries; // Claims on the repayment
    mapping(address => ISpigot.Beneficiary)  beneficiaryInfo; // beneficiary -> info
    address operator;
    address owner;
    address admin;
    address swapTarget;
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

    error TradeFailed();

    using SafeERC20 for IERC20;
    // Maximum numerator for Setting.ownerSplit param to ensure that the Owner can't claim more than 100% of revenue
    uint8 constant MAX_SPLIT = 100;
    // cap revenue per claim to avoid overflows on multiplication when calculating percentages
    uint256 constant MAX_REVENUE = type(uint256).max / MAX_SPLIT;

    error TradeFailed();

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
     * @dev                     - priviliged internal function!
     * @notice                  - dumb func that executes arbitry code against a target contract
     * @param amount            - amount of revenue tokens to sell
     * @param sellToken         - revenue token being sold
     * @param swapTarget        - exchange aggregator to trade against
     * @param zeroExTradeData   - Trade data to execute against exchange for target token/amount
     * @return bool             - if trade was successful
     */
    function trade(
        uint256 amount,
        address sellToken,
        address payable swapTarget,
        bytes calldata zeroExTradeData
    ) public returns (bool) {
        if (sellToken == Denominations.ETH) {
            // if claiming/trading eth send as msg.value to dex
            (bool success, ) = swapTarget.call{value: amount}(zeroExTradeData); // TODO: test with 0x api data on mainnet fork
            if (!success) {
                revert TradeFailed();
            }
        } else {
            IERC20(sellToken).approve(swapTarget, amount);
            (bool success, ) = swapTarget.call(zeroExTradeData);
            if (!success) {
                revert TradeFailed();
            }
        }

        return true;
    }

    // function that calls trade. pass in a lender address and it will trade their tokens for the desired token
    function tradeAndClaim(SpigotState storage self, address lender, address sellToken, address payable swapTarget, bytes calldata zeroExTradeData) external returns (bool) {
        // called from
        uint256 amount = self.beneficiaryInfo[lender].bennyTokens[sellToken];
        uint256 oldTokens = IERC20(self.beneficiaryInfo[lender].repaymentToken).balanceOf(address(this));

        trade(amount, sellToken, swapTarget, zeroExTradeData);

        uint256 boughtTokens = IERC20(self.beneficiaryInfo[lender].repaymentToken).balanceOf(address(this)) - oldTokens;
        IERC20(self.beneficiaryInfo[lender].repaymentToken).safeTransfer(lender, boughtTokens);

        self.beneficiaryInfo[lender].debtOwed -= boughtTokens;
        self.beneficiaryInfo[lender].bennyTokens[sellToken] = 0;
        return true;
    }

    /**
    @dev needs tt
     */
    function trade(
        uint256 amount,
        address sellToken,
        address payable swapTarget,
        bytes calldata zeroExTradeData
    ) public returns (bool) {
        if (sellToken == Denominations.ETH) {
            // if claiming/trading eth send as msg.value to dex
            (bool success, ) = swapTarget.call{value: amount}(zeroExTradeData); // TODO: test with 0x api data on mainnet fork
            if (!success) {
                revert TradeFailed();
            }
        } else {
            IERC20(sellToken).approve(swapTarget, amount);
            (bool success, ) = swapTarget.call(zeroExTradeData);
            if (!success) {
                revert TradeFailed();
            }
        }

        return true;
    }

    // function that calls trade. pass in a lender address and it will trade their tokens for the desired token
    function tradeAndClaim(SpigotState storage self, address lender, address sellToken, address payable swapTarget, bytes calldata zeroExTradeData) external returns (bool) {
        // called from 
        uint256 amount = self.beneficiaryInfo[lender].bennyTokens[sellToken];
        uint256 oldTokens = IERC20(self.beneficiaryInfo[lender].desiredRepaymentToken).balanceOf(address(this));

        trade(amount, sellToken, swapTarget, zeroExTradeData);

        uint256 boughtTokens = IERC20(self.beneficiaryInfo[lender].desiredRepaymentToken).balanceOf(address(this)) - oldTokens;
        
        if (boughtTokens <= self.beneficiaryInfo[lender].debtOwed){
            self.beneficiaryInfo[lender].debtOwed -= boughtTokens;
            IERC20(self.beneficiaryInfo[lender].desiredRepaymentToken).safeTransfer(lender, boughtTokens);
        } else if (boughtTokens > self.beneficiaryInfo[lender].debtOwed){
            IERC20(self.beneficiaryInfo[lender].desiredRepaymentToken).safeTransfer(lender, self.beneficiaryInfo[lender].debtOwed);
            self.operatorTokens[self.beneficiaryInfo[lender].desiredRepaymentToken] = self.operatorTokens[self.beneficiaryInfo[lender].desiredRepaymentToken] + (boughtTokens - self.beneficiaryInfo[lender].debtOwed);
            self.beneficiaryInfo[lender].debtOwed = 0;
        }
        
        return true;
    }

    function _distributeFunds(SpigotState storage self, address revToken) internal returns (uint256[] memory feeBalances) {

        uint256 _currentBalance;
        uint256[] memory feeBalances = new uint256[](self.beneficiaries.length);

        _currentBalance = IERC20(revToken).balanceOf(address(this)) - self.operatorTokens[revToken] - getEscrowedTokens(self, revToken);

        if (_currentBalance > 0){

            uint256[] memory allocations = new uint256[](self.beneficiaries.length);

            for (uint256 i = 0; i < self.beneficiaries.length; i++) {
                allocations[i] = self.beneficiaryInfo[self.beneficiaries[i]].allocation;
            }
            // feeBalances[0] is fee sent to smartTreasury
            feeBalances = _amountsFromAllocations(allocations, _currentBalance);

            for (uint256 i = 0; i < self.beneficiaries.length; i++){
                uint256 debt = self.beneficiaryInfo[self.beneficiaries[i]].debtOwed;

                if (i == 1){
                    IERC20(revToken).safeTransfer(self.beneficiaries[i], feeBalances[i]);
                }
                // check if revtoken is the same as beneficiary desired token
                if (self.beneficiaryInfo[self.beneficiaries[i]].desiredRepaymentToken == revToken){
                    // TODO: I think this can be a helper
                    if (feeBalances[i] <= debt){
                        IERC20(revToken).safeTransfer(self.beneficiaries[i], feeBalances[i]);
                        self.beneficiaryInfo[self.beneficiaries[i]].debtOwed -= feeBalances[i];
                    } else if (feeBalances[i] > debt){
                        IERC20(revToken).safeTransfer(self.beneficiaries[i], debt);
                        self.operatorTokens[revToken] += (feeBalances[i] - debt);
                        self.beneficiaryInfo[self.beneficiaries[i]].debtOwed = 0;
                    }

                } else if (self.beneficiaryInfo[self.beneficiaries[i]].repaymentToken != revToken){
                    self.beneficiaryInfo[self.beneficiaries[i]].bennyTokens[revToken] = self.beneficiaryInfo[self.beneficiaries[i]].bennyTokens[revToken] + feeBalances[i];
                }


            }
        }
        return feeBalances;
    }

    function _amountsFromAllocations(uint256[] memory _allocations, uint256 total) internal pure returns (uint256[] memory newAmounts) {
        newAmounts = new uint256[](_allocations.length);
        uint256 currBalance;
        uint256 allocatedBalance;

        for (uint256 i = 0; i < _allocations.length; i++) {
            if (i == _allocations.length - 1) {
                newAmounts[i] = total - allocatedBalance;
            } else {
                currBalance = (total * _allocations[i]) / (100000);
                allocatedBalance = allocatedBalance + currBalance;
                newAmounts[i] = currBalance;
            }
        }
        return newAmounts;
    }

    function getLenderTokens(SpigotState storage self, address token, address lender) external view returns (uint256) {
        uint256 total;
        total = IERC20(token).balanceOf(address(this)) - self.operatorTokens[token];

        total += total * self.beneficiaryInfo[lender].allocation / 100000; 
        total -= getEscrowedTokens(self, token);
        total += self.beneficiaryInfo[lender].bennyTokens[token];
        return total;
    }

    function isDebt(SpigotState storage self) external view returns (bool) {
        bool isDebt = true;
        for (uint256 i = 0; i < self.beneficiaries.length; i++) {
            if (self.beneficiaryInfo[self.beneficiaries[i]].debtOwed == 0){
                isDebt = false;
            }
        }
        return isDebt;
    }

    function getEscrowedTokens(SpigotState storage self, address token) public view returns (uint256) {
        uint256 totalBennyTokens = 0;
        for (uint256 i = 0; i < self.beneficiaries.length; i++) {
            totalBennyTokens += self.beneficiaryInfo[self.beneficiaries[i]].bennyTokens[token];
        }

        return totalBennyTokens;
    }

////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////// TODO: NEED TO REDO THESE WITH THOMAS ///////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////


        /**
  @notice Internal function to sets the split allocations of fees to send to fee beneficiaries
  @dev The split allocations must sum to 100000.
  @dev smartTreasury must be set for this to be called.
  @param _allocations The updated split ratio.
   */
    function _setSplitAllocation(SpigotState storage self, uint256[] memory _allocations) internal {
        require(_allocations.length == self.beneficiaries.length, "Invalid length");
        require(_allocations[0] == 0, "operator must always have 0% allocation. Their split is determined by the rev contracts");
        uint256 sum=0;
        for (uint256 i=0; i<_allocations.length; i++) {
            sum = sum + _allocations[i];
        }
        require(sum == 100000, "Ratio does not equal 100000");

        for (uint256 i = 0; i < self.beneficiaries.length; i++) {
            self.beneficiaryInfo[self.beneficiaries[i]].allocation = _allocations[i];
        }
    }

    

    // TODO: add docuementation
    function addBeneficiaryAddress(SpigotState storage self, address _newBeneficiary, uint256[] calldata _newAllocation) external {
        require(self.beneficiaries.length < 5, "Max beneficiaries");
        require(_newBeneficiary!=address(0), "beneficiary cannot be 0 address");

        for (uint256 i = 0; i < self.beneficiaries.length; i++) {
            require(self.beneficiaries[i] != _newBeneficiary, "Duplicate beneficiary");
        }

        self.beneficiaries.push(_newBeneficiary);

        _setSplitAllocation(self, _newAllocation);
    }

    // TODO: add documentation
    function replaceBeneficiaryAt(SpigotState storage self, uint256 _index, address _newBeneficiary, uint256[] calldata _newAllocation) external {
        require(_index >= 1, "Invalid beneficiary to remove");

        // TODO: we need a way to remove beneficiaries. easiest way to do this would be to
        // replace the beneficiares in the array
        require(_newBeneficiary!=address(0), "Beneficiary cannot be 0 address");

        for (uint256 i = 0; i < self.beneficiaries.length; i++) {
            require(self.beneficiaries[i] != _newBeneficiary, "Duplicate beneficiary");
        }

        self.beneficiaries[_index] = _newBeneficiary;

        _setSplitAllocation(self, _newAllocation);
    }

    // TODO: add docuementation
    // TODO: needs restrictions on who/when can be called
    function resetAllocation(SpigotState storage self, uint256[] calldata _newAllocation) external {
        _setSplitAllocation(self, _newAllocation);
    }

    // TODO: add docuementation
    // TODO: needs restrictions on who/when can be called
    function resetDebtOwed(SpigotState storage self, uint256[] calldata _newDebtOwed) external {
        require(_newDebtOwed.length == self.beneficiaries.length, "Invalid length");
        for (uint256 i = 0; i < self.beneficiaries.length; i++) {
            self.beneficiaryInfo[self.beneficiaries[i]].debtOwed = _newDebtOwed[i];
        }
    }

    // TODO: add docuementation
    // TODO: needs restrictions on who/when can be called
    // function updateRepaymentToken(SpigotState storage self, address[] calldata _newToken) external {

    //     for (uint256 i = 0; i < self.beneficiaries.length; i++) {
    //         require(_newToken[i] != address(0), "Invalid token");
    //         self.beneficiaryInfo[self.beneficiaries[i]].repaymentToken = _newToken[i];
    //     }
    // }

    // TODO: add documentation
    // TODO: needs restrictions on who/when can be called
    // function updateBeneficiaryInfo(SpigotState storage self, address beneficiary, address newOperator, uint256 newAllocation, address newRepaymentToken, uint256 newOutstandingDebt) external {

    //     // Delete the existing Beneficiary to reset bennyTokens mapping
    //     delete self.beneficiaryInfo[beneficiary];

    //     // update variables
    //     self.beneficiaryInfo[beneficiary].bennyOperator = newOperator;
    //     self.beneficiaryInfo[beneficiary].allocation = newAllocation;
    //     self.beneficiaryInfo[beneficiary].repaymentToken = newRepaymentToken;
    //     self.beneficiaryInfo[beneficiary].debtOwed = newOutstandingDebt;

    // }


    function getLenderTokens(SpigotState storage self, address token, address lender) external view returns (uint256) {
        uint256 total;
        total = IERC20(token).balanceOf(address(this)) - self.operatorTokens[token];

        return total * self.beneficiaryInfo[lender].allocation / 100000;
    }

    function hasBeneficiaryDebtOutstanding(SpigotState storage self) external view returns (bool) {
        bool hasDebtOwed = true;
        for (uint256 i = 0; i < self.beneficiaries.length; i++) {
            if (self.beneficiaryInfo[self.beneficiaries[i]].debtOwed == 0){
                hasDebtOwed = false;
            }
        }
        return hasDebtOwed;
    }

    // Spigot Events
    event AddSpigot(address indexed revenueContract, uint256 ownerSplit, bytes4 claimFnSig, bytes4 trsfrFnSig);

    event RemoveSpigot(address indexed revenueContract);

    event UpdateWhitelistFunction(bytes4 indexed func, bool indexed allowed);

    event UpdateOwnerSplit(address indexed revenueContract, uint8 indexed split);

    event ClaimRevenue(address indexed token, uint256 indexed amount, uint256 ownerTokens, address revenueContract);

    event ClaimLenderTokens(address indexed token, uint256 indexed amount, address lender);

    event ClaimOperatorTokens(address indexed token, uint256 indexed amount, address operator);

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

    error PushPayment();
}
