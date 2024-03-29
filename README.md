## Documentation Site

We have comprehensive docs on our site:
https://docs.creditcoop.xyz/developer-documentation/architecture

## Installing

We track remote remotes like Foundry and Chainlink via submodules so you will need to install those in addition to our repo itself

If you have forge installed already you can run `forge install`

Alternatively using  git when cloning you can run `git clone --recurse-submodules`
Or if you already have repo installed you can run `git pull --recurse-submodules`


## Git Hooks:

#### (post-checkout): Reinitialize git submodules when switching between branches
```
git submodule deinit --force .
git submodule update --init --recursive
```

If still faceing issues, try this command:
```
git reset HEAD <path-to-lib>
```


Also try updating foundry suite by running:

```
foundryup
```
## Deploying

### Testnet Deployments

We have deployed contracts to Gõrli testnet.
[All deployed contract addresses including libraries and mock contracts](https://near-diploma-a92.notion.site/Deployed-Verified-Contracts-4717a0e2b231459e891e7e4565ec4e81)

[List of tokens that are priced by our dummy oracle](https://near-diploma-a92.notion.site/Test-Tokens-10-17-2afd16dde17c45eeba14b780d58ba28b) that you can use for interacting with Line Of Credit and Escrow contracts (you can use any token for Spigot revenue as long as it can be traded to a whitelisted token)

### Mainnet Deploymetns

We have deployed 2 test versions of our contracts to Mainnet. You can find those contract address here: TODO

### Deploy Your Own

To deploy a LineFactory you must deploy ModuleFactory, Arbiter, and Oracle contracts as well as know what the [0x protocol ExchangeProxy](https://docs.0x.org/introduction/0x-cheat-sheet#exchange-proxy-addresses) address is for the network you are deploying on.

To deploy a SecuredLine you should call our [LineFactory](https://github.com/credit-cooperative/Line-of-Credit/blob/master/contracts/interfaces/ILineFactory.sol) contract so your Line will automatically be indexed by subgraphs and display on interfaces for lenders to send you offers. There are multiple functions to deploy lines depending on the granularaity and control you want for your terms and conditions.

## Testing

We use foundry for testing. Follow [installation guide](https://github.com/foundry-rs/foundry) on their repo.

Before running tests, make sure the foundry.toml file is correctly configured. Make sure it includes the following:

```
[profile.default]
src = 'contracts'
test = 'test'
script = 'scripts'
out = 'out'
libs = [

]
remappings = [
    "forge-std/=lib/forge-std/src/",
    "ds-test/=lib/forge-std/lib/ds-test/src/",
    "chainlink/=lib/chainlink/contracts/src/v0.8/",
    "openzeppelin/=lib/openzeppelin-contracts/contracts/"
]
libraries = []
```

Check the the .env file includes the following environment variables:

```
FOUNDRY_PROFILE=""

MAINNET_ETHERSCAN_API_KEY= <YOUR_KEY_HERE>
DEPLOYER_MAINNET_PRIVATE_KEY= <YOUR_KEY_HERE>
MAINNET_RPC_URL= <YOUR_RPC_URL_HERE>

GOERLI_RPC_URL= <YOUR_GOERLI_RPC_URL_HERE>
GOERLI_PRIVATE_KEY= <YOUR_GOERLI_PRIVATE_KEY_HERE>

LOCAL_RPC_URL='http://localhost:8545'
LOCAL_PRIVATE_KEY= <LOCAL_PRIVATE_KEY_HERE>
```

Then run `forge test`

Run all tests with maximum logging:
`forge test -vvv`

Test individual test files:
`forge test —match-path <filepath>`

Test individual tests:
`forge test —match-test <testname>`

Check test coverage:
`forge coverage`

## Deployment
For all deployments, the `deploy.sh` script can be modified to deploy all libraries and modules necessary to create Lines of Credit. To run the script, you will need the `jq` library which can be installed usng homebrew(mac) or apt-get(Windows). You can uncomment the command for your OS in the script to install automatically.

There are 4 variables that will need to be adjusted depening on if you are deploying to local, goerli or mainnet. RPC_URL, PRIVATE_KEY and the toml profile that the script will write the libraries to. These  variables are in `deploy.sh`. The 4th variable will be  in your `.env` file and is the FOUNDRY_PROFILE environment variable.

### Mainnet

Check Gas Costs:
```forge script --chain-id 1 --fork-url https://eth-mainnet.g.alchemy.com/v2/oUfrH5IYAmVc-_iljDTKdLZajyGpSNBz --etherscan-api-key UJ1WYIW6CDU4MZWS4HFJJX91AWK8KGCWGD contracts/scripts/MainnetDeploy.s.sol --with-gas-price 25000000000```

Deploy:
```forge script --chain-id 1 --fork-url https://eth-mainnet.g.alchemy.com/v2/oUfrH5IYAmVc-_iljDTKdLZajyGpSNBz --etherscan-api-key UJ1WYIW6CDU4MZWS4HFJJX91AWK8KGCWGD --verify --verifier-url https://api.etherscan.io/api --broadcast contracts/scripts/MainnetDeploy.s.sol --with-gas-price 27000000000 --resume```


### Mainnet Contract Verification

Module Factory:
```
forge verify-contract \
    --chain-id 1 \
    --watch \
    --etherscan-api-key UJ1WYIW6CDU4MZWS4HFJJX91AWK8KGCWGD \
    0x73cB72A7EfaDdD99cDd2d110e2F4B8b65BF3b812 \
    contracts/modules/factories/ModuleFactory.sol:ModuleFactory
```

LineLib:
```
forge verify-contract \
    --chain-id 1 \
    --watch \
    --etherscan-api-key UJ1WYIW6CDU4MZWS4HFJJX91AWK8KGCWGD \
    0x73cB72A7EfaDdD99cDd2d110e2F4B8b65BF3b812 \
    contracts/utils/LineLib.sol:LineLib
```

CreditLib:
```
forge verify-contract \
    --chain-id 1 \
    --watch \
    --etherscan-api-key UJ1WYIW6CDU4MZWS4HFJJX91AWK8KGCWGD \
    0x4dcA189D7FB51d9cc375E4d697e5800C5D21fF87 \
    contracts/utils/CreditLib.sol:CreditLib
```

EscrowLib:
```
forge verify-contract \
    --chain-id 1 \
    --watch \
    --etherscan-api-key UJ1WYIW6CDU4MZWS4HFJJX91AWK8KGCWGD \
    0x9ae9c76276e503105f20c8b452ccd0c4ee3b2df2 \
    contracts/utils/EscrowLib.sol:EscrowLib
```

CreditListLib:
```
forge verify-contract \
    --chain-id 1 \
    --watch \
    --etherscan-api-key UJ1WYIW6CDU4MZWS4HFJJX91AWK8KGCWGD \
    0x9cBe9741b3503a790E69e1587B5d51c0056154dc \
    contracts/utils/CreditListLib.sol:CreditListLib
```

SpigotedLineLib:
```
forge verify-contract \
    --chain-id 1 \
    --watch \
    --etherscan-api-key UJ1WYIW6CDU4MZWS4HFJJX91AWK8KGCWGD \
    0x274946031D204567281F7616718b4aBB940Ef784 \
    contracts/utils/SpigotedLineLib.sol:SpigotedLineLib
```

LineFactoryLib:
```
forge verify-contract \
    --chain-id 1 \
    --watch \
    --etherscan-api-key UJ1WYIW6CDU4MZWS4HFJJX91AWK8KGCWGD \
    0x2b721a999b83cbcc1DBD697A27199d5b4Be70102 \
    contracts/utils/LineFactoryLib.sol:LineFactoryLib
```

SpigotLib:
```
forge verify-contract \
    --chain-id 1 \
    --watch \
    --etherscan-api-key UJ1WYIW6CDU4MZWS4HFJJX91AWK8KGCWGD \
    0x05b4180e2EE77a04f3f0dC833E36b7d9f1141e02 \
    contracts/utils/SpigotLib.sol:SpigotLib
```



ModuleFactory
```
forge verify-contract \
    --chain-id 1 \
    --watch \
    --etherscan-api-key UJ1WYIW6CDU4MZWS4HFJJX91AWK8KGCWGD \
    0x2E18fA4917f9f2A35De0313314762A4435291254 \
    contracts/modules/factories/ModuleFactory.sol:ModuleFactory
```

LineFactory
```
forge verify-contract \
    --chain-id 1 \
    --watch \
    --constructor-args $(cast abi-encode "constructor(address,address,address,address)" 0x2E18fA4917f9f2A35De0313314762A4435291254 0xeb0566b1EF38B95da2ed631eBB8114f3ac7b9a8a 0x5a4AAF300473eaF8A9763318e7F30FA8a3f5Dd48 0xDef1C0ded9bec7F1a1670819833240f027b25EfF)  \
    --etherscan-api-key UJ1WYIW6CDU4MZWS4HFJJX91AWK8KGCWGD \
    0x07d5c33a3AFa24A25163D2afDD663BAb4C17b6d5 \
    contracts/modules/factories/LineFactory.sol:LineFactory
```

SecuredLine
```
forge verify-contract \
    --chain-id 1 \
    --watch \
    --constructor-args $(cast abi-encode "constructor(address,address,address,address,address,address,uint256,uint8)" 0x5a4AAF300473eaF8A9763318e7F30FA8a3f5Dd48 0xeb0566b1EF38B95da2ed631eBB8114f3ac7b9a8a 0x7ec0d4fdda3c194408d59241d27ce0d2016d890f 0xDef1C0ded9bec7F1a1670819833240f027b25EfF 0xCE605b2E2444F13f753951Ec0a66e2a1DfaB0468 0x054Cf97Aa0D4D018dD0f8bbDF5f9382cD6786fa2 8094536 100)  \
    --etherscan-api-key UJ1WYIW6CDU4MZWS4HFJJX91AWK8KGCWGD \
    0xa0bf40bA76F8Fe562c15F029B2e50Fe80b0d600d \
    contracts/modules/credit/SecuredLine.sol:SecuredLine
```


Spigot
```
forge verify-contract \
    --chain-id 1 \
    --watch \
    --constructor-args $(cast abi-encode "constructor(address,address)" 0x07d5c33a3AFa24A25163D2afDD663BAb4C17b6d5 0x7ec0d4fdda3c194408d59241d27ce0d2016d890f)  \
    --etherscan-api-key UJ1WYIW6CDU4MZWS4HFJJX91AWK8KGCWGD \
    0xCE605b2E2444F13f753951Ec0a66e2a1DfaB0468 \
    contracts/modules/spigot/Spigot.sol:Spigot
```

Escrow
```
forge verify-contract \
    --chain-id 1 \
    --watch \
    --constructor-args $(cast abi-encode "constructor(uint32,address,address,address)" 1250 0x5a4AAF300473eaF8A9763318e7F30FA8a3f5Dd48 0x07d5c33a3AFa24A25163D2afDD663BAb4C17b6d5 0x7ec0d4fdda3c194408d59241d27ce0d2016d890f)  \
    --etherscan-api-key UJ1WYIW6CDU4MZWS4HFJJX91AWK8KGCWGD \
    0x054Cf97Aa0D4D018dD0f8bbDF5f9382cD6786fa2 \
    contracts/modules/escrow/Escrow.sol:Escrow
```

### Local

### Goerli
