#!/bin/bash

# make sure the libraries array in the toml file looks like this 'libraries = []' with no spaces inside the brackets

brew install jq

### DEPLOY FACTORY MODULES ###

source .env

<<<<<<< HEAD:deploy_factory_mainnet.sh
ModuleFactory=$(forge create --rpc-url $POLYGON_RPC_URL --private-key $POLYGON_PRIVATE_KEY --etherscan-api-key $POLYGON_ETHERSCAN_API_KEY contracts/modules/factories/ModuleFactory.sol:ModuleFactory --verify --json)
=======
ModuleFactory=$(forge create --rpc-url $GOERLI_RPC_URL --private-key $GOERLI_PRIVATE_KEY --etherscan-api-key $GOERLI_ETHERSCAN_API_KEY contracts/modules/factories/ModuleFactory.sol:ModuleFactory --verify --json)
>>>>>>> develop:deploy_factory_goerli.sh
ModuleFactoryAddress=$(echo "$ModuleFactory" | jq -r '.deployedTo')
ModuleFactoryEntry="contracts\/factory\/ModuleFactory.sol:ModuleFactory:$ModuleFactoryAddress"
echo $ModuleFactoryAddress

# Constructor Arguments: ModuleFactory Address, Arbiter Address, Oracle Address, Swap Target Address (same as Mainnet)

LineFactory=$(forge create --rpc-url $GOERLI_RPC_URL \
<<<<<<< HEAD:deploy_factory_mainnet.sh
--constructor-args $ModuleFactoryAddress 0x895A8900437ba52A7C1450b09CD05C2Ba8A0EBE5 0x93E01461b2B02Fe872C1C5CceAd3E334BFA3C0De 0xdef1c0ded9bec7f1a1670819833240f027b25eff \
--private-key $GOERLI_PRIVATE_KEY --etherscan-api-key $MAINNET_ETHERSCAN_API_KEY \
=======
--constructor-args $ModuleFactoryAddress 0x9832FD4537F3143b5C2989734b11A54D4E85eEF6 0x93E01461b2B02Fe872C1C5CceAd3E334BFA3C0De 0x47B005bC1AD130D6a61c2d21047Ee84e03e5Aa8f \
--private-key $GOERLI_PRIVATE_KEY --etherscan-api-key $GOERLI_ETHERSCAN_API_KEY \
>>>>>>> develop:deploy_factory_goerli.sh
contracts/modules/factories/LineFactory.sol:LineFactory --verify --json)]
LineFactoryAddress=$(echo "$LineFactory" | jq -r '.deployedTo')
echo $LineFactoryAddress
