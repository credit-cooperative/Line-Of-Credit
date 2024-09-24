#!/bin/bash

# make sure the libraries array in the toml file looks like this 'libraries = []' with no spaces inside the brackets

# brew install jq

# apt-get jq

### DEPLOY LIBS ###

source ../.env

LineLib=$(forge create --rpc-url $PLUME_DEVNET_RPC_URL --private-key $PlUME_DEVNET_PRIVATE_KEY --etherscan-api-key $PLUME_ETHSERSCAN_API_KEY  --optimizer-runs 20000 contracts/utils/LineLib.sol:LineLib --json --verify)
LineLibAddress=$(echo "$LineLib" | jq -r '.deployedTo')
LineLibEntry="contracts\/utils\/LineLib.sol:LineLib:$LineLibAddress"

sed -i'' -e '/\[profile\.plumedevnet\]/,/^\[/s/^libraries = \[.*\]/libraries = \["'$LineLibEntry'"\]/' ../foundry.toml


CreditLib=$(forge create --rpc-url $PLUME_DEVNET_RPC_URL --private-key $PlUME_DEVNET_PRIVATE_KEY --etherscan-api-key $PLUME_ETHSERSCAN_API_KEY --optimizer-runs 200 contracts/utils/CreditLib.sol:CreditLib --verify --json)
CreditLibAddress=$(echo "$CreditLib" | jq -r '.deployedTo')
CreditLibEntry="contracts\/utils\/CreditLib.sol:CreditLib:$CreditLibAddress"

sed -i'' -e '/\[profile\.plumedevnet\]/,/^\[/s/^libraries = \["'$LineLibEntry'"\]/libraries = \["'$LineLibEntry'","'$CreditLibEntry'"\]/' ../foundry.toml

CreditListLib=$(forge create --rpc-url $PLUME_DEVNET_RPC_URL --private-key $PlUME_DEVNET_PRIVATE_KEY --etherscan-api-key $PLUME_ETHSERSCAN_API_KEY --optimizer-runs 200 contracts/utils/CreditListLib.sol:CreditListLib --verify --json)
CreditListLibAddress=$(echo "$CreditListLib" | jq -r '.deployedTo')
CreditListLibEntry="contracts\/utils\/CreditListLib.sol:CreditListLib:$CreditListLibAddress"

sed -i'' -e '/\[profile\.plumedevnet\]/,/^\[/s/^libraries = \["'$LineLibEntry'","'$CreditLibEntry'"\]/libraries = \["'$LineLibEntry'","'$CreditLibEntry'","'$CreditListLibEntry'"\]/' ../foundry.toml

SpigotLib=$(forge create --rpc-url $PLUME_DEVNET_RPC_URL --private-key $PlUME_DEVNET_PRIVATE_KEY --etherscan-api-key $PLUME_ETHSERSCAN_API_KEY --optimizer-runs 200 contracts/utils/SpigotLib.sol:SpigotLib --verify --json)
SpigotLibAddress=$(echo "$SpigotLib" | jq -r '.deployedTo')
SpigotLibEntry="contracts\/utils\/SpigotLib.sol:SpigotLib:$SpigotLibAddress"

sed -i'' -e '/\[profile\.plumedevnet\]/,/^\[/s/^libraries = \["'$LineLibEntry'","'$CreditLibEntry'","'$CreditListLibEntry'"\]/libraries = \["'$LineLibEntry'","'$CreditLibEntry'","'$CreditListLibEntry'","'$SpigotLibEntry'"\]/' ../foundry.toml

EscrowLib=$(forge create --rpc-url $PLUME_DEVNET_RPC_URL --private-key $PlUME_DEVNET_PRIVATE_KEY --etherscan-api-key $PLUME_ETHSERSCAN_API_KEY --optimizer-runs 200 contracts/utils/EscrowLib.sol:EscrowLib --verify --json)
EscrowLibAddress=$(echo "$EscrowLib" | jq -r '.deployedTo')
EscrowLibEntry="contracts\/utils\/EscrowLib.sol:EscrowLib:$EscrowLibAddress"

sed -i'' -e '/\[profile\.plumedevnet\]/,/^\[/s/^libraries = \["'$LineLibEntry'","'$CreditLibEntry'","'$CreditListLibEntry'","'$SpigotLibEntry'"\]/libraries = \["'$LineLibEntry'","'$CreditLibEntry'","'$CreditListLibEntry'","'$SpigotLibEntry'","'$EscrowLibEntry'"\]/' ../foundry.toml

SpigotedLineLib=$(forge create --rpc-url $PLUME_DEVNET_RPC_URL --private-key $PlUME_DEVNET_PRIVATE_KEY --etherscan-api-key $PLUME_ETHSERSCAN_API_KEY --optimizer-runs 200 contracts/utils/SpigotedLineLib.sol:SpigotedLineLib --verify --json)
SpigotedLineLibAddress=$(echo "$SpigotedLineLib" | jq -r '.deployedTo')
SpigotedLineLibEntry="contracts\/utils\/SpigotedLineLib.sol:SpigotedLineLib:$SpigotedLineLibAddress"

sed -i'' -e '/\[profile\.plumedevnet\]/,/^\[/s/^libraries = \["'$LineLibEntry'","'$CreditLibEntry'","'$CreditListLibEntry'","'$SpigotLibEntry'","'$EscrowLibEntry'"\]/libraries = \["'$LineLibEntry'","'$CreditLibEntry'","'$CreditListLibEntry'","'$SpigotLibEntry'","'$EscrowLibEntry'","'$SpigotedLineLibEntry'"\]/' ../foundry.toml

LineFactoryLib=$(forge create --rpc-url $PLUME_DEVNET_RPC_URL --private-key $PlUME_DEVNET_PRIVATE_KEY --etherscan-api-key $PLUME_ETHSERSCAN_API_KEY --optimizer-runs 200 contracts/utils/LineFactoryLib.sol:LineFactoryLib --verify --json)
LineFactoryLibAddress=$(echo "$LineFactoryLib" | jq -r '.deployedTo')
LineFactoryLibEntry="contracts\/utils\/LineFactoryLib.sol:LineFactoryLib:$LineFactoryLibAddress"

sed -i'' -e '/\[profile\.plumedevnet\]/,/^\[/s/^libraries = \["'$LineLibEntry'","'$CreditLibEntry'","'$CreditListLibEntry'","'$SpigotLibEntry'","'$EscrowLibEntry'","'$SpigotedLineLibEntry'"\]/libraries = \["'$LineLibEntry'","'$CreditLibEntry'","'$CreditListLibEntry'","'$SpigotLibEntry'","'$EscrowLibEntry'","'$SpigotedLineLibEntry'","'$LineFactoryLibEntry'"\]/' ../foundry.toml


forge verify-contract 0x33a321Ff02578190BE33b7c7F0da59d616a1365d contracts/utils/LineLib.sol:LineLib \
  --rpc-url https://devnet-rpc.plumenetwork.xyz \
  --verifier oklink --verifier-url \
  https://www.oklink.com/api/v5/explorer/contract/verify-source-code-plugin/PLUME_DEVNET \
  --api-key 91181d88-9dbe-4eb3-b228-81bcee2d118a    

  forge verify-contract 0x71122123187AE77D8B6D0DCD7FfdEa3fF90aDff1 contracts/utils/CreditLib.sol:CreditLib \
  --rpc-url https://devnet-rpc.plumenetwork.xyz \
  --verifier oklink --verifier-url \
  https://www.oklink.com/api/v5/explorer/contract/verify-source-code-plugin/PLUME_DEVNET \
  --api-key 91181d88-9dbe-4eb3-b228-81bcee2d118a   

  forge verify-contract 0x1086847B9c1C19cEEE43885d3B3f9d94DDcd1f6C contracts/utils/CreditListLib.sol:CreditListLib \
  --rpc-url https://devnet-rpc.plumenetwork.xyz \
  --verifier oklink --verifier-url \
  https://www.oklink.com/api/v5/explorer/contract/verify-source-code-plugin/PLUME_DEVNET \
  --api-key 91181d88-9dbe-4eb3-b228-81bcee2d118a 

  forge verify-contract 0xAC2ff4c766730b8c4D31DbD5858f32448f89e0f0 contracts/utils/SpigotLib.sol:SpigotLib \
  --rpc-url https://devnet-rpc.plumenetwork.xyz \
  --verifier oklink --verifier-url \
  https://www.oklink.com/api/v5/explorer/contract/verify-source-code-plugin/PLUME_DEVNET \
  --api-key 91181d88-9dbe-4eb3-b228-81bcee2d118a  

  forge verify-contract 0x03f92Ae5Ae26C299ed70B9466b7dc56Fa6515526 contracts/utils/EscrowLib.sol:EscrowLib \
  --rpc-url https://devnet-rpc.plumenetwork.xyz \
  --verifier oklink --verifier-url \
  https://www.oklink.com/api/v5/explorer/contract/verify-source-code-plugin/PLUME_DEVNET \
  --api-key 91181d88-9dbe-4eb3-b228-81bcee2d118a    

  forge verify-contract 0x159a92130798e8F3d1a9F4165E870F1465AE5338 contracts/utils/SpigotedLineLib.sol:SpigotedLineLib \
  --rpc-url https://devnet-rpc.plumenetwork.xyz \
  --verifier oklink --verifier-url \
  https://www.oklink.com/api/v5/explorer/contract/verify-source-code-plugin/PLUME_DEVNET \
  --api-key 91181d88-9dbe-4eb3-b228-81bcee2d118a   

  forge verify-contract 0x202AA2Cd166B7aa6EaA6dfC42e60f899a9bEEF14 contracts/utils/LineFactoryLib.sol:LineFactoryLib \
  --rpc-url https://devnet-rpc.plumenetwork.xyz \
  --verifier oklink --verifier-url \
  https://www.oklink.com/api/v5/explorer/contract/verify-source-code-plugin/PLUME_DEVNET \
  --api-key 91181d88-9dbe-4eb3-b228-81bcee2d118a 