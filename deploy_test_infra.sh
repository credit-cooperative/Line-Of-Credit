# DEPLOY ORACLE ###

### Replace these addresses with your deployed test tokens ###


# ccCoinOne TOKEN ADDRESS: 0xF64fC04626d3f0CA01d7C23cA77110D2B5fd8893 - 4/4/23
# ccCoinTwo TOKEN ADDRESS: 0x72bBE4dF62D5956e1d640D0fcb16DEe0A30B7049 - 4/4/23

Oracle=$(forge create --rpc-url $GOERLI_RPC_URL --constructor-args 0xF64fC04626d3f0CA01d7C23cA77110D2B5fd8893 0x72bBE4dF62D5956e1d640D0fcb16DEe0A30B7049 \
--private-key $GOERLI_PRIVATE_KEY --etherscan-api-key $MAINNET_ETHERSCAN_API_KEY  contracts/mock/SimpleOracle.sol:SimpleOracle  --verify --json)
OracleAddress=$(echo "$Oracle" | jq -r '.deployedTo')
echo $OracleAddress

### DEPLOY SWAP TARGET ###

SwapTarget=$(forge create --rpc-url $GOERLI_RPC_URL --private-key $GOERLI_PRIVATE_KEY --etherscan-api-key $MAINNET_ETHERSCAN_API_KEY contracts/mock/ZeroEx.sol:ZeroEx --verify --json)
SwapTargetAddress=$(echo "$SwapTarget" | jq -r '.deployedTo')
echo $SwapTargetAddress

### DEPLOY REV CONTRACT ###

# forge create --rpc-url $GOERLI_RPC_URL --constructor-args 0xf44B95991CaDD73ed769454A03b3820997f00873 0x589a0b00a0dD78Fc2C94b8eac676dec4C3Dcd562 \
#  --private-key $GOERLI_PRIVATE_KEY --etherscan-api-key $MAINNET_ETHERSCAN_API_KEY contracts/mock/SimpleRevenueContract.sol:SimpleRevenueContract --verify

