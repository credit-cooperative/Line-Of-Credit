// SPDX-License-Identifier: GPL-3.0
// Copyright: https://github.com/credit-cooperative/Line-Of-Credit/blob/master/COPYRIGHT.md

 pragma solidity ^0.8.16;

import {Script} from "../lib/forge-std/src/Script.sol";
import {RevenueToken} from "../contracts/mock/RevenueToken.sol";

contract SmallDeploy is Script {
    RevenueToken token;

    function run() external {
        vm.startBroadcast();

        token = new RevenueToken();

        vm.stopBroadcast();
    }
}
