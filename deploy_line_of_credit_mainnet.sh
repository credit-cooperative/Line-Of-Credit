#!/bin/bash

# make sure the libraries array in the toml file looks like this 'libraries = []' with no spaces inside the brackets

# brew install jq

### Deploy LoC Modules ###

source .env


### constructor arguments: minCRatio, oracle address, owner, borrower
Escrow=$(forge create --rpc-url $MAINNET_RPC_URL \
--constructor-args 0 0x5a4AAF300473eaF8A9763318e7F30FA8a3f5Dd48 0x06dae7Ba3958EF288adB0B9b3732eC204E48BC47 0x06dae7Ba3958EF288adB0B9b3732eC204E48BC47 \
--private-key $MAINNET_PRIVATE_KEY --etherscan-api-key $MAINNET_ETHERSCAN_API_KEY contracts/modules/escrow/Escrow.sol:Escrow --verify --json)
EscrowAddress=$(echo "$Escrow" | jq -r '.deployedTo')
echo $EscrowAddress


### constructor arguments: owner, operator
Spigot=$(forge create --rpc-url $MAINNET_RPC_URL \
--constructor-args 0x06dae7Ba3958EF288adB0B9b3732eC204E48BC47 0x06dae7Ba3958EF288adB0B9b3732eC204E48BC47 \
--private-key $MAINNET_PRIVATE_KEY --etherscan-api-key $MAINNET_ETHERSCAN_API_KEY contracts/modules/spigot/Spigot.sol:Spigot --verify --json)
SpigotAddress=$(echo "$Spigot" | jq -r '.deployedTo')
echo $SpigotAddress


### constructor arguments: oracle, arbiter, borrower, swapTarget, spigot, escrow, ttl (3 days), defaultSplit
SecuredLine=$(forge create --rpc-url $MAINNET_RPC_URL \
--constructor-args 0x5a4AAF300473eaF8A9763318e7F30FA8a3f5Dd48 0xeb0566b1EF38B95da2ed631eBB8114f3ac7b9a8a 0x06dae7Ba3958EF288adB0B9b3732eC204E48BC47 0xDef1C0ded9bec7F1a1670819833240f027b25EfF $SpigotAddress $EscrowAddress 259200 100 \
--private-key $MAINNET_PRIVATE_KEY --etherscan-api-key $MAINNET_ETHERSCAN_API_KEY contracts/modules/credit/SecuredLine.sol:SecuredLine --verify --json)
SecuredLineAddress=$(echo "$SecuredLine" | jq -r '.deployedTo')
echo $SecuredLineAddress

# After deployement, transfer ownership of both Spigot and Escrow to Line of Credit, and the init() on Line of Credit, register on Line Factory
# transfer ownership of spigot: updateOwner
# transfer ownership of escrow: updateLine

