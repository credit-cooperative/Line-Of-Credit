#!/bin/bash

# make sure the libraries array in the toml file looks like this 'libraries = []' with no spaces inside the brackets

# brew install jq

# apt-get jq

### DEPLOY LIBS ###

source ../.env

LineLib=$(forge create --rpc-url $SEPOLIA_RPC_URL --private-key $SEPOLIA_PRIVATE_KEY --etherscan-api-key $SEPOLIA_ETHERSCAN_API_KEY  --optimizer-runs 20000 contracts/utils/LineLib.sol:LineLib --json --verify)
LineLibAddress=$(echo "$LineLib" | jq -r '.deployedTo')
LineLibEntry="contracts\/utils\/LineLib.sol:LineLib:$LineLibAddress"

sed -i '' '/\[profile\.sepolia\]/,/^\[/s/^libraries = \[.*\]/libraries = \["'$LineLibEntry'"\]/' ../foundry.toml

# CreditLib=$(forge create --rpc-url $SEPOLIA_RPC_URL --private-key $SEPOLIA_PRIVATE_KEY --etherscan-api-key $SEPOLIA_ETHERSCAN_API_KEY --optimizer-runs 200 contracts/utils/CreditLib.sol:CreditLib --verify --json)
# CreditLibAddress=$(echo "$CreditLib" | jq -r '.deployedTo')
# CreditLibEntry="contracts\/utils\/CreditLib.sol:CreditLib:$CreditLibAddress"

# sed -i '' '/\[profile\.sepolia\]/,/^\[/s/^libraries = \["'$LineLibEntry'"\]/libraries = \["'$LineLibEntry'","'$CreditLibEntry'"\]/' ../foundry.toml

# CreditListLib=$(forge create --rpc-url $SEPOLIA_RPC_URL --private-key $SEPOLIA_PRIVATE_KEY --etherscan-api-key $SEPOLIA_ETHERSCAN_API_KEY --optimizer-runs 200 contracts/utils/CreditListLib.sol:CreditListLib --verify --json)
# CreditListLibAddress=$(echo "$CreditListLib" | jq -r '.deployedTo')
# CreditListLibEntry="contracts\/utils\/CreditListLib.sol:CreditListLib:$CreditListLibAddress"

# sed -i '' '/\[profile\.sepolia\]/,/^\[/s/^libraries = \["'$LineLibEntry'","'$CreditLibEntry'"\]/libraries = \["'$LineLibEntry'","'$CreditLibEntry'","'$CreditListLibEntry'"\]/' ../foundry.toml

# SpigotLib=$(forge create --rpc-url $SEPOLIA_RPC_URL --private-key $SEPOLIA_PRIVATE_KEY --etherscan-api-key $SEPOLIA_ETHERSCAN_API_KEY --optimizer-runs 200 contracts/utils/SpigotLib.sol:SpigotLib --verify --json)
# SpigotLibAddress=$(echo "$SpigotLib" | jq -r '.deployedTo')
# SpigotLibEntry="contracts\/utils\/SpigotLib.sol:SpigotLib:$SpigotLibAddress"

# sed -i '' '/\[profile\.sepolia\]/,/^\[/s/^libraries = \["'$LineLibEntry'","'$CreditLibEntry'","'$CreditListLibEntry'"\]/libraries = \["'$LineLibEntry'","'$CreditLibEntry'","'$CreditListLibEntry'","'$SpigotLibEntry'"\]/' ../foundry.toml

# EscrowLib=$(forge create --rpc-url $SEPOLIA_RPC_URL --private-key $SEPOLIA_PRIVATE_KEY --etherscan-api-key $SEPOLIA_ETHERSCAN_API_KEY --optimizer-runs 200 contracts/utils/EscrowLib.sol:EscrowLib --verify --json)
# EscrowLibAddress=$(echo "$EscrowLib" | jq -r '.deployedTo')
# EscrowLibEntry="contracts\/utils\/EscrowLib.sol:EscrowLib:$EscrowLibAddress"

# sed -i '' '/\[profile\.sepolia\]/,/^\[/s/^libraries = \["'$LineLibEntry'","'$CreditLibEntry'","'$CreditListLibEntry'","'$SpigotLibEntry'"\]/libraries = \["'$LineLibEntry'","'$CreditLibEntry'","'$CreditListLibEntry'","'$SpigotLibEntry'","'$EscrowLibEntry'"\]/' ../foundry.toml

# SpigotedLineLib=$(forge create --rpc-url $SEPOLIA_RPC_URL --private-key $SEPOLIA_PRIVATE_KEY --etherscan-api-key $SEPOLIA_ETHERSCAN_API_KEY --optimizer-runs 200 contracts/utils/SpigotedLineLib.sol:SpigotedLineLib --verify --json)
# SpigotedLineLibAddress=$(echo "$SpigotedLineLib" | jq -r '.deployedTo')
# SpigotedLineLibEntry="contracts\/utils\/SpigotedLineLib.sol:SpigotedLineLib:$SpigotedLineLibAddress"

# sed -i '' '/\[profile\.sepolia\]/,/^\[/s/^libraries = \["'$LineLibEntry'","'$CreditLibEntry'","'$CreditListLibEntry'","'$SpigotLibEntry'","'$EscrowLibEntry'"\]/libraries = \["'$LineLibEntry'","'$CreditLibEntry'","'$CreditListLibEntry'","'$SpigotLibEntry'","'$EscrowLibEntry'","'$SpigotedLineLibEntry'"\]/' ../foundry.toml

# LineFactoryLib=$(forge create --rpc-url $SEPOLIA_RPC_URL --private-key $SEPOLIA_PRIVATE_KEY --etherscan-api-key $SEPOLIA_ETHERSCAN_API_KEY --optimizer-runs 200 contracts/utils/LineFactoryLib.sol:LineFactoryLib --verify --json)
# LineFactoryLibAddress=$(echo "$LineFactoryLib" | jq -r '.deployedTo')
# LineFactoryLibEntry="contracts\/utils\/LineFactoryLib.sol:LineFactoryLib:$LineFactoryLibAddress"

# sed -i '' '/\[profile\.sepolia\]/,/^\[/s/^libraries = \["'$LineLibEntry'","'$CreditLibEntry'","'$CreditListLibEntry'","'$SpigotLibEntry'","'$EscrowLibEntry'","'$SpigotedLineLibEntry'"\]/libraries = \["'$LineLibEntry'","'$CreditLibEntry'","'$CreditListLibEntry'","'$SpigotLibEntry'","'$EscrowLibEntry'","'$SpigotedLineLibEntry'","'$LineFactoryLibEntry'"\]/' ../foundry.toml
