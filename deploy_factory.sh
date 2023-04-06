#!/bin/bash

# make sure the libraries array in the toml file looks like this 'libraries = []' with no spaces inside the brackets

brew install jq

### DEPLOY FACTORY MODULES ###

source .env

ModuleFactory=$(forge create --rpc-url $MAINNET_RPC_URL --private-key $MAINNET_PRIVATE_KEY --etherscan-api-key $MAINNET_ETHERSCAN_API_KEY contracts/modules/factories/ModuleFactory.sol:ModuleFactory --verify --json)
ModuleFactoryAddress=$(echo "$ModuleFactory" | jq -r '.deployedTo')
ModuleFactoryEntry="contracts\/factory\/ModuleFactory.sol:ModuleFactory:$ModuleFactoryAddress"
echo $ModuleFactoryAddress

# Constructor Arguments: ModuleFactory Address, Arbiter Address, Oracle Address, Swap Target Address

LineFactory=$(forge create --rpc-url $MAINNET_RPC_URL \
--constructor-args $ModuleFactoryAddress 0xeb0566b1EF38B95da2ed631eBB8114f3ac7b9a8a 0x5a4AAF300473eaF8A9763318e7F30FA8a3f5Dd48 0xdef1c0ded9bec7f1a1670819833240f027b25eff \
--private-key $MAINNET_PRIVATE_KEY --etherscan-api-key $MAINNET_ETHERSCAN_API_KEY \
contracts/modules/factories/LineFactory.sol:LineFactory --verify --json)]
LineFactoryAddress=$(echo "$LineFactory" | jq -r '.deployedTo')
echo $LineFactoryAddress
