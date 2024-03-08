pragma solidity ^0.8.19;

import {Script, console2 as console} from "forge-std/Script.sol";
import {LineFactory} from "../modules/factories/LineFactory.sol";
import {ModuleFactory} from "../modules/factories/ModuleFactory.sol";
import {GenericOracle} from "../modules/oracle/GenericOracle.sol";

contract PlumeDeployment is Script {

    ModuleFactory moduleFactory;
    GenericOracle oracle;
    LineFactory lineFactory;

    //TODO: Replace before Deploymentss
    address arbiter = address(0x42069);
    address payable swapTarget = payable(0xfD2c49851DB3D1A189Fc887671A5752d2336D128);//Uni Swap Router on Plume

    function run() public {
        uint privKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.rememberKey(privKey);

        console.log("deployer address: %s", deployer);

        vm.startBroadcast(deployer);

        moduleFactory = new ModuleFactory();
        oracle = new GenericOracle();

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
    }
}