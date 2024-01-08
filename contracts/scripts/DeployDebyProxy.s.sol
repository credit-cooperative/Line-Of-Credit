// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../modules/get-3PL-debt/HumaRainPoolImplementation.sol";
import "openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";

contract DeployScript is Script {
    function run() external {
        vm.startBroadcast();

        // Deploying the implementation contract
        HumaRainPoolImplementation humaRainPoolImplementation = new HumaRainPoolImplementation();
        console.log("HumaRainPoolImplementation deployed to:", address(humaRainPoolImplementation));

        // Data for initializing the contract, if needed
        bytes memory initData = abi.encodeWithSignature("initialize()");

        // Deploying the TransparentUpgradeableProxy
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(humaRainPoolImplementation),
            address(this), // The admin address
            initData
        );
        console.log("Proxy deployed to:", address(proxy));

        vm.stopBroadcast();
    }
}
