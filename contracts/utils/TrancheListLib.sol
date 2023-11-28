// SPDX-License-Identifier: GPL-3.0
// Copyright: https://github.com/credit-cooperative/Line-Of-Credit/blob/master/COPYRIGHT.md

 pragma solidity ^0.8.16;
import {ILineOfCredit} from "../interfaces/ILineOfCredit.sol";
import {IOracle} from "../interfaces/IOracle.sol";
import {CreditLib} from "./CreditLib.sol";

 // TODO: Imports for development purpose only
 import "forge-std/console.sol";

/**
 * @title Credit Cooperative Line of Credit Library
 * @notice Core logic and variables to be reused across all Credit Cooperative Marketplace Line of Credit contracts
 */
library TrancheListLib {
    // TODO; add documentation
    function removeTranche(ILineOfCredit.Tranche[] storage tranches, uint256 trancheIndex) external returns (bool, uint256) {
        require(trancheIndex < tranches.length, "Index out of bounds");

        // Shift elements to the left starting from the index to be removed
        for (uint i = trancheIndex; i < tranches.length - 1; i++) {
            tranches[i] = tranches[i + 1];
        }

        // Remove the last element (duplicated at the end)
        tranches.pop();

        return (true, trancheIndex);
    }
}