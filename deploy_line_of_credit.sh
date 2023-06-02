#!/bin/bash

# make sure the libraries array in the toml file looks like this 'libraries = []' with no spaces inside the brackets

# brew install jq

### Deploy LoC Modules ###

source .env


### constructor arguments: minCRatio, oracle address, owner, borrower
Escrow=$(forge create --rpc-url $GOERLI_RPC_URL \
--constructor-args 5000 0x93E01461b2B02Fe872C1C5CceAd3E334BFA3C0De 0x1a171a91B4Aa1A669e2397D6670746DDcDd4fbBe 0x1a171a91B4Aa1A669e2397D6670746DDcDd4fbBe \
--private-key $GOERLI_PRIVATE_KEY --etherscan-api-key $MAINNET_ETHERSCAN_API_KEY contracts/modules/escrow/Escrow.sol:Escrow --verify --json)
EscrowAddress=$(echo "$Escrow" | jq -r '.deployedTo')
echo $EscrowAddress


### constructor arguments: owner, operator
Spigot=$(forge create --rpc-url $GOERLI_RPC_URL \
--constructor-args 0x1a171a91B4Aa1A669e2397D6670746DDcDd4fbBe 0x1a171a91B4Aa1A669e2397D6670746DDcDd4fbBe \
--private-key $GOERLI_PRIVATE_KEY --etherscan-api-key $MAINNET_ETHERSCAN_API_KEY contracts/modules/spigot/Spigot.sol:Spigot --verify --json)
SpigotAddress=$(echo "$Spigot" | jq -r '.deployedTo')
echo $SpigotAddress


### constructor arguments: oracle, arbiter, borrower, swapTarget, spigot, escrow, ttl (3 days), defaultSplit
SecuredLine=$(forge create --rpc-url $GOERLI_RPC_URL \
--constructor-args 0x93E01461b2B02Fe872C1C5CceAd3E334BFA3C0De 0x895A8900437ba52A7C1450b09CD05C2Ba8A0EBE5 0x1a171a91B4Aa1A669e2397D6670746DDcDd4fbBe 0x47B005bC1AD130D6a61c2d21047Ee84e03e5Aa8f $SpigotAddress $EscrowAddress 259200 50 \
--private-key $GOERLI_PRIVATE_KEY --etherscan-api-key $MAINNET_ETHERSCAN_API_KEY contracts/modules/credit/SecuredLine.sol:SecuredLine --verify --json)
SecuredLineAddress=$(echo "$SecuredLine" | jq -r '.deployedTo')
echo $SecuredLineAddress

# After deployement, transfer ownership of both Spigot and Escrow to Line of Credit, and the init() on Line of Credit, register on Line Factory
# transfer ownership of spigot: updateOwner
# transfer ownership of escrow: updateLine

