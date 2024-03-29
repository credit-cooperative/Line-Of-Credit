// SPDX-License-Identifier: GPL-3.0
// Copyright: https://github.com/credit-cooperative/Line-Of-Credit/blob/master/COPYRIGHT.md

 pragma solidity ^0.8.16;

import {RevToken} from "../../contracts/mock/RevToken.sol";
import {MockUSDCToken} from "../../contracts/mock/MockUSDCToken.sol";
import {Script} from "../../lib/forge-std/src/Script.sol";
import {console} from "../../lib/forge-std/src/console.sol";

contract DeployTokenScript is Script {

    // Rename Tokens to your desired name
    RevToken ccCoinOne;
    MockUSDCToken ccCoinTwo;

    // Replace addresses with the address that you want to mint test tokens to
    address mintee1 = 0x895A8900437ba52A7C1450b09CD05C2Ba8A0EBE5;
    address mintee2 = 0x06dae7Ba3958EF288adB0B9b3732eC204E48BC47;
    uint mintAmount = 10000000000 ether;

    function run() external {

        uint256 deployerPrivateKey= vm.envUint("SEPOLIA_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        //  Pass in name and symbol for new tokens
        ccCoinOne = new RevToken("test DAI", "DAI");
        ccCoinTwo = new MockUSDCToken("test USDC", "USDC");

        ccCoinOne.mint(mintee1, mintAmount);
        ccCoinTwo.mint(mintee1, mintAmount);

        ccCoinOne.mint(mintee2, mintAmount);
        ccCoinTwo.mint(mintee2, mintAmount);

        vm.stopBroadcast();
    }
}