 pragma solidity ^0.8.9;

import {RevToken} from "../../contracts/mock/RevToken.sol";
import {Script} from "../../lib/forge-std/src/Script.sol";
import {console} from "../../lib/forge-std/src/console.sol";

contract DeployTokenScript is Script {
    
    // Rename Tokens to your desired name
    RevToken ccCoinOne;
    RevToken ccCoinTwo;

    // Replace addresses with the address that you want to mint test tokens to
    address mintee1 = 0x539E70A18073436Eef2E3314A540A7c71dD4B57B;
    address mintee2 = 0x06dae7Ba3958EF288adB0B9b3732eC204E48BC47;
    uint mintAmount = 10000000000 ether;
    
    function run() external {
        
        uint256 deployerPrivateKey= vm.envUint("GOERLI_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        //  Pass in name and symbol for new tokens
        ccCoinOne = new RevToken("ccCoinOne", "CC1");
        ccCoinTwo = new RevToken("ccCoinTwo", "CC2");

        ccCoinOne.mint(mintee1, mintAmount);
        ccCoinTwo.mint(mintee1, mintAmount);

        vm.stopBroadcast();
    }
}