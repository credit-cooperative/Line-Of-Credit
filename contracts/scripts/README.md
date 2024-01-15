# Purpose: Deployment Script for Simulating Library and Factory Deployment

## Overview
This pull request introduces a new script file designed to simulate the deployment of all necessary libraries and contracts for setting up a line of credit from a factory contract. The primary purpose of this script is to simulate the gas costs associated with the deployment process.

## Features
- **Script Creation**: A new script file is added to handle the deployment of libraries and contracts efficiently.
- **Gas Cost Simulation**: Enables users to simulate gas costs for deploying line of credit contracts.

## Usage Instructions
1. **Start Local Blockchain**:
    - Run the following command to start a local blockchain with the London hardfork:
      ```bash
      anvil --hardfork london
      ```

2. **Environment Setup**:
    - Set the `FOUNDRY_PROFILE` environment variable to `local`.
    - Update the `.env` file with your local private key and RPC URL:
      ```
      LOCAL_PRIVATE_KEY=<your local private key from the anvil instance>
      LOCAL_RPC_URL="http://localhost:8545"
      ```

3. **Deploy Script**:
    - Open a separate terminal window.
    - Navigate to the correct directory:
      ```bash
      cd path/to/directory
      ```
    - Source the environment variables:
      ```bash
      source .env
      ```
    - Execute the deployment script:
      ```bash
      forge script contracts/scripts/LibDeploy.s.sol:LibDeploy --rpc-url $LOCAL_RPC_URL --broadcast -vvvv
      ```
    - This command will print out a detailed list of the gas costs for each library.

## Notes
- This script is intended for simulation purposes only and is not recommended for production use.