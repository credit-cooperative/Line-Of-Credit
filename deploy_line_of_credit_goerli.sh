#!/bin/bash

# make sure the libraries array in the toml file looks like this 'libraries = []' with no spaces inside the brackets

# brew install jq

### Deploy LoC Modules ###

source .env


### constructor arguments: minCRatio, oracle address, owner, borrower
Escrow=$(forge create --rpc-url $GOERLI_RPC_URL \
--constructor-args 5000 0x93E01461b2B02Fe872C1C5CceAd3E334BFA3C0De 0xf44B95991CaDD73ed769454A03b3820997f00873 0xf44B95991CaDD73ed769454A03b3820997f00873 \
--private-key $GOERLI_PRIVATE_KEY --etherscan-api-key $GOERLI_ETHERSCAN_API_KEY contracts/modules/escrow/Escrow.sol:Escrow --verify --json)
EscrowAddress=$(echo "$Escrow" | jq -r '.deployedTo')
echo $EscrowAddress


### constructor arguments: owner, operator
Spigot=$(forge create --rpc-url $GOERLI_RPC_URL \
--constructor-args 0xf44B95991CaDD73ed769454A03b3820997f00873 0x97fCbc96ed23e4E9F0714008C8f137D57B4d6C97 \
--private-key $GOERLI_PRIVATE_KEY --etherscan-api-key $GOERLI_ETHERSCAN_API_KEY contracts/modules/spigot/Spigot.sol:Spigot --verify --json)
SpigotAddress=$(echo "$Spigot" | jq -r '.deployedTo')
echo $SpigotAddress


### constructor arguments: oracle, arbiter, borrower, swapTarget, spigot, escrow, ttl (3 days), defaultSplit
SecuredLine=$(forge create --rpc-url $GOERLI_RPC_URL \
--constructor-args 0x93E01461b2B02Fe872C1C5CceAd3E334BFA3C0De 0x9832FD4537F3143b5C2989734b11A54D4E85eEF6 0xf44B95991CaDD73ed769454A03b3820997f00873 0x47B005bC1AD130D6a61c2d21047Ee84e03e5Aa8f $SpigotAddress $EscrowAddress 259200 50 \
--private-key $GOERLI_PRIVATE_KEY --etherscan-api-key $GOERLI_ETHERSCAN_API_KEY contracts/modules/credit/SecuredLine.sol:SecuredLine --verify --json)
SecuredLineAddress=$(echo "$SecuredLine" | jq -r '.deployedTo')
echo $SecuredLineAddress

# After deployement, transfer ownership of both Spigot and Escrow to Line of Credit, and the init() on Line of Credit, register on Line Factory
# transfer ownership of spigot: updateOwner
# transfer ownership of escrow: updateLine

