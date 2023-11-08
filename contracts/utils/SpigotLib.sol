// SPDX-License-Identifier: GPL-3.0
// Copyright: https://github.com/credit-cooperative/Line-Of-Credit/blob/master/COPYRIGHT.md

 pragma solidity ^0.8.16;
// TODO: Imports for development purpose only
import "forge-std/console.sol";

import {ReentrancyGuard} from "openzeppelin/utils/ReentrancyGuard.sol";
import {LineLib} from "../utils/LineLib.sol";
import {ISpigot} from "../interfaces/ISpigot.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {Denominations} from "chainlink/Denominations.sol";

struct SpigotState {
    address[] beneficiaries; // Claims on the repayment
    mapping(address => ISpigot.Beneficiary) beneficiaryInfo; // beneficiary -> info
    address operator;
    address owner;
    address arbiter;
    address swapTarget;
    mapping(address => uint256) operatorTokens;
    mapping(address => uint256) allocationTokens;
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
            claimed = existingBalance - self.operatorTokens[token] - self.allocationTokens[token] - getEscrowedTokens(self,token);

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
        uint256 allocationTokens = (claimed * self.settings[revenueContract].ownerSplit) / 100;
        // update escrowed balance
        self.allocationTokens[token] = self.allocationTokens[token] + allocationTokens;

        if (claimed > allocationTokens) {
            self.operatorTokens[token] = self.operatorTokens[token] + (claimed - allocationTokens);
        }


        emit ClaimRevenue(token, claimed, allocationTokens, revenueContract);

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

        if (boughtTokens <= self.beneficiaryInfo[lender].debtOwed){
            self.beneficiaryInfo[lender].debtOwed -= boughtTokens;
            IERC20(self.beneficiaryInfo[lender].repaymentToken).safeTransfer(lender, boughtTokens);
        } else if (boughtTokens > self.beneficiaryInfo[lender].debtOwed){
            IERC20(self.beneficiaryInfo[lender].repaymentToken).safeTransfer(lender, self.beneficiaryInfo[lender].debtOwed);
            self.operatorTokens[self.beneficiaryInfo[lender].repaymentToken] = self.operatorTokens[self.beneficiaryInfo[lender].repaymentToken] + (boughtTokens - self.beneficiaryInfo[lender].debtOwed);
            self.beneficiaryInfo[lender].debtOwed = 0;
        }

        return true;
    }

    function _distributeFunds(SpigotState storage self, address revToken) internal returns (uint256[] memory distributions) {

        // get balance of revenue token to distribute
        uint256 _tokensToDistribute = self.allocationTokens[revToken];

        // return array of amounts to distribute to each beneficiary
        uint256[] memory distributions = new uint256[](self.beneficiaries.length);

        if (_tokensToDistribute == 0) {
            revert NoTokensToDistribute();
        }

        // get current beneficiary settings for all beneficiaries
        // TODO: this should be a helper function
        uint256[] memory allocations = new uint256[](self.beneficiaries.length);
        address[] memory repaymentTokens = new address[](self.beneficiaries.length);
        uint256[] memory outstandingDebts = new uint256[](self.beneficiaries.length);
        for (uint256 i = 0; i < self.beneficiaries.length; i++) {
            allocations[i] = self.beneficiaryInfo[self.beneficiaries[i]].allocation;
            outstandingDebts[i] = self.beneficiaryInfo[self.beneficiaries[i]].debtOwed;
            repaymentTokens[i] = self.beneficiaryInfo[self.beneficiaries[i]].repaymentToken;
        }

        uint256 numBeneficiaries = self.beneficiaries.length;
        uint256 numRepaidBeneficiaries = 1;

        console.log('xxx - FIRST tokensToDistribute: ', _tokensToDistribute);
        // while there are tokens to distribute and there are still beneficiaries with debt
        uint256 excessTokens = 0;
        // uint256 count = 0;
        while (_tokensToDistribute > 0) { // && count < 5  && numRepaidBeneficiaries < numBeneficiaries
            console.log('\nxxx - tokensToDistribute: ', _tokensToDistribute);
            uint256 allocatedTokens = 0;
            uint256 allocationToSpread = 0;
            for (uint256 i = 0; i < distributions.length; i++) {
                uint256 beneficiaryDistribution = (allocations[i] * _tokensToDistribute) / (100000);
                console.log('\nxxx - i', i);
                console.log('xxx - beneficiary distribution: ', beneficiaryDistribution);
                // if first beneficiary, send all tokens
                if (i == 0) {
                    distributions[i] += beneficiaryDistribution;
                }

                // check if revtoken is the same as beneficiary repayment token
                else if (revToken == repaymentTokens[i]) {
                    // if distribution amount exceeds debt, set debt and allocations to zero
                    console.log('xxx - outstanding debts: ', outstandingDebts[i]);
                    if (beneficiaryDistribution > outstandingDebts[i]){
                        excessTokens += (beneficiaryDistribution - outstandingDebts[i]);
                        console.log('xxx - excess tokens: ', excessTokens);
                        beneficiaryDistribution = outstandingDebts[i];
                        outstandingDebts[i] = 0; // set beneficiary debt to zero
                        allocationToSpread += allocations[i];
                        allocations[i] = 0; // set beneficiary allocation to zero
                        distributions[i] += beneficiaryDistribution;
                        numRepaidBeneficiaries += 1;
                    }
                    else {
                        distributions[i] += beneficiaryDistribution;
                        outstandingDebts[i] -= beneficiaryDistribution;
                    }
                }

                // if revToken different than beneficiary repayment token
                else if (revToken != repaymentTokens[i]) {
                    distributions[i] += beneficiaryDistribution;
                }

                allocatedTokens += beneficiaryDistribution; //
                console.log('xxx - allocatedTokens: ', allocatedTokens);
                console.log('xxx - distributions: ', distributions[i]);
            }
            // count += 1;
            _tokensToDistribute -= excessTokens; // add excess tokens back
            _tokensToDistribute -= allocatedTokens; // subtract allocated tokens

            // reset allocations
            allocations = _resetAllocations(allocations, outstandingDebts, allocationToSpread);

            // add excessTokens to _tokensToDistribute if there are no more tokens to distribute
            if (excessTokens > 0 && _tokensToDistribute == 0) {
                _tokensToDistribute += excessTokens;
                excessTokens = 0;
            }
        }

    // Set allocations and debtOwed in state
    for (uint256 i = 0; i < self.beneficiaries.length; i++) {
        self.beneficiaryInfo[self.beneficiaries[i]].allocation = allocations[i];
        self.beneficiaryInfo[self.beneficiaries[i]].debtOwed = outstandingDebts[i];
    }

    // distribute excess tokens to the first beneficiary (the owner of the Spigot)
    distributions[0] += excessTokens;

    self.allocationTokens[revToken] = 0; // set allocation tokens to zero

    // TODO: transfer funds in distributions array to respective beneficiary addresses?
    return distributions;

        // OLD CODE
        // // get current allocations
        // uint256[] memory allocations = new uint256[](self.beneficiaries.length);
        // for (uint256 i = 0; i < self.beneficiaries.length; i++) {
        //     allocations[i] = self.beneficiaryInfo[self.beneficiaries[i]].allocation;
        // }

        // // feeBalances[0] is fee sent to smartTreasury
        // feeBalances = _amountsFromAllocations(allocations, self.allocationTokens[revToken]);

        // for (uint256 i = 0; i < self.beneficiaries.length; i++) {
        //     uint256 debt = self.beneficiaryInfo[self.beneficiaries[i]].debtOwed;

        //     if (i == 1){
        //         IERC20(revToken).safeTransfer(self.beneficiaries[i], feeBalances[i]);
        //     }

        //     // check if revtoken is the same as beneficiary desired token
        //     if (self.beneficiaryInfo[self.beneficiaries[i]].repaymentToken == revToken) {
        //         // TODO: I think this can be a helper
        //         if (feeBalances[i] <= debt){
        //             IERC20(revToken).safeTransfer(self.beneficiaries[i], feeBalances[i]);
        //             self.beneficiaryInfo[self.beneficiaries[i]].debtOwed -= feeBalances[i];
        //         } else if (feeBalances[i] > debt){
        //             IERC20(revToken).safeTransfer(self.beneficiaries[i], debt);
        //             self.operatorTokens[revToken] += (feeBalances[i] - debt);
        //             self.beneficiaryInfo[self.beneficiaries[i]].debtOwed = 0;
        //         }

        //     } else if (self.beneficiaryInfo[self.beneficiaries[i]].repaymentToken != revToken){
        //         self.beneficiaryInfo[self.beneficiaries[i]].bennyTokens[revToken] = self.beneficiaryInfo[self.beneficiaries[i]].bennyTokens[revToken] + feeBalances[i];
        //     }


        // }
    }

    function _resetAllocations(uint256[] memory allocations, uint256[] memory outstandingDebts, uint256 allocationToSpread) internal view returns (uint256[] memory newAllocations) {

        // allocations must sum to 100000
        // uint256 total = 0;
        // for (uint256 i = 0; i < allocations.length; i++) {
        //     total += allocations[i];
        //     console.log('xxx - original allocation: ', allocations[i]);
        // }
        // require(total == 100000, "Sum must be 100000");
        uint256 total = 100000;

        // Cannot reset allocations if only owner or there is nothing to spread
        if (allocations.length <= 1 || allocationToSpread == 0) {
            return allocations;
        }

        console.log('xxx - allocationToSpread', allocationToSpread);

        // Save the value to be redistributed and set the index's value to 0
        total -= allocationToSpread; // Update total to the sum of the remaining elements

        // Distribute the value proportionally
        if (total > 0) {
            for (uint256 i = 0; i < allocations.length; i++) {
                if (i == 0 || outstandingDebts[i] != 0) {
                    // Calculate the proportional amount for each element
                    uint256 proportionalAmount = (allocations[i] * allocationToSpread) / total;
                    // Add the proportional amount to the current element
                    allocations[i] += proportionalAmount;
                }
            }
        }
        // Handle any rounding errors by adding the difference to the first element
        uint256 newTotal = 0;
        for (uint256 i = 0; i < allocations.length; i++) {
            console.log('xxx - new allocation: ', allocations[i]);
            newTotal += allocations[i];
        }
        if (newTotal < 100000) {
            allocations[0] += (100000 - newTotal);
        }

        return allocations;
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
        uint256 total = 0;

        // lender token allocation
        total += self.allocationTokens[token] * self.beneficiaryInfo[lender].allocation / 100000;
        total += self.beneficiaryInfo[lender].bennyTokens[token];
        return total;
    }

    function hasBeneficiaryDebtOutstanding(SpigotState storage self) external view returns (bool) {
        bool hasDebtOwed = false;
        for (uint256 i = 0; i < self.beneficiaries.length; i++) {
            if (self.beneficiaryInfo[self.beneficiaries[i]].debtOwed > 0){
                hasDebtOwed = true;
            }
        }
        return hasDebtOwed;
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

    // TODO: add documentation
    function deleteBeneficiaries(SpigotState storage self) external {
        if (msg.sender != self.owner && msg.sender != self.arbiter) {
            revert CallerAccessDenied();
        }
        delete self.beneficiaries;
    }


    // TODO: add docuementation
    function addBeneficiaryAddress(SpigotState storage self, address _newBeneficiary) external {
        require(self.beneficiaries.length < 5, "Max beneficiaries");
        require(_newBeneficiary != address(0), "beneficiary cannot be zero address");
        if (msg.sender != self.owner && msg.sender != self.arbiter) {
            revert CallerAccessDenied();
        }

        for (uint256 i = 0; i < self.beneficiaries.length; i++) {
            require(self.beneficiaries[i] != _newBeneficiary, "Duplicate beneficiary");
        }

        self.beneficiaries.push(_newBeneficiary);
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

    function updateBeneficiaryInfo(SpigotState storage self, address beneficiary, address newOperator, uint256 allocation, address repaymentToken, uint256 outstandingDebt) external {
        require(beneficiary != address(0), "Invalid beneficiary");
        require(newOperator != address(0), "Invalid operator");
        if (msg.sender != self.owner && msg.sender != self.arbiter) {
            revert CallerAccessDenied();
        }
        // require(allocation > 0, "Invalid allocation");
        // require(repaymentToken != address(0), "Invalid repayment token");

        self.beneficiaryInfo[beneficiary].bennyOperator = newOperator;
        self.beneficiaryInfo[beneficiary].allocation = allocation;
        self.beneficiaryInfo[beneficiary].repaymentToken = repaymentToken;
        self.beneficiaryInfo[beneficiary].debtOwed = outstandingDebt;

        // TODO: cannnot delete mapping entirely. need to iterate over to delete if necessary
        // delete self.beneficiaryInfo[beneficiary].bennyTokens;

    }

    // TODO: add documentation
    // Notes:
    // - onlyArbiter can call this function
    // - arbiter can unilaterally remove an external credit position (i.e. beneficiary)
    // - arbiter sets beneficiary's debt to 0, removes beneficiary from array, and
    //   transfers allocation back to the owner of the Spigot (i.e. Line of Credit)
    // - does not maintain order of the beneficiaries array as the order has no significance
    function removeBeneficiary(SpigotState storage self, address beneficiary) external {
        require(beneficiary != address(0), "Invalid beneficiary");
        require(beneficiary != self.beneficiaries[0], "Cannot remove owner from beneficiaries");
        if (msg.sender != self.arbiter) {
            revert CallerAccessDenied();
        }

        // set the debt owed to 0
        self.beneficiaryInfo[beneficiary].debtOwed = 0;

        // get the beneficiary allocation
        uint256 beneficiaryAllocation = self.beneficiaryInfo[beneficiary].allocation;

        // remove from Beneficiary struct
        delete self.beneficiaryInfo[beneficiary];

        // add the beneficiaries allocation to the owner's allocation (the first beneficiary)

        self.beneficiaryInfo[self.beneficiaries[0]].allocation += beneficiaryAllocation;
        // remove the beneficiary from the beneficiaries array
        uint length = self.beneficiaries.length;
        for (uint i = 0; i < length; i++) {
            if (self.beneficiaries[i] == beneficiary) {
                self.beneficiaries[i] = self.beneficiaries[length - 1];
                self.beneficiaries.pop();
                break;
            }
        }

    }

    // Getters

    // TODO: add documentation
    function getBeneficiaryBasicInfo(SpigotState storage self, address beneficiary) external view returns (address, uint256, address, uint256) {
        ISpigot.Beneficiary storage b = self.beneficiaryInfo[beneficiary];
        return (b.bennyOperator, b.allocation, b.repaymentToken, b.debtOwed);
    }

    // // TODO: add documentation
    // function getBennyTokenAmount(SpigotState storage self, address beneficiary, address token) external view returns (uint256) {
    //     uint256 amount = self.beneficiaryInfo[beneficiary].bennyTokens[token];
    //     return amount;
    // }

////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////



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

    error NoTokensToDistribute();

    error SpigotSettingsExist();

    error PushPayment();
}
