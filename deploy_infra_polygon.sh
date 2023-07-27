#!/bin/bash
source .env

# DEPLOY ORACLE ###

### Replace these addresses with your deployed test tokens ###

# ccCoinOne TOKEN ADDRESS: 0xF64fC04626d3f0CA01d7C23cA77110D2B5fd8893 - 4/4/23
# ccCoinTwo TOKEN ADDRESS: 0x72bBE4dF62D5956e1d640D0fcb16DEe0A30B7049 - 4/4/23

# Oracle=$(forge create --rpc-url $GOERLI_RPC_URL --constructor-args 0xF64fC04626d3f0CA01d7C23cA77110D2B5fd8893 0x72bBE4dF62D5956e1d640D0fcb16DEe0A30B7049 \
# --private-key $GOERLI_PRIVATE_KEY --etherscan-api-key $MAINNET_ETHERSCAN_API_KEY  contracts/mock/SimpleOracle.sol:SimpleOracle  --verify --json)
# OracleAddress=$(echo "$Oracle" | jq -r '.deployedTo')
# echo $OracleAddress

# forge create --rpc-url $POLYGON_RPC_URL --constructor-args 0xb7c75c110467B1c5dc1af60D0A3C245eD0b883f9 --private-key $POLYGON_PRIVATE_KEY --etherscan-api-key $POLYGON_ETHERSCAN_API_KEY  contracts/modules/oracle/Oracle.sol:Oracle  --verify

# ### DEPLOY SWAP TARGET ###

# SwapTarget=$(forge create --rpc-url $GOERLI_RPC_URL --private-key $GOERLI_PRIVATE_KEY --etherscan-api-key $MAINNET_ETHERSCAN_API_KEY contracts/mock/ZeroEx.sol:ZeroEx --verify --json)
# SwapTargetAddress=$(echo "$SwapTarget" | jq -r '.deployedTo')
# echo $SwapTargetAddress

# ### DEPLOY REV CONTRACT ###

SimpleRevenueContract=$(forge create --rpc-url $POLYGON_RPC_URL --constructor-args 0x06dae7Ba3958EF288adB0B9b3732eC204E48BC47 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174 \
 --private-key $POLYGON_PRIVATE_KEY --etherscan-api-key $POLYGON_ETHERSCAN_API_KEY contracts/mock/SimpleRevenueContract.sol:SimpleRevenueContract --verify --json)
SimpleRevenueContractAddress=$(echo "$SimpleRevenueContract" | jq -r '.deployedTo')
echo $SimpleRevenueContractAddress



