// SPDX-License-Identifier: GPL-3.0
// Copyright: https://github.com/credit-cooperative/Line-Of-Credit/blob/master/COPYRIGHT.md

 pragma solidity ^0.8.16;

 // TODO: Imports for development purpose only
 import "forge-std/console.sol";

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {LineLib} from "../../utils/LineLib.sol";
import {EscrowedLine} from "./EscrowedLine.sol";
import {SpigotedLine} from "./SpigotedLine.sol";
import {SpigotedLineLib} from "../../utils/SpigotedLineLib.sol";
import {LineOfCredit} from "./LineOfCredit.sol";
import {ILineOfCredit} from "../../interfaces/ILineOfCredit.sol";
import {ISecuredLine} from "../../interfaces/ISecuredLine.sol";

/**
 * @title  - Credit Cooperative Secured Line of Credit
 * @notice - The SecuredLine combines both collateral modules (SpigotedLine + EscrowedLine) with core lending functionality from LineOfCredit
 *         - to create a fully secured lending facility backed by revenue via Spigot or tokens via Escrow.
 * @dev    - modifies _liquidate(), _healthcheck(), _init(), and _declareInsolvent() functionality
 */
contract SecuredLine is SpigotedLine, EscrowedLine, ISecuredLine {
    constructor(
        address oracle_,
        address arbiter_,
        address borrower_,
        address payable swapTarget_,
        address spigot_,
        address escrow_,
        uint ttl_,
        uint8 defaultSplit_
    ) SpigotedLine(oracle_, arbiter_, borrower_, spigot_, swapTarget_, ttl_, defaultSplit_) EscrowedLine(escrow_) {}

    /**
     * @dev requires both Spigot and Escrow to pass _init to succeed
     */
    function _init() internal virtual override(SpigotedLine, EscrowedLine) {
        SpigotedLine._init();
        EscrowedLine._init();
    }

    /// see ISecuredLine.rollover
    function rollover(address newLine) external override onlyBorrower {
        // require all debt successfully paid already
        if (status != LineLib.STATUS.REPAID) {
            revert DebtOwed();
        }
        // require new line isn't activated yet
        if (ILineOfCredit(newLine).status() != LineLib.STATUS.UNINITIALIZED) {
            revert BadNewLine();
        }
        // we dont check borrower is same on both lines because borrower might want new address managing new line
        EscrowedLine._rollover(newLine);
        SpigotedLineLib.rollover(address(spigot), newLine);

        // ensure that line we are sending can accept them. There is no recovery option.
        try ILineOfCredit(newLine).init() {} catch {
            revert BadRollover();
        }
    }

    //  see IEscrowedLine.liquidate
    function liquidate(uint256 amount, address targetToken) external returns (uint256) {
        if (msg.sender != arbiter) {
            revert CallerAccessDenied();
        }
        if (_updateStatus(_healthcheck()) != LineLib.STATUS.LIQUIDATABLE) {
            revert NotLiquidatable();
        }

        // send tokens to arbiter for OTC sales
        return _liquidate(ids[0], amount, targetToken, msg.sender);
    }

    function _healthcheck() internal override(EscrowedLine, LineOfCredit) returns (LineLib.STATUS) {
        // check core (also cheap & internal) covenants before checking collateral conditions
        LineLib.STATUS s = LineOfCredit._healthcheck();
        if (s != LineLib.STATUS.ACTIVE) {
            // return early if non-default answer
            return s;
        }

        // check collateral ratio and return ACTIVE
        return EscrowedLine._healthcheck();
    }

    /**
     * @notice Wrapper for SpigotedLine and EscrowedLine internal functions
     * @dev - both underlying calls MUST return true for Line status to change to INSOLVENT
     * @return isInsolvent - if the entire Line including all collateral sources is fuly insolvent.
     */
    function _canDeclareInsolvent() internal virtual override(EscrowedLine, SpigotedLine) returns (bool) {
        return (EscrowedLine._canDeclareInsolvent() && SpigotedLine._canDeclareInsolvent());
    }

    /**
     * @notice - Allows borrower to extend the deadline of the line, update the borrower address, minimum c ratio percentages, and the owner splits for each revenue contract attached to the Spigot.
     * @dev - callable by `borrower`
     * @dev - requires line to not have open, active credit positions or outstanding debt to beneficiaries
     * @param newBorrower The new address of the borrower
     * @param ttlExtension The amount of time to extend the line by
     * @param minimumCollateralRatio The minimum collateral ratio required for the line
     * @param revenueContracts The list of revenue contracts to update with new owner splits
     * @param ownerSplits The corresponding list of new owner splits for each revenue contract
     * @return true is line is amended, extended, and set to ACTIVE status
     */
    function amendAndExtend(address newBorrower, uint256 ttlExtension, uint32 minimumCollateralRatio, address[] calldata revenueContracts, uint8[] calldata ownerSplits) external onlyBorrower returns (bool) {
        bool hasBeneficiaryDebtOutstanding = spigot.hasBeneficiaryDebtOutstanding();
        if (count == 0 && !hasBeneficiaryDebtOutstanding) {
            if (proposalCount > 0) {
                _clearProposals();
            }
            _amend(newBorrower, minimumCollateralRatio, revenueContracts, ownerSplits);
            _extend(ttlExtension);
            return true;
        }
        revert CannotAmendAndExtendLine();
    }

    /**
     * @notice - Allows borrower to update borrower address, the minimum c ratio percentage, and the owner splits for each revenue contract attached to the Spigot.
     * @dev - callable by `borrower`
     * @dev - requires line to not have open, active credit positions or outstanding debt to beneficiaries
     * @param newBorrower The new address of the borrower
     * @param minimumCollateralRatio The minimum collateral ratio required for the line
     * @param revenueContracts The list of revenue contracts to update with new owner splits
     * @param ownerSplits The corresponding list of new owner splits for each revenue contract
     * @return true is line is amended
     */
    function amend(address newBorrower, uint32 minimumCollateralRatio, address[] calldata revenueContracts, uint8[] calldata ownerSplits) external onlyBorrower returns (bool) {
        bool hasBeneficiaryDebtOutstanding = spigot.hasBeneficiaryDebtOutstanding();
        if (count == 0 && !hasBeneficiaryDebtOutstanding) {
            if (proposalCount > 0) {
                _clearProposals();
            }
            bool isAmended = _amend(newBorrower, minimumCollateralRatio, revenueContracts, ownerSplits);
            return isAmended;
        }
        revert CannotAmendLine();

    }

    // TODO: check if SecuredLine owns Spigot address (otherwise should fail)
    // TODO: check if SecuredLine owns Escrow (otherwise should fail)
    // TODO: what happens if line is repaid and Spigot is transferred to borrower/operator?
    // TODO: check that msg.sender is the Escrow State line address
    function _amend(address newBorrower, uint32 minimumCollateralRatio, address[] calldata revenueContracts, uint8[] calldata ownerSplits) internal returns (bool) {
        updateBorrower(newBorrower);
        escrow.updateMinimumCollateralRatio(minimumCollateralRatio);
        emit AmendEscrow(address(this), address(escrow), minimumCollateralRatio);
        updateRevenueContractSplits(revenueContracts, ownerSplits);
        emit AmendLine(address(this), borrower, deadline);

        return true;
    }

}



