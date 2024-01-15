## Installing

We track remote remotes like Foundry and Chainlink via submodules so you will need to install those in addition to our repo itself

If you have forge installed already you can run `forge install`

If you done,  follow [installation guide](https://github.com/foundry-rs/foundry) on their repo.

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

Then run `forge test --match-path test_operate_univ3 -vv` to see an example of the spigot owning and managing a uniswap v3 position.