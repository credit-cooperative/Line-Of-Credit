# Solidity API

## LineLib

Core logic and variables to be reused across all Debt DAO Marketplace lines

### TransferFailed

```solidity
error TransferFailed()
```

### BadToken

```solidity
error BadToken()
```

### STATUS

```solidity
enum STATUS {
  UNINITIALIZED,
  INITIALIZED,
  ACTIVE,
  UNDERCOLLATERALIZED,
  LIQUIDATABLE,
  DELINQUENT,
  LIQUIDATING,
  OVERDRAWN,
  DEFAULT,
  ARBITRATION,
  REPAID,
  INSOLVENT
}
```

### sendOutTokenOrETH

```solidity
function sendOutTokenOrETH(address token, address receiver, uint256 amount) external returns (bool)
```

- Send ETH or ERC20 token from this contract to an external contract

| Name | Type | Description |
| ---- | ---- | ----------- |
| token | address | - address of token to send out. Denominations.ETH for raw ETH |
| receiver | address | - address to send tokens to |
| amount | uint256 | - amount of tokens to send |

### receiveTokenOrETH

```solidity
function receiveTokenOrETH(address token, address sender, uint256 amount) external returns (bool)
```

- Send ETH or ERC20 token from this contract to an external contract

| Name | Type | Description |
| ---- | ---- | ----------- |
| token | address | - address of token to send out. Denominations.ETH for raw ETH |
| sender | address | - address that is giving us tokens/ETH |
| amount | uint256 | - amount of tokens to send |

### getBalance

```solidity
function getBalance(address token) external view returns (uint256)
```

- Helper function to get current balance of this contract for ERC20 or ETH

| Name | Type | Description |
| ---- | ---- | ----------- |
| token | address | - address of token to check. Denominations.ETH for raw ETH |

