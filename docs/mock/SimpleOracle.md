# Solidity API

## SimpleOracle

### prices

```solidity
mapping(address => int256) prices
```

### constructor

```solidity
constructor(address _supportedToken1, address _supportedToken2) public
```

### init

```solidity
function init() external pure returns (bool)
```

### changePrice

```solidity
function changePrice(address token, int256 newPrice) external
```

### getLatestAnswer

```solidity
function getLatestAnswer(address token) external returns (int256)
```

current price for token asset. denominated in USD

### healthcheck

```solidity
function healthcheck() external pure returns (enum LineLib.STATUS status)
```

### line

```solidity
function line() external pure returns (address)
```

