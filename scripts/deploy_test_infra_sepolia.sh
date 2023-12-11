#!/bin/bash
source ../.env

# DEPLOY TEST TOKENS ###
# DeployTokens=$(forge script --rpc-url $SEPOLIA_RPC_URL \
# --private-key $SEPOLIA_PRIVATE_KEY --etherscan-api-key $SEPOLIA_ETHERSCAN_API_KEY  DeployTokenScript  --verify --broadcast)
# DeployTokensAddress=$(echo "$DeployTokens" | jq -r '.deployedTo')
# echo $DeployTokens

# DEPLOY ORACLE ###

### Replace these addresses with your deployed test tokens ###

# ccCoinOne TOKEN ADDRESS: 0xbCfB1bC0ce6c04D1adBbcDEE13e9f94E6fbDc64d - 12/11/23
# ccCoinTwo TOKEN ADDRESS: 0xcfEE544566ff8156bfC2C20d97f03882be4b5353 - 12/11/23

Oracle=$(forge create --rpc-url $SEPOLIA_RPC_URL --constructor-args 0xF64fC04626d3f0CA01d7C23cA77110D2B5fd8893 0x72bBE4dF62D5956e1d640D0fcb16DEe0A30B7049 \
--private-key $SEPOLIA_PRIVATE_KEY --etherscan-api-key $MAINNET_ETHERSCAN_API_KEY  contracts/mock/SimpleOracle.sol:SimpleOracle  --verify --json)
OracleAddress=$(echo "$Oracle" | jq -r '.deployedTo')
echo $OracleAddress

# ### DEPLOY SWAP TARGET ###

# SwapTarget=$(forge create --rpc-url $SEPOLIA_RPC_URL --private-key $SEPOLIA_PRIVATE_KEY --etherscan-api-key $MAINNET_ETHERSCAN_API_KEY contracts/mock/ZeroEx.sol:ZeroEx --verify --json)
# SwapTargetAddress=$(echo "$SwapTarget" | jq -r '.deployedTo')
# echo $SwapTargetAddress

# ### DEPLOY REV CONTRACT ###

# SimpleRevenueContract=$(forge create --rpc-url $SEPOLIA_RPC_URL --constructor-args 0x06dae7Ba3958EF288adB0B9b3732eC204E48BC47 0xF64fC04626d3f0CA01d7C23cA77110D2B5fd8893 \
#  --private-key $SEPOLIA_PRIVATE_KEY --etherscan-api-key $MAINNET_ETHERSCAN_API_KEY contracts/mock/SimpleRevenueContract.sol:SimpleRevenueContract --verify --json)
# SimpleRevenueContractAddress=$(echo "$SimpleRevenueContract" | jq -r '.deployedTo')
# echo $SimpleRevenueContractAddress


# forge create --rpc-url $POLYGON_RPC_URL --constructor-args 0xb7c75c110467B1c5dc1af60D0A3C245eD0b883f9 --private-key $POLYGON_PRIVATE_KEY --etherscan-api-key $POLYGON_ETHERSCAN_API_KEY  contracts/modules/oracle/Oracle.sol:Oracle  --verify

# forge create --rpc-url $POLYGON_RPC_URL  --private-key $POLYGON_PRIVATE_KEY --etherscan-api-key $POLYGON_ETHERSCAN_API_KEY  contracts/modules/oracle/PolygonOracle.sol:PolygonOracle  --verify