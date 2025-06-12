// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import {Spigot} from "../../contracts/modules/spigot/Spigot.sol";

contract DeploySpigot is Script {
    function run() external {
        // Load constructor arguments from environment variables
        address arg1 = 0xf44B95991CaDD73ed769454A03b3820997f00873;
        

        // Load the private key from environment variables
        uint256 deployerPrivateKey = vm.envUint("BASE_PRIVATE_KEY");

        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the Spigot contract with the provided constructor arguments
        Spigot spigot = new Spigot(arg1, arg1);

        // Stop broadcasting transactions
        vm.stopBroadcast();
    }
}
