#!/bin/bash

# make sure the libraries array in the toml file looks like this 'libraries = []' with no spaces inside the brackets

brew install jq

### DEPLOY FACTORY MODULES ###

source .env

ModuleFactory=$(forge create --rpc-url $MAINNET_RPC_URL --private-key $MAINNET_PRIVATE_KEY --etherscan-api-key $MAINNET_ETHERSCAN_API_KEY contracts/modules/factories/ModuleFactory.sol:ModuleFactory --verify --json)
ModuleFactoryAddress=$(echo "$ModuleFactory" | jq -r '.deployedTo')
ModuleFactoryEntry="contracts\/factory\/ModuleFactory.sol:ModuleFactory:$ModuleFactoryAddress"
echo $ModuleFactoryAddress

# Constructor Arguments: ModuleFactory Address, Arbiter Address, Oracle Address, Swap Target Address (same as Mainnet)

LineFactory=$(forge create --rpc-url $MAINNET_RPC_URL \
--constructor-args $ModuleFactoryAddress 0x895A8900437ba52A7C1450b09CD05C2Ba8A0EBE5 0x93E01461b2B02Fe872C1C5CceAd3E334BFA3C0De 0xdef1c0ded9bec7f1a1670819833240f027b25eff \
--private-key $MAINNET_PRIVATE_KEY --etherscan-api-key $MAINNET_ETHERSCAN_API_KEY \
contracts/modules/factories/LineFactory.sol:LineFactory --verify --json)]
LineFactoryAddress=$(echo "$LineFactory" | jq -r '.deployedTo')
echo $LineFactoryAddress
