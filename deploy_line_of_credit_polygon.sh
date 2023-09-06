#!/bin/bash

# make sure the libraries array in the toml file looks like this 'libraries = []' with no spaces inside the brackets

# brew install jq

### Deploy LoC Modules ###

source .env


### constructor arguments: minCRatio, oracle address, owner, borrower
Escrow=$(forge create --rpc-url $POLYGON_RPC_URL \
--constructor-args 0 0xF1baA8242e3AAF65D4Eb030459854cddE209acb9 0xf44B95991CaDD73ed769454A03b3820997f00873 0x06dae7Ba3958EF288adB0B9b3732eC204E48BC47 \
--private-key $POLYGON_PRIVATE_KEY --etherscan-api-key $POLYGON_ETHERSCAN_API_KEY contracts/modules/escrow/Escrow.sol:Escrow --verify --json)
EscrowAddress=$(echo "$Escrow" | jq -r '.deployedTo')
echo $EscrowAddress


### constructor arguments: owner, operator
Spigot=$(forge create --rpc-url $POLYGON_RPC_URL \
--constructor-args 0xf44B95991CaDD73ed769454A03b3820997f00873 0x06dae7Ba3958EF288adB0B9b3732eC204E48BC47 \
--private-key $POLYGON_PRIVATE_KEY --etherscan-api-key $POLYGON_ETHERSCAN_API_KEY contracts/modules/spigot/Spigot.sol:Spigot --verify --json)
SpigotAddress=$(echo "$Spigot" | jq -r '.deployedTo')
echo $SpigotAddress


### constructor arguments: oracle, arbiter, borrower, swapTarget, spigot, escrow, ttl (3 days), defaultSplit
SecuredLine=$(forge create --rpc-url $POLYGON_RPC_URL \
--constructor-args 0xF1baA8242e3AAF65D4Eb030459854cddE209acb9 0xFE002526dEc5B3e4b5134b75b20c065178323343 0x06dae7Ba3958EF288adB0B9b3732eC204E48BC47 0xdef1c0ded9bec7f1a1670819833240f027b25eff $SpigotAddress $EscrowAddress 259200 100 \
--private-key $POLYGON_PRIVATE_KEY --etherscan-api-key $POLYGON_ETHERSCAN_API_KEY contracts/modules/credit/SecuredLine.sol:SecuredLine --verify --json)
SecuredLineAddress=$(echo "$SecuredLine" | jq -r '.deployedTo')
echo $SecuredLineAddress

# After deployement, transfer ownership of both Spigot and Escrow to Line of Credit, and the init() on Line of Credit, register on Line Factory
# transfer ownership of spigot: updateOwner
# transfer ownership of escrow: updateLine

