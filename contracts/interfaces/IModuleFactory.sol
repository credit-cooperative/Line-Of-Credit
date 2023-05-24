// SPDX-License-Identifier: GPL-3.0
// Copyright: https://github.com/test-org2222/Line-Of-Credit/blog/master/COPYRIGHT.md

pragma solidity 0.8.16;

interface IModuleFactory {
    event DeployedSpigot(address indexed deployedAt, address indexed owner, address operator);

    event DeployedEscrow(address indexed deployedAt, uint32 indexed minCRatio, address indexed oracle, address owner);

    function deploySpigot(address owner, address operator) external returns (address);

    function deployEscrow(uint32 minCRatio, address oracle, address owner, address borrower) external returns (address);
}
