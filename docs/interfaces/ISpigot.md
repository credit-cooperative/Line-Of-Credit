# Solidity API

## ISpigot

### Setting

```solidity
struct Setting {
  address token;
  uint8 ownerSplit;
  bytes4 claimFunction;
  bytes4 transferOwnerFunction;
}
```

### AddSpigot

```solidity
event AddSpigot(address revenueContract, address token, uint256 ownerSplit)
```

### RemoveSpigot

```solidity
event RemoveSpigot(address revenueContract, address token)
```

### UpdateWhitelistFunction

```solidity
event UpdateWhitelistFunction(bytes4 func, bool allowed)
```

### UpdateOwnerSplit

```solidity
event UpdateOwnerSplit(address revenueContract, uint8 split)
```

### ClaimRevenue

```solidity
event ClaimRevenue(address token, uint256 amount, uint256 escrowed, address revenueContract)
```

### ClaimEscrow

```solidity
event ClaimEscrow(address token, uint256 amount, address owner)
```

### UpdateOwner

```solidity
event UpdateOwner(address newOwner)
```

### UpdateOperator

```solidity
event UpdateOperator(address newOperator)
```

### UpdateTreasury

```solidity
event UpdateTreasury(address newTreasury)
```

### BadFunction

```solidity
error BadFunction()
```

### ClaimFailed

```solidity
error ClaimFailed()
```

### NoRevenue

```solidity
error NoRevenue()
```

### UnclaimedRevenue

```solidity
error UnclaimedRevenue()
```

### CallerAccessDenied

```solidity
error CallerAccessDenied()
```

### BadSetting

```solidity
error BadSetting()
```

### claimRevenue

```solidity
function claimRevenue(address revenueContract, bytes data) external returns (uint256 claimed)
```

### operate

```solidity
function operate(address revenueContract, bytes data) external returns (bool)
```

### claimEscrow

```solidity
function claimEscrow(address token) external returns (uint256 claimed)
```

### addSpigot

```solidity
function addSpigot(address revenueContract, struct ISpigot.Setting setting) external returns (bool)
```

### removeSpigot

```solidity
function removeSpigot(address revenueContract) external returns (bool)
```

### updateOwnerSplit

```solidity
function updateOwnerSplit(address revenueContract, uint8 ownerSplit) external returns (bool)
```

### updateOwner

```solidity
function updateOwner(address newOwner) external returns (bool)
```

### updateOperator

```solidity
function updateOperator(address newOperator) external returns (bool)
```

### updateTreasury

```solidity
function updateTreasury(address newTreasury) external returns (bool)
```

### updateWhitelistedFunction

```solidity
function updateWhitelistedFunction(bytes4 func, bool allowed) external returns (bool)
```

### owner

```solidity
function owner() external view returns (address)
```

### treasury

```solidity
function treasury() external view returns (address)
```

### operator

```solidity
function operator() external view returns (address)
```

### isWhitelisted

```solidity
function isWhitelisted(bytes4 func) external view returns (bool)
```

### getEscrowed

```solidity
function getEscrowed(address token) external view returns (uint256)
```

### getSetting

```solidity
function getSetting(address revenueContract) external view returns (address token, uint8 split, bytes4 claimFunc, bytes4 transferFunc)
```

