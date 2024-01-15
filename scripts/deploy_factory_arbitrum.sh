#!/bin/bash

# make sure the libraries array in the toml file looks like this 'libraries = []' with no spaces inside the brackets

brew install jq

### DEPLOY FACTORY MODULES ###

# source ../.env

# ModuleFactory=$(forge create --rpc-url $ARBITRUM_RPC_URL --private-key $ARBITRUM_PRIVATE_KEY --etherscan-api-key $ARBISCAN_API_KEY contracts/modules/factories/ModuleFactory.sol:ModuleFactory --verify --json)
# ModuleFactoryAddress=$(echo "$ModuleFactory" | jq -r '.deployedTo')
# ModuleFactoryEntry="contracts\/factory\/ModuleFactory.sol:ModuleFactory:$ModuleFactoryAddress"
# echo $ModuleFactoryAddress


### DEPLOY Oracle ###

Oracle=$(forge create --rpc-url $ARBITRUM_RPC_URL --private-key $ARBITRUM_PRIVATE_KEY --etherscan-api-key $ARBISCAN_API_KEY contracts/modules/oracle/ArbitrumOracle.sol:ArbitrumOracle --verify --json)

# Constructor Arguments: ModuleFactory Address, Arbiter Address, Oracle Address, Swap Target Address (same as Mainnet)

LineFactory=$(forge create --rpc-url $ARBITRUM_RPC_URL \
--constructor-args 0x0f436F62f3CE9D2F25231f1DAE71b77A4F8EeDf9 0xFE002526dEc5B3e4b5134b75b20c065178323343 0x47B005bC1AD130D6a61c2d21047Ee84e03e5Aa8f 0xdef1c0ded9bec7f1a1670819833240f027b25eff \
--private-key $ARBITRUM_PRIVATE_KEY --etherscan-api-key $ARBISCAN_API_KEY \
contracts/modules/factories/LineFactory.sol:LineFactory --verify --json)]
LineFactoryAddress=$(echo "$LineFactory" | jq -r '.deployedTo')
echo $LineFactoryAddress
