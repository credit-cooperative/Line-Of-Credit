#!/bin/bash
source .env

###  Controller ###

# Constructor Args: admin, treasury, owner
forge create --rpc-url $POLYGON_RPC_URL --constructor-args 0x06dae7Ba3958EF288adB0B9b3732eC204E48BC47 0x06dae7Ba3958EF288adB0B9b3732eC204E48BC47 0x06dae7Ba3958EF288adB0B9b3732eC204E48BC47 \
--private-key $POLYGON_PRIVATE_KEY --etherscan-api-key $POLYGON_ETHERSCAN_API_KEY \
contracts/mock/Rain/MockRainCollateralController.sol:MockRainCollateralController --verify


### Factory ###

# Constructor Args: initialOwner
forge create --rpc-url $POLYGON_RPC_URL --constructor-args 0x06dae7Ba3958EF288adB0B9b3732eC204E48BC47 \
--private-key $POLYGON_PRIVATE_KEY --etherscan-api-key $POLYGON_ETHERSCAN_API_KEY \
contracts/mock/Rain/MockRainCollateralFactory.sol:MockRainCollateralFactory  --verify

### Beacon ###

# Constructor Args: initialOwner
forge create --rpc-url $POLYGON_RPC_URL --constructor-args 0x06dae7Ba3958EF288adB0B9b3732eC204E48BC47 \
--private-key $POLYGON_PRIVATE_KEY --etherscan-api-key $POLYGON_ETHERSCAN_API_KEY \
contracts/mock/Rain/MockRainBeacon.sol:MockRainBeacon  --verify


### Collateral ###

# Constructor Args: owner, factory
forge create --rpc-url $POLYGON_RPC_URL --constructor-args 0x06dae7Ba3958EF288adB0B9b3732eC204E48BC47 0xb2a475abeeec287fdfda37f6977803989e388f53 \
--private-key $POLYGON_PRIVATE_KEY --etherscan-api-key $POLYGON_ETHERSCAN_API_KEY \
contracts/mock/Rain/MockRainCollateral.sol:MockRainCollateral --verify

### TransparentUpgradeableProxy ###

# Constructor Args: address _logic, address initialOwner, bytes memory _data
forge create --rpc-url $POLYGON_RPC_URL --constructor-args 0x55e3acf90ec2df0603ffbc7c8c4a4e1e402c4493 0x06dae7Ba3958EF288adB0B9b3732eC204E48BC47 "" \
--private-key $POLYGON_PRIVATE_KEY --etherscan-api-key $POLYGON_ETHERSCAN_API_KEY \
contracts/mock/proxy/TransparentUpgradeableProxy.sol:TransparentUpgradeableProxy  --verify

# DEPLOY ORACLE ###

forge create --rpc-url $POLYGON_RPC_URL --constructor-args 0xb7c75c110467B1c5dc1af60D0A3C245eD0b883f9 \
--private-key $POLYGON_PRIVATE_KEY --etherscan-api-key $POLYGON_ETHERSCAN_API_KEY  \
contracts/modules/oracle/Oracle.sol:Oracle  --verify

forge create --rpc-url $POLYGON_RPC_URL  --private-key $POLYGON_PRIVATE_KEY \
--etherscan-api-key $POLYGON_ETHERSCAN_API_KEY  contracts/modules/oracle/PolygonOracle.sol:PolygonOracle  --verify