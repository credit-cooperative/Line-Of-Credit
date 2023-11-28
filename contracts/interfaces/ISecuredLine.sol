// SPDX-License-Identifier: GPL-3.0
// Copyright: https://github.com/credit-cooperative/Line-Of-Credit/blob/master/COPYRIGHT.md

 pragma solidity ^0.8.16;

import {IEscrowedLine} from "./IEscrowedLine.sol";
import {ISpigotedLine} from "./ISpigotedLine.sol";

interface ISecuredLine is IEscrowedLine, ISpigotedLine {
    // Rollover
    error DebtOwed();
    error BadNewLine();
    error BadRollover();
    error CannotAmendAndExtendLine();
    error CannotAmendLine();

    // Events
    event RecoveredEscrow(address indexed to, uint256 amount, address token);
    event RecoveredSpigot(address indexed to, address indexed spigot);

    // Borrower functions

    /**
     * @notice - helper function to allow Borrower to easily transfer settings and collateral from this line to a new line
     *         - usefull after ttl has expired and want to renew Line with minimal effort
     * @dev    - transfers Spigot and Escrow ownership to newLine. Arbiter functions on this Line will no longer work
     * @param newLine - the new, uninitialized Line deployed by borrower
     */
    function rollover(address newLine) external;

    // abort
    function recoverEscrowTokensAndSpigotedContracts(address[] memory tokens) external returns(bool);
}
