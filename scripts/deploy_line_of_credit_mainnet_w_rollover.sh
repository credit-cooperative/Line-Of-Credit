#!/bin/bash

# make sure the libraries array in the toml file looks like this 'libraries = []' with no spaces inside the brackets

# brew install jq

### Deploy LoC Modules ###

source ../.env

read -p "Did you change FOUNDRY_PROFILE to the correct chain? [y/N] " answer

case $answer in
    [Yy]* ) echo "Continuing...";;
    [Nn]* ) echo "Exiting..."; exit;;
    * ) echo "Please answer yes or no."; exit;;
esac

echo  -n "Borrower Address: "
read borrower_address

echo  -n "Oracle Address: "
read oracle_address

echo  -n "Arbiter Address: "
read arbiter_address

echo  -n "Swap Target Address: "
read swap_target_address

echo -n "Min C Ratio: "
read min_c_ratio

echo -n "Default Split: "
read default_split

echo -n "TTL (days): "
read days
ttl=$((days * 86400))

echo -n "Spigot address: "
read SpigotAddress

echo -n "Escrow address: "
read EscrowAddress


echo "borrower address: " $borrower_address
echo "oracle address: " $oracle_address
echo "arbiter_address: "  $arbiter_address
echo "swap target address: " $swap_target_address
echo "min c ratio: " $min_c_ratio
echo "default split: " $default_split
echo "ttl: " $ttl
echo "Spigot address: " $SpigotAddress
echo "Escrow address: " $EscrowAddress

read -p "Do you wish to continue? [y/N] " answer

case $answer in
    [Yy]* ) echo "Continuing...";;
    [Nn]* ) echo "Exiting..."; exit;;
    * ) echo "Please answer yes or no."; exit;;
esac

echo "Deploying Line of Credit"

### constructor arguments: oracle, arbiter, borrower, swapTarget, spigot, escrow, ttl (3 days), defaultSplit
SecuredLine=$(forge create --rpc-url $MAINNET_RPC_URL \
--constructor-args $oracle_address $arbiter_address $borrower_address $swap_target_address $SpigotAddress $EscrowAddress $ttl $default_split \
--private-key $MAINNET_PRIVATE_KEY --etherscan-api-key $MAINNET_ETHERSCAN_API_KEY contracts/modules/credit/SecuredLine.sol:SecuredLine --verify --json)
SecuredLineAddress=$(echo "$SecuredLine" | jq -r '.deployedTo')
echo $SecuredLineAddress

