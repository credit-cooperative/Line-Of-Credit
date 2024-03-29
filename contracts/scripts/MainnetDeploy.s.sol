pragma solidity ^0.8.19;

import {Script, console2 as console} from "forge-std/Script.sol";
import {LineFactory} from "../modules/factories/LineFactory.sol";
import {ModuleFactory} from "../modules/factories/ModuleFactory.sol";

contract MainnetDeploy is Script {

    ModuleFactory moduleFactory;
    LineFactory lineFactory;

    address constant arbiter = address(0xeb0566b1EF38B95da2ed631eBB8114f3ac7b9a8a);
    address payable constant swapTarget = payable(0xDef1C0ded9bec7F1a1670819833240f027b25EfF); // ZeroEx
    address constant oracle = 0x5a4AAF300473eaF8A9763318e7F30FA8a3f5Dd48;

    function run() public {
        uint256 privKey = vm.envUint("MAINNET_PRIVATE_KEY");
        address deployer = vm.rememberKey(privKey);

        console.log("deployer address: %s", deployer);

        vm.startBroadcast(deployer);

        moduleFactory = new ModuleFactory();

        lineFactory = new LineFactory(
            address(moduleFactory),
            arbiter,
            address(oracle),
            swapTarget
        );

        vm.stopBroadcast();

        console.log("Module Factory: %s", address(moduleFactory));
        console.log("Oracle: %s", address(oracle));
        console.log("Line Factory: %s", address(lineFactory));

        require(lineFactory.arbiter() == arbiter, "arbiter not set");
        require(lineFactory.swapTarget() == swapTarget, "swapTarget not set");
        require(lineFactory.oracle() == oracle, "oracle not set");
    }
}