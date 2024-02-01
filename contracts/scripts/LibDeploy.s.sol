// SPDX-License-Identifier: GPL-3.0
// Copyright: https://github.com/credit-cooperative/Line-Of-Credit/blob/master/COPYRIGHT.md

 pragma solidity ^0.8.16;

 // import all libs from utils folder

import {Script} from "../../lib/forge-std/src/Script.sol";
import {CreditLib} from "../utils/CreditLib.sol";
import {CreditListLib} from "../utils/CreditListLib.sol";
import {EscrowLib} from "../utils/EscrowLib.sol";
import {LineFactoryLib} from "../utils/LineFactoryLib.sol";
import {LineLib} from "../utils/LineLib.sol";
import {SpigotedLineLib} from "../utils/SpigotedLineLib.sol";
import {SpigotLib} from "../utils/SpigotLib.sol";
import {LineFactory} from "../modules/factories/LineFactory.sol";
import {ModuleFactory} from "../modules/factories/ModuleFactory.sol";

contract LibDeploy is Script {

    function run() external {
        uint256 deployerPrivateKey= vm.envUint("LOCAL_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address arbiter = address(12);
        address oracle = address(10);
        address swap = address(11);

        ModuleFactory modulefactory = new ModuleFactory();
        LineFactory linefactory = new LineFactory(address(modulefactory), arbiter, oracle, payable(swap));

        vm.stopBroadcast();
    }




}