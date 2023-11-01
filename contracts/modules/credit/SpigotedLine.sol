// SPDX-License-Identifier: GPL-3.0
// Copyright: https://github.com/credit-cooperative/Line-Of-Credit/blob/master/COPYRIGHT.md

 pragma solidity ^0.8.16;

import {Denominations} from "chainlink/Denominations.sol";
import {LineOfCredit} from "./LineOfCredit.sol";
import {LineLib} from "../../utils/LineLib.sol";
import {CreditLib} from "../../utils/CreditLib.sol";
import {SpigotedLineLib} from "../../utils/SpigotedLineLib.sol";
import {MutualConsent} from "../../utils/MutualConsent.sol";
import {ISpigot} from "../../interfaces/ISpigot.sol";
import {ISpigotedLine} from "../../interfaces/ISpigotedLine.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";

/**
  * @title  - Credit Cooperative Spigoted Line of Credit
  * @notice - Line of Credit contract with additional functionality for integrating with a Spigot and revenue based collateral.
            - Allows Arbiter to repay debt using collateralized revenue streams onbehalf of Borrower and Lender(s)
  * @dev    - Inherits LineOfCredit functionality
 */
contract SpigotedLine is ISpigotedLine, LineOfCredit {
    using SafeERC20 for IERC20;

    /// @notice see Spigot
    ISpigot public immutable spigot;

    /// @notice - maximum revenue we want to be able to take from spigots if Line is in default
    uint8 constant MAX_SPLIT = 100;

    /// @notice % of revenue tokens to take from Spigot if the Line of Credit is healthy. 0 decimals
    uint8 public defaultRevenueSplit;

    /// @notice exchange aggregator (mainly 0x router) to trade revenue tokens from a Spigot for credit tokens owed to lenders
    address payable public immutable swapTarget;

    /**
     * @notice - excess unsold revenue claimed from Spigot to be sold later or excess credit tokens bought from revenue but not yet used to repay debt
     *         - needed because the Line of Credit might have the same token being lent/borrower as being bought/sold so need to separate accounting.
     * @dev    - private variable so other Line modules do not interfer with Spigot functionality
     */
    mapping(address => uint256) private unusedTokens;

    /**
     * @notice - The SpigotedLine is a LineofCredit contract with additional functionality for integrating with a Spigot.
               - allows Borrower or Lender to repay debt using collateralized revenue streams
     * @param oracle_ - price oracle to use for getting all token values
     * @param arbiter_ - neutral party with some special priviliges on behalf of borrower and lender
     * @param borrower_ - the debitor for all credit positions in this contract
     * @param spigot_ - Spigot smart contract that is owned by this Line
     * @param swapTarget_ - 0x protocol exchange address to send calldata for trades to exchange revenue tokens for credit tokens
     * @param ttl_ - time to live for line of credit contract across all lenders set at deployment in order to set the term/expiry date
     * @param defaultRevenueSplit_ - The % of Revenue Tokens that the Spigot escrows for debt repayment if the Line is healthy.
     */
    constructor(
        address oracle_,
        address arbiter_,
        address borrower_,
        address spigot_,
        address payable swapTarget_,
        uint256 ttl_,
        uint8 defaultRevenueSplit_
    ) LineOfCredit(oracle_, arbiter_, borrower_, ttl_) {
        require(defaultRevenueSplit_ <= MAX_SPLIT);

        spigot = ISpigot(spigot_);
        defaultRevenueSplit = defaultRevenueSplit_;
        swapTarget = swapTarget_;
    }

    /**
     * see LineOfCredit._init and Securedline.init
     * @notice requires this Line is owner of the Escrowed collateral else Line will not init
     */
    function _init() internal virtual override(LineOfCredit) {
        if (spigot.owner() != address(this)) revert BadModule(address(spigot));
    }

    /**
     * see SecuredLine.declareInsolvent
     * @notice requires Spigot contract itselgf to be transfered to Arbiter and sold off to a 3rd party before declaring insolvent
     *(@dev priviliegad internal function.
     * @return isInsolvent - if Spigot contract is currently insolvent or not
     */
    function _canDeclareInsolvent() internal virtual override returns (bool) {
        return SpigotedLineLib.canDeclareInsolvent(address(spigot), arbiter);
    }

    /// see ISpigotedLine.closePositionWithUnusedTokens
    function closePositionWithUnusedTokens(bytes32 id) external nonReentrant onlyBorrowerOrArbiter {
        Credit memory credit = _accrue(credits[id], id);

        uint256 facilityFee = credit.interestAccrued;
        uint256 unusedTokensForClosingPosition = unusedTokens[credit.token];
        unusedTokens[credit.token] -= unusedTokensForClosingPosition;

        if (unusedTokensForClosingPosition > facilityFee) {
            // clear facility fees and close position
            credits[id] = _close(_repay(credit, id, facilityFee, address(this)), id);
        }

    }


    /// see ISpigotedLine.claimAndRepay
    function claimAndRepay(
        address claimToken,
        bytes calldata zeroExTradeData
    ) external whileBorrowing nonReentrant returns (uint256) {
        bytes32 id = ids[0];
        Credit memory credit = _accrue(credits[id], id);

        if (msg.sender != arbiter) {
            revert CallerAccessDenied();
        }

        uint256 newTokens = _claimAndTrade(claimToken, credit.token, zeroExTradeData);

        uint256 repaid = newTokens + unusedTokens[credit.token];
        uint256 debt = credit.interestAccrued + credit.principal;

        // cap payment to debt value
        if (repaid > debt) repaid = debt;

        // update reserves based on usage
        if (repaid > newTokens) {
            // if using `unusedTokens` to repay line, reduce reserves
            uint256 diff = repaid - newTokens;
            emit ReservesChanged(credit.token, -int256(diff), 1);
            unusedTokens[credit.token] -= diff;
        } else {
            // else high revenue and bought more credit tokens than owed, fill reserves
            uint256 diff = newTokens - repaid;
            emit ReservesChanged(credit.token, int256(diff), 1);
            unusedTokens[credit.token] += diff;
        }

        credits[id] = _repay(credit, id, repaid, address(0)); // no payer, we already have funds

        emit RevenuePayment(claimToken, repaid);

        return newTokens;
    }

    /// see ISpigotedLine.useAndRepay
    function useAndRepay(uint256 amount) external whileBorrowing returns (bool) {
        bytes32 id = ids[0];
        Credit memory credit = credits[id];

        if (msg.sender != borrower && msg.sender != credit.lender) {
            revert CallerAccessDenied();
        }

        if (amount > credit.principal + credit.interestAccrued) {
            revert RepayAmountExceedsDebt(credit.principal + credit.interestAccrued);
        }

        if (amount > unusedTokens[credit.token]) {
            revert ReservesOverdrawn(credit.token, unusedTokens[credit.token]);
        }

        // reduce reserves before _repay calls token to prevent reentrancy
        unusedTokens[credit.token] -= amount;
        emit ReservesChanged(credit.token, -int256(amount), 0);

        credits[id] = _repay(_accrue(credit, id), id, amount, address(0)); // no payer, we already have funds

        emit RevenuePayment(credit.token, amount);

        return true;
    }

    /// see ISpigotedLine.claimAndTrade
    function claimAndTrade(
        address claimToken,
        bytes calldata zeroExTradeData
    ) external whileBorrowing nonReentrant returns (uint256) {
        if (msg.sender != arbiter) {
            revert CallerAccessDenied();
        }

        address targetToken = credits[ids[0]].token;
        uint256 newTokens = _claimAndTrade(claimToken, targetToken, zeroExTradeData);

        // add bought tokens to unused balance
        unusedTokens[targetToken] += newTokens;
        emit ReservesChanged(targetToken, int256(newTokens), 1);

        return newTokens;
    }

    /**
     * @notice  - Claims revenue tokens escrowed in Spigot and trades them for credit tokens.
     *          - MUST trade all available claim tokens to target credit token.
     *          - Excess credit tokens not used to repay dent are stored in `unused`
     * @dev     - priviliged internal function
     * @param claimToken - The revenue token escrowed in the Spigot to sell in trade
     * @param targetToken - The credit token that needs to be bought in order to pat down debt. Always `credits[ids[0]].token`
     * @param zeroExTradeData - 0x API data to use in trade to sell `claimToken` for target
     *
     * @return - amount of target tokens bought
     */
    function _claimAndTrade(
        address claimToken,
        address targetToken,
        bytes calldata zeroExTradeData
    ) internal returns (uint256) {
        if (claimToken == targetToken) {
            // same asset. dont trade
            return spigot.distributeFunds(claimToken)[1];
        } else {
            // trade revenue token for debt obligation
            (uint256 tokensBought, uint256 totalUnused) = SpigotedLineLib.claimAndTrade(
                claimToken,
                targetToken,
                swapTarget,
                address(spigot),
                unusedTokens[claimToken],
                zeroExTradeData
            );

            // we dont use revenue after this so can store now
            /// @dev ReservesChanged event for claim token is emitted in SpigotedLineLib.claimAndTrade
            unusedTokens[claimToken] = totalUnused;

            // the target tokens purchased
            return tokensBought;
        }
    }

    //  SPIGOT OWNER FUNCTIONS

    /// see ISpigotedLine.updateOwnerSplit
    function updateOwnerSplit(address revenueContract) external returns (bool) {
        return
            SpigotedLineLib.updateSplit(
                address(spigot),
                revenueContract,
                _updateStatus(_healthcheck()),
                defaultRevenueSplit
            );
    }

    /// see ISpigotedLine.addSpigot
    function addSpigot(address revenueContract, ISpigot.Setting calldata setting) external returns (bool) {
        if (msg.sender != arbiter) {
            revert CallerAccessDenied();
        }
        return spigot.addSpigot(revenueContract, setting);
    }

    /// see ISpigotedLine.updateWhitelist
    function updateWhitelist(bytes4 func, bool allowed) external returns (bool) {
        if (msg.sender != arbiter) {
            revert CallerAccessDenied();
        }
        return spigot.updateWhitelistedFunction(func, allowed);
    }

    /// see ISpigotedLine.releaseSpigot
    function releaseSpigot(address to) external returns (bool) {
        return SpigotedLineLib.releaseSpigot(address(spigot), _updateStatus(_healthcheck()), borrower, arbiter, to);
    }

    /// see ISpigotedLine.removeSpigot
    function removeSpigot(address revenueContract) external returns (bool) {
        return SpigotedLineLib.removeSpigot(address(spigot), _updateStatus(_healthcheck()), borrower, revenueContract);
    }


    // TODO: add documentation
    // TODO: add tests
    // NOTE: only works for existing revenue contracts for which to change splits
    function updateRevenueContractSplits(address[] calldata _revenueContracts, uint8[] calldata _ownerSplits) public onlyBorrower {
        // TODO: needs to check that outstanding debt to beneficiaries is 0
        if (count == 0) {
            if (proposalCount > 0) {
                _clearProposals();
            }
            for (uint256 i = 0; i < _revenueContracts.length; i++) {
                spigot.updateOwnerSplit(_revenueContracts[i], _ownerSplits[i]);
            }
        }

    }

    // TODO: implement this function
    // NOTE: add/reset new/existing beneficiary agreements
    // NOTES: allocations cannot sum to greater than 100000
    // TODO: emit AmendBeneficiaries(address(this), spigot, beneficiaries);
    // NOTE: only works with existing beneificiaries. Need to add/remove beneficiares before calling this function
    function updateBeneficiarySettings(address[] calldata _beneficiaries, address[] calldata _operators, uint256[] calldata _allocations, address[] calldata _repaymentTokens, uint256[] calldata _outstandingDebts) external onlyBorrower {
        // TODO: needs to check that outstanding debt to beneficiaries is 0
        if (count == 0) {
            if (proposalCount > 0) {
                _clearProposals();
            }

            if (_beneficiaries[0] != address(this)) {
                revert LineMustBeFirstBeneficiary(_beneficiaries[0]);
            }

            if (_outstandingDebts[0] > 0) {
                revert LineBeneficiaryDebtMustBeZero(_outstandingDebts[0]);
            }

            for (uint256 i = 0; i < _beneficiaries.length; i++) {

                spigot.updateBeneficiaryInfo(_beneficiaries[i], _operators[i], _allocations[i], _repaymentTokens[i], _outstandingDebts[i]);

            }
        }
    }

    // function updateBeneficiaryOperator(address beneficiary, address newOperator) external {

    // }

    /// see ISpigotedLine.sweep
    function sweep(address to, address token, uint256 amount) external nonReentrant returns (uint256) {
        uint256 swept = SpigotedLineLib.sweep(
            to,
            token,
            amount,
            unusedTokens[token],
            _updateStatus(_healthcheck()),
            borrower,
            arbiter
        );

        if (swept != 0) {
            unusedTokens[token] -= swept;
            emit ReservesChanged(token, -int256(swept), 1);
        }

        return swept;
    }

    /// see ILineOfCredit.tradeable
    function tradeable(address token) external view returns (uint256) {
        return unusedTokens[token] + spigot.getLenderTokens(token, spigot.owner());
    }

    /// see ILineOfCredit.unused
    function unused(address token) external view returns (uint256) {
        return unusedTokens[token];
    }

    // allow claiming/trading in ETH
    receive() external payable {}
}
