#!/bin/bash

# make sure the libraries array in the toml file looks like this 'libraries = []' with no spaces inside the brackets

# brew install jq

### DEPLOY FACTORY MODULES ###

# source ../.env

ModuleFactory=$(forge create --rpc-url $POLYGON_RPC_URL --private-key $POLYGON_PRIVATE_KEY --etherscan-api-key $POLYGONSCAN_API_KEY contracts/modules/factories/ModuleFactory.sol:ModuleFactory --verify --json)
ModuleFactoryAddress=$(echo "$ModuleFactory" | jq -r '.deployedTo')
ModuleFactoryEntry="contracts\/factory\/ModuleFactory.sol:ModuleFactory:$ModuleFactoryAddress"
echo $ModuleFactoryAddress

# Constructor Arguments: ModuleFactory Address, Arbiter Address, Oracle Address, Swap Target Address (same as Mainnet)

LineFactory=$(forge create --rpc-url $POLYGON_RPC_URL \
--constructor-args 0x4AE0962441B763981000A99306AB5016238B8F40 0xFE002526dEc5B3e4b5134b75b20c065178323343 0xF1baA8242e3AAF65D4Eb030459854cddE209acb9 0xdef1c0ded9bec7f1a1670819833240f027b25eff \
--private-key $POLYGON_PRIVATE_KEY --etherscan-api-key $POLYGONSCAN_API_KEY \
contracts/modules/factories/LineFactory.sol:LineFactory --verify --json)]
LineFactoryAddress=$(echo "$LineFactory" | jq -r '.deployedTo')
echo $LineFactoryAddress
