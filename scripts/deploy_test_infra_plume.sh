#!/bin/bash
source ../.env

# ### DEPLOY REV CONTRACT ###

SimpleRevenueContract=$(forge create --rpc-url $PLUME_RPC_URL --constructor-args 0x06dae7Ba3958EF288adB0B9b3732eC204E48BC47 0x1aa70741167155E08bD319bE096C94eE54C6CA19 \
 --private-key $PLUME_PRIVATE_KEY --etherscan-api-key $PLUME_SCAN_API_KEY contracts/mock/SimpleRevenueContract.sol:SimpleRevenueContract --verify --json)
SimpleRevenueContractAddress=$(echo "$SimpleRevenueContract" | jq -r '.deployedTo')
echo $SimpleRevenueContractAddress


# forge create --rpc-url $PLUME_RPC_URL --constructor-args 0x06dae7Ba3958EF288adB0B9b3732eC204E48BC47 0x1aa70741167155E08bD319bE096C94eE54C6CA19 \
#  --private-key $PLUME_PRIVATE_KEY --etherscan-api-key $MAINNET_ETHERSCAN_API_KEY contracts/mock/SimpleRevenueContract.sol:SimpleRevenueContract --verify --json