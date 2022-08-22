# Solidity API

## ISpigotedLine

### RevenuePayment

```solidity
event RevenuePayment(address token, uint256 amount)
```

### useAndRepay

```solidity
function useAndRepay(uint256 amount) external returns (bool)
```

### claimAndRepay

```solidity
function claimAndRepay(address token, bytes zeroExTradeData) external returns (uint256)
```

### claimAndTrade

```solidity
function claimAndTrade(address token, bytes zeroExTradeData) external returns (uint256 tokensBought)
```

### addSpigot

```solidity
function addSpigot(address revenueContract, struct ISpigot.Setting setting) external returns (bool)
```

### updateWhitelist

```solidity
function updateWhitelist(bytes4 func, bool allowed) external returns (bool)
```

### updateOwnerSplit

```solidity
function updateOwnerSplit(address revenueContract) external returns (bool)
```

### releaseSpigot

```solidity
function releaseSpigot() external returns (bool)
```

### sweep

```solidity
function sweep(address to, address token) external returns (uint256)
```

### unused

```solidity
function unused(address token) external returns (uint256)
```

