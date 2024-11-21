#!/bin/bash

# make sure the libraries array in the toml file looks like this 'libraries = []' with no spaces inside the brackets

brew install jq

### DEPLOY FACTORY MODULES ###

# source ../.env

ModuleFactory=$(forge create --rpc-url $PLUME_DEVNET_RPC_URL --private-key $PlUME_DEVNET_PRIVATE_KEY contracts/modules/factories/ModuleFactory.sol:ModuleFactory --verify --json)
ModuleFactoryAddress=$(echo "$ModuleFactory" | jq -r '.deployedTo')
ModuleFactoryEntry="contracts\/factory\/ModuleFactory.sol:ModuleFactory:$ModuleFactoryAddress"
echo $ModuleFactoryAddress

forge verify-contract 0x1529A4AaCc4f8F7Ed1708c1c7879536BeEd5a715 contracts/modules/factories/ModuleFactory.sol:ModuleFactory \
  --rpc-url https://devnet-rpc.plumenetwork.xyz \
  --verifier oklink --verifier-url \
  https://www.oklink.com/api/v5/explorer/contract/verify-source-code-plugin/PLUME_DEVNET \
  --api-key 91181d88-9dbe-4eb3-b228-81bcee2d118a
### DEPLOY Oracle ###

Oracle=$(forge create --rpc-url $PLUME_DEVNET_RPC_URL --private-key $PlUME_DEVNET_PRIVATE_KEY contracts/modules/oracle/PlumeDevnetOracle.sol:PlumeDevnetOracle --verify --json)

forge verify-contract 0x26055b843446557bbcf8Bd3b7b49449dDF4BCB29 contracts/modules/oracle/PlumeDevnetOracle.sol:PlumeDevnetOracle \
  --rpc-url https://devnet-rpc.plumenetwork.xyz \
  --verifier oklink --verifier-url \
  https://www.oklink.com/api/v5/explorer/contract/verify-source-code-plugin/PLUME_DEVNET \
  --api-key 91181d88-9dbe-4eb3-b228-81bcee2d118a



# Constructor Arguments: ModuleFactory Address, Arbiter Address, Oracle Address, Swap Target Address

LineFactory=$(forge create --rpc-url $PLUME_DEVNET_RPC_URL \
--constructor-args 0x1529A4AaCc4f8F7Ed1708c1c7879536BeEd5a715 0xf44B95991CaDD73ed769454A03b3820997f00873 0x26055b843446557bbcf8Bd3b7b49449dDF4BCB29 0xf44B95991CaDD73ed769454A03b3820997f00873  \
--private-key $PlUME_DEVNET_PRIVATE_KEY \
contracts/modules/factories/LineFactory.sol:LineFactory --verify --json)
LineFactoryAddress=$(echo "$LineFactory" | jq -r '.deployedTo')
echo $LineFactoryAddress


forge verify-contract 0x268B02858C32FBDbC33a8453339DB033B4326485 contracts/modules/factories/LineFactory.sol:LineFactory \
  --rpc-url https://devnet-rpc.plumenetwork.xyz \
  --verifier oklink --verifier-url \
  https://www.oklink.com/api/v5/explorer/contract/verify-source-code-plugin/PLUME_DEVNET \
  --api-key 91181d88-9dbe-4eb3-b228-81bcee2d118a
