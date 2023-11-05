// SPDX-License-Identifier: GPL-3.0
// Copyright: https://github.com/credit-cooperative/Line-Of-Credit/blob/master/COPYRIGHT.md

 pragma solidity ^0.8.16;

import {IModuleFactory} from "../../interfaces/IModuleFactory.sol";

import {Spigot} from "../spigot/Spigot.sol";
import {Escrow} from "../escrow/Escrow.sol";

/**
 * @title   - Credit Cooperative Module Factory
 * @notice  - Facotry contract to deploy Spigot, and Escrow contracts.
 */
contract ModuleFactory is IModuleFactory {
    /**
     * see Spigot.constructor
     * @notice - Deploys a Spigot module that can be used in a LineOfCredit
     */
    function deploySpigot(
        address owner,
        address operator,
        address[] calldata _startingBeneficiaries,
        uint256[] calldata _startingAllocations,
        uint256[] calldata _debtOwed,
        address[] calldata _repaymentToken,
        address _adminMultisig
    ) external returns (address module) {
        module = address(new Spigot(owner, operator, _startingBeneficiaries, _startingAllocations, _debtOwed, _repaymentToken, _adminMultisig));
        emit DeployedSpigot(module, owner, _startingBeneficiaries[0]);
    }

    /**
     * see Escrow.constructor
     * @notice - Deploys an Escrow module that can be used in a LineOfCredit
     */
    function deployEscrow(
        uint32 minCRatio,
        address oracle,
        address owner,
        address borrower,
        address arbiter
    ) external returns (address module) {
        module = address(new Escrow(minCRatio, oracle, owner, borrower, arbiter));
        emit DeployedEscrow(module, minCRatio, oracle, owner, arbiter);
    }

    function registerEscrow(
        uint32 minCRatio,
        address oracle,
        address owner,
        address escrow
    ) external {

        emit RegisteredEscrow(escrow, minCRatio, oracle, owner);
    }

    function registerSpigot(
        address spigot,
        address owner,
        address borrower, //
        address operator
    ) external {

        emit RegisteredSpigot(spigot, owner, borrower, operator);
    }
}
