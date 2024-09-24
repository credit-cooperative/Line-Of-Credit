#!/bin/bash

# make sure the libraries array in the toml file looks like this 'libraries = []' with no spaces inside the brackets

brew install jq

### DEPLOY FACTORY MODULES ###

# source ../.env

# ModuleFactory=$(forge create --rpc-url $BASE_RPC_URL --private-key $BASE_PRIVATE_KEY --etherscan-api-key $BASE_API_KEY contracts/modules/factories/ModuleFactory.sol:ModuleFactory --verify --json)
# ModuleFactoryAddress=$(echo "$ModuleFactory" | jq -r '.deployedTo')
# ModuleFactoryEntry="contracts\/factory\/ModuleFactory.sol:ModuleFactory:$ModuleFactoryAddress"
# echo $ModuleFactoryAddress


### DEPLOY Oracle ###

Oracle=$(forge create --rpc-url $BASE_RPC_URL --private-key $BASE_PRIVATE_KEY --etherscan-api-key $BASE_API_KEY contracts/modules/oracle/ArbitrumOracle.sol:ArbitrumOracle --verify --json)

# Constructor Arguments: ModuleFactory Address, Arbiter Address, Oracle Address, Swap Target Address (same as Mainnet)

LineFactory=$(forge create --rpc-url $BASE_RPC_URL \
--constructor-args 0x26055b843446557bbcf8Bd3b7b49449dDF4BCB29 0xC1aF21b9f237E3332843F63364A1599Aa722947c 0xb370B80f85cD2A312f6B5f017D8AD5BD827F954C 0xDef1C0ded9bec7F1a1670819833240f027b25EfF \
--private-key $BASE_PRIVATE_KEY --etherscan-api-key $BASE_API_KEY \
contracts/modules/factories/LineFactory.sol:LineFactory --verify --json)
LineFactoryAddress=$(echo "$LineFactory" | jq -r '.deployedTo')
echo $LineFactoryAddress
