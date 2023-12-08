#!/bin/bash

# make sure the libraries array in the toml file looks like this 'libraries = []' with no spaces inside the brackets

# brew install jq

### DEPLOY FACTORY MODULES ###

source ../.env

ModuleFactory=$(forge create --rpc-url $SEPOLIA_RPC_URL --private-key $SEPOLIA_PRIVATE_KEY --etherscan-api-key $SEPOLIA_ETHERSCAN_API_KEY contracts/modules/factories/ModuleFactory.sol:ModuleFactory --verify --json)
ModuleFactoryAddress=$(echo "$ModuleFactory" | jq -r '.deployedTo')
ModuleFactoryEntry="contracts\/factory\/ModuleFactory.sol:ModuleFactory:$ModuleFactoryAddress"
echo $ModuleFactoryAddress

# Constructor Arguments: ModuleFactory Address, Arbiter Address, Oracle Address, Swap Target Address (same as Mainnet)

# LineFactory=$(forge create --rpc-url $SEPOLIA_RPC_URL \
# --constructor-args $ModuleFactoryAddress 0x06dae7Ba3958EF288adB0B9b3732eC204E48BC47 0x06dae7Ba3958EF288adB0B9b3732eC204E48BC47 0xdef1c0ded9bec7f1a1670819833240f027b25eff \
# --private-key $SEPOLIA_PRIVATE_KEY --etherscan-api-key $SEPOLIA_ETHERSCAN_API_KEY \
# contracts/modules/factories/LineFactory.sol:LineFactory --verify --json)]
# LineFactoryAddress=$(echo "$LineFactory" | jq -r '.deployedTo')
# echo $LineFactoryAddress
