pragma solidity ^0.8.19;

import {Script, console2 as console} from "forge-std/Script.sol";
import {SimpleRevenueContract} from "../mock/SimpleRevenueContract.sol";

contract PlumeSimpleRevenueContractDeployment is Script {

    SimpleRevenueContract revenueContract;

    function run() public {
        uint256 privKey = vm.envUint("PLUME_PRIVATE_KEY");
        address deployer = vm.rememberKey(privKey);

        console.log("deployer address: %s", deployer);

        vm.startBroadcast(deployer);

        revenueContract = new SimpleRevenueContract(0x06dae7Ba3958EF288adB0B9b3732eC204E48BC47, 0x1aa70741167155E08bD319bE096C94eE54C6CA19);

        vm.stopBroadcast();

        console.log("Revenue Contract: %s", address(revenueContract));

    }
}