#!/bin/bash
source ../.env

# ### DEPLOY REV CONTRACT ###

SimpleRevenueContract=$(forge create --rpc-url $BASE_RPC_URL --constructor-args 0x06dae7Ba3958EF288adB0B9b3732eC204E48BC47 0xaf88d065e77c8cC2239327C5EDb3A432268e5831 \
 --private-key $BASE_PRIVATE_KEY --etherscan-api-key $BASE_API_KEY contracts/mock/SimpleRevenueContract.sol:SimpleRevenueContract --verify --json)
SimpleRevenueContractAddress=$(echo "$SimpleRevenueContract" | jq -r '.deployedTo')
echo $SimpleRevenueContractAddress

# # Verify contract
# forge verify-contract \
#     --chain-id 42161 \
#     --watch \
#     --constructor-args $(cast abi-encode "constructor(address,address)" 0x06dae7Ba3958EF288adB0B9b3732eC204E48BC47 0xaf88d065e77c8cC2239327C5EDb3A432268e5831)  \
#     --rpc-url $BASE_RPC_URL --etherscan-api-key $BASE_API_KEY \
#     0x081B1f32434826f46652C0aAC20E1560aFC0Ce24 \
#     SimpleRevenueContract


# forge create --rpc-url $BASE_RPC_URL --constructor-args 0xb7c75c110467B1c5dc1af60D0A3C245eD0b883f9 --private-key $BASE_PRIVATE_KEY --etherscan-api-key $BASE_API_KEY  contracts/modules/oracle/Oracle.sol:Oracle  --verify

# forge create --rpc-url $BASE_RPC_URL  --private-key $BASE_PRIVATE_KEY --etherscan-api-key $BASE_API_KEY  contracts/modules/oracle/PolygonOracle.sol:PolygonOracle  --verify