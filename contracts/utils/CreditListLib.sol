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
library CreditListLib {
    event QueueCleared();
    event SortedIntoQ(bytes32 indexed id, uint256 indexed newIdx, uint256 indexed oldIdx, bytes32 oldId);
    error CantStepQ();

    /**
     * @notice  - Removes a position id from the active list of open positions.
     * @dev     - assumes `id` is stored only once in the `positions` array. if `id` occurs twice, debt would be double counted.
     * @param ids           - all current credit lines on the Line of Credit facility
     * @param id            - the hash id of the credit line to be removed from active ids after removePosition() has run
     * @return newPositions - all active credit lines on the Line of Credit facility after the `id` has been removed
     */
    function removePosition(bytes32[][] storage ids, bytes32 id) external returns (bool, uint256) {
        uint256 numTranches = ids.length;
        for (uint256 i; i < numTranches; ++i) {
            uint256 len = ids[i].length;
            for (uint256 j; j < len; ++j) {
                if (ids[i][j] == id) {
                    delete ids[i][j];
                    return (true, i);
                }
            }
        }

        return (false, 0);
    }

    /**
     * @notice  - swap the first element in the queue, provided it is null, with the next available valid(non-null) id
     * @dev     - Must perform check for ids[0] being valid (non-zero) before calling
     * @param ids       - all current credit lines on the Line of Credit facility
     * @return swapped  - returns true if the swap has occurred
     */
    function stepQ(bytes32[][] storage ids, uint256 tranche) external returns (bool) {
        if (ids[tranche][0] != bytes32(0)) {
            revert CantStepQ();
        }
        uint256 len = ids[tranche].length;
        // console.log('\n');
        // console.log('ZZZ - tranche len: ', len);
        if (len <= 1) return false;

        // skip the loop if we don't need
        if (len == 2 && ids[tranche][1] != bytes32(0)) {
            (ids[tranche][0], ids[tranche][1]) = (ids[tranche][1], ids[tranche][0]);
            emit SortedIntoQ(ids[tranche][0], 0, 1, ids[tranche][1]);
            return true;
        }

        // we never check the first id, because we already know it's null
        for (uint i = 1; i < len; ) {
            if (ids[tranche][i] != bytes32(0)) {
                (ids[tranche][0], ids[tranche][i]) = (ids[tranche][i], ids[tranche][0]); // swap the ids in storage
                emit SortedIntoQ(ids[tranche][0], 0, i, ids[tranche][i]);
                return true; // if we make the swap, return early
            }
            unchecked {
                ++i;
            }
        }
        emit QueueCleared();
        return false;
    }

    /**
     * @notice  - swap the first element in the queue, provided it is null, with the next available valid(non-null) id
     * @dev     - Must perform check for ids[0] being valid (non-zero) before calling
     * @param ids       - all current credit lines on the Line of Credit facility
     * @return swapped  - returns true if the swap has occurred
     */
    // TODO - add events to this function
    // NOTE - tranches are always closed in order of seniority? (not true with multi token)
    function stepTranche(bytes32[][] storage ids, uint256 tranche) external returns (bool) {

        uint256 len = ids.length;

        console.log('\n');
        console.log('777', len);
        console.log('777', tranche);
        console.log('\n');

        // if there is only one tranche, replace ids with an empty 2d array
        // if (len <= 1) {
        //     // bytes32[][] storage emptyIds;
        //     ids = new bytes32[][](0);
        //     return true;
        // }

        // if tranche index is last tranche, then pop the array
        if (tranche == len - 1 || len <= 1) {
            // if last tranche is empty, remove it
            console.log('ZZZ - do I make it here 1?');
            ids.pop();
            console.log('ZZZ - do I make it here 2?', ids.length);
            return true;
        }

        // skip the loop if we don't need
        if (len == 2) {
            bytes32[] memory firstTranche = ids[0];
            bytes32[] memory secondTranche = ids[1];
            (ids[0], ids[1]) = (secondTranche, firstTranche);
            ids.pop();
            // TODO: add back event
            // emit SortedIntoQ(ids[0], 0, 1, ids[1]);
            return true;
        }

        // // we never check the first id, because we already know it's null
        // for (uint i = 1; i < len; ) {
        //     if (ids[tranche][i] != bytes32(0)) {
        //         (ids[tranche][0], ids[tranche][i]) = (ids[tranche][i], ids[tranche][0]); // swap the ids in storage
        //         emit SortedIntoQ(ids[tranche][0], 0, i, ids[tranche][i]);
        //         return true; // if we make the swap, return early
        //     }
        //     unchecked {
        //         ++i;
        //     }
        // }
        // emit QueueCleared();
        return false;
    }

}
