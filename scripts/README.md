# Steps to Reproduce Contracts (Sepolia)

### 1. Deploy Libs
`./deploy_libs_sepolia.sh`

### 2. (Optional) Deploy Test Tokens and Deploy SimpleOracle
`./deploy_test_infra_sepolia.sh`

### 3. Deploy Factories
`./deploy_factory_sepolia.sh`

### 4. Deploy Lines from Factory
Call `deploySecuredLineWithConfig` from the `LineFactory` contract with desired parameters.
