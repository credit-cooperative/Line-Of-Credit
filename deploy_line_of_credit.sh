#!/bin/bash

# make sure the libraries array in the toml file looks like this 'libraries = []' with no spaces inside the brackets

brew install jq

### Deploy LoC Modules ###

source .env


### constructor arguments: minCRatio, oracle address, owner, borrower
Escrow=$(forge create --rpc-url $GOERLI_RPC_URL \
--constructor-args 0 0x93E01461b2B02Fe872C1C5CceAd3E334BFA3C0De 0x539E70A18073436Eef2E3314A540A7c71dD4B57B 0x539E70A18073436Eef2E3314A540A7c71dD4B57B \
--private-key $GOERLI_PRIVATE_KEY --etherscan-api-key $MAINNET_ETHERSCAN_API_KEY contracts/modules/escrow/Escrow.sol:Escrow --verify --json)
EscrowAddress=$(echo "$Escrow" | jq -r '.deployedTo')
echo $EscrowAddress


### constructor arguments: owner, operator
Spigot=$(forge create --rpc-url $GOERLI_RPC_URL \
--constructor-args 0x539E70A18073436Eef2E3314A540A7c71dD4B57B 0x539E70A18073436Eef2E3314A540A7c71dD4B57B \
--private-key $GOERLI_PRIVATE_KEY --etherscan-api-key $MAINNET_ETHERSCAN_API_KEY contracts/modules/spigot/Spigot.sol:Spigot --verify --json)
SpigotAddress=$(echo "$Spigot" | jq -r '.deployedTo')
echo $SpigotAddress


### constructor arguments: oracle, arbiter, borrower, swapTarget, spigot, escrow, ttl, defaultSplit
SecuredLine=$(forge create --rpc-url $GOERLI_RPC_URL \
--constructor-args 0x93E01461b2B02Fe872C1C5CceAd3E334BFA3C0De 0x895A8900437ba52A7C1450b09CD05C2Ba8A0EBE5 0x539E70A18073436Eef2E3314A540A7c71dD4B57B 0x47B005bC1AD130D6a61c2d21047Ee84e03e5Aa8f 0x7C64ee348902f23F6764715C7c60FE557C2a502D 0x1c5b78eeFA529f698F37374F9CD757fD68E628eD 3 0 \
--private-key $GOERLI_PRIVATE_KEY --etherscan-api-key $MAINNET_ETHERSCAN_API_KEY contracts/modules/credit/SecuredLine.sol:SecuredLine --verify --json)
SecuredLineAddress=$(echo "$SecuredLine" | jq -r '.deployedTo')
echo $SecuredLineAddress


