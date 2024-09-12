#!/bin/bash
source ../.env

# ### DEPLOY REV CONTRACT ###

SimpleRevenueContract=$(forge create --rpc-url $BASE_RPC_URL --constructor-args 0x06dae7Ba3958EF288adB0B9b3732eC204E48BC47 0xaf88d065e77c8cC2239327C5EDb3A432268e5831 \
 --private-key $BASE_PRIVATE_KEY --etherscan-api-key $BASE_API_KEY contracts/mock/SimpleRevenueContract.sol:SimpleRevenueContract --verify --json)
SimpleRevenueContractAddress=$(echo "$SimpleRevenueContract" | jq -r '.deployedTo')
echo $SimpleRevenueContractAddress

# line
forge verify-contract 
--chain-id 8453 \
--watch \
--constructor-args $(cast abi-encode "constructor(address,address,address,address,address,address,uint,uint8)” 0xb370B80f85cD2A312f6B5f017D8AD5BD827F954C 0xC1aF21b9f237E3332843F63364A1599Aa722947c 0xf44B95991CaDD73ed769454A03b3820997f00873 0xDef1C0ded9bec7F1a1670819833240f027b25EfF 0x3d1357Caf05b9cAc4F939C34e0990FDbC25DB92f 0x200aFF2516B97d3be81c86B08EA417A40b9B43DF 2629743 100) --etherscan-api-key BASE_API_KEY 0x0FB4bc5053ae28369F38E3B5b73a3C3881713Ccb contracts/modules/credit/SecuredLine.sol:SecuredLine

# escrow
forge verify-contract 
--chain-id 8453 \
--watch \
--constructor-args $(cast abi-encode "constructor(uint32, address, address, address)” 0 0xb370B80f85cD2A312f6B5f017D8AD5BD827F954C 0x1529A4AaCc4f8F7Ed1708c1c7879536BeEd5a715 0xf44B95991CaDD73ed769454A03b3820997f00873) --etherscan-api-key BASE_API_KEY 0x200aFF2516B97d3be81c86B08EA417A40b9B43DF contracts/modules/escrow/Escrow.sol:Escrow

# spigot
forge verify-contract 
--chain-id 8453 \
--watch \
--constructor-args $(cast abi-encode "constructor(address, address)0x1529A4AaCc4f8F7Ed1708c1c7879536BeEd5a715 0xf44B95991CaDD73ed769454A03b3820997f00873) --etherscan-api-key BASE_API_KEY 0x3d1357Caf05b9cAc4F939C34e0990FDbC25DB92f contracts/modules/spigot/Spigot.sol:Spigot


forge verify-contract \
     --chain-id 42161 \
#     --watch \
#     --constructor-args $(cast abi-encode "constructor(address,address)" 0x06dae7Ba3958EF288adB0B9b3732eC204E48BC47 0xaf88d065e77c8cC2239327C5EDb3A432268e5831)  \
#     --rpc-url $BASE_RPC_URL --etherscan-api-key $BASE_API_KEY \
#     0x081B1f32434826f46652C0aAC20E1560aFC0Ce24 \
#     SimpleRevenueContract


# forge create --rpc-url $BASE_RPC_URL --private-key $BASE_PRIVATE_KEY --etherscan-api-key $BASE_API_KEY  contracts/modules/oracle/BaseOracle.sol:BaseOracle  --verify

# forge create --rpc-url $BASE_RPC_URL  --private-key $BASE_PRIVATE_KEY --etherscan-api-key $BASE_API_KEY  contracts/modules/oracle/PolygonOracle.sol:PolygonOracle  --verify