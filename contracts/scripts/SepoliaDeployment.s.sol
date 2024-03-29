pragma solidity ^0.8.19;

import {Script, console2 as console} from "forge-std/Script.sol";
import {LineFactory} from "../modules/factories/LineFactory.sol";
import {ModuleFactory} from "../modules/factories/ModuleFactory.sol";
import {GenericOracle} from "../modules/oracle/GenericOracle.sol";

import {Ownable} from "openzeppelin/access/Ownable.sol";

contract SepoliaDeployment is Script {

    ModuleFactory moduleFactory;
    GenericOracle oracle;
    LineFactory lineFactory;

    //TODO: Replace before Deploymentss
    address arbiter = address(0x895A8900437ba52A7C1450b09CD05C2Ba8A0EBE5);
    address payable swapTarget = payable(0xDef1C0ded9bec7F1a1670819833240f027b25EfF); // ZeroEx

    function run() public {
        uint256 privKey = vm.envUint("SEPOLIA_PRIVATE_KEY");
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

        //Transfer ownership of the oracle to the arbiter
        oracle.setOwner(arbiter);

        vm.stopBroadcast();
        require(oracle.owner() == arbiter, "oracle ownership not transferred correctly");

        console.log("Module Factory: %s", address(moduleFactory));
        console.log("Oracle: %s", address(oracle));
        console.log("Line Factory: %s", address(lineFactory));

    }
}