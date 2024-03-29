# Steps to Reproduce Contracts (Sepolia)

### 1. Deploy Libs
`./deploy_libs_sepolia.sh`

### 2. (Optional) Deploy Test Tokens and Deploy SimpleOracle
`./deploy_test_infra_sepolia.sh`

### 3. Deploy Factories
`./deploy_factory_sepolia.sh`

### 4. Deploy Lines from Factory
Call `deploySecuredLineWithConfig` from the `LineFactory` contract with desired parameters.

### 5. Verify Line Factory, SecuredLine, Escrow, and Spigot
Set `FOUNDRY_PROFILE=sepolia`

```forge verify-contract \
    --chain-id 11155111 \
    --watch \
    --constructor-args $(cast abi-encode "constructor(address,address,address,address,address,address,uint256,uint8)" 0x274946031D204567281F7616718b4aBB940Ef784 0x06dae7Ba3958EF288adB0B9b3732eC204E48BC47 0x06dae7Ba3958EF288adB0B9b3732eC204E48BC47 0xDef1C0ded9bec7F1a1670819833240f027b25EfF 0x565D2B43365f8A5bfB472b5660B7010671859679 0x4860d22833657dce1c27a3A30fa315E1B1B4B8cB  2592000 100)  \
    --etherscan-api-key UJ1WYIW6CDU4MZWS4HFJJX91AWK8KGCWGD \
    0xc3Ce4BFfE157dD3BeE61a49217214319ba910965 \
    contracts/modules/credit/SecuredLine.sol:SecuredLine```