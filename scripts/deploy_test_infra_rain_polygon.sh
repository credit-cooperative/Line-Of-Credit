#!/bin/bash
source ../.env

###  Controller ###

# Constructor Args: admin, treasury, owner
forge create --rpc-url $POLYGON_RPC_URL --constructor-args 0xf44B95991CaDD73ed769454A03b3820997f00873 0xf44B95991CaDD73ed769454A03b3820997f00873 0xf44B95991CaDD73ed769454A03b3820997f00873 \
--private-key $POLYGON_PRIVATE_KEY --etherscan-api-key $POLYGON_ETHERSCAN_API_KEY \
contracts/mock/Rain/MockRainCollateralController.sol:MockRainCollateralController --verify


### Factory ###

# Constructor Args: controller
forge create --rpc-url $POLYGON_RPC_URL --constructor-args 0x3db20Cb84375EAB0067CD90b59B0301276e04b8c \
--private-key $POLYGON_PRIVATE_KEY --etherscan-api-key $POLYGON_ETHERSCAN_API_KEY \
contracts/mock/Rain/MockRainCollateralFactory.sol:MockRainCollateralFactory  --verify


### Collateral ###

# Constructor Args: owner, factory
forge create --rpc-url $POLYGON_RPC_URL --constructor-args 0x97fCbc96ed23e4E9F0714008C8f137D57B4d6C97 0x4955634FFDac4c88BfBA71D7093FB1b9259a9647 \
--private-key $POLYGON_PRIVATE_KEY --etherscan-api-key $POLYGON_ETHERSCAN_API_KEY \
contracts/mock/Rain/MockRainCollateral.sol:MockRainCollateral --verify



# DEPLOY ORACLE ###

forge create --rpc-url $POLYGON_RPC_URL --constructor-args 0xb7c75c110467B1c5dc1af60D0A3C245eD0b883f9 \
--private-key $POLYGON_PRIVATE_KEY --etherscan-api-key $POLYGON_ETHERSCAN_API_KEY  \
contracts/modules/oracle/Oracle.sol:Oracle  --verify

forge create --rpc-url $POLYGON_RPC_URL  --private-key $POLYGON_PRIVATE_KEY \
--etherscan-api-key $POLYGON_ETHERSCAN_API_KEY  contracts/modules/oracle/PolygonOracle.sol:PolygonOracle  --verify