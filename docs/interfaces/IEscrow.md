# Solidity API

## IEscrowState

## IEscrow

### Deposit

```solidity
struct Deposit {
  uint256 amount;
  bool isERC4626;
  address asset;
  uint8 assetDecimals;
}
```

### AddCollateral

```solidity
event AddCollateral(address token, uint256 amount)
```

### RemoveCollateral

```solidity
event RemoveCollateral(address token, uint256 amount)
```

### EnableCollateral

```solidity
event EnableCollateral(address token)
```

### Liquidate

```solidity
event Liquidate(address token, uint256 amount)
```

### InvalidCollateral

```solidity
error InvalidCollateral()
```

### CallerAccessDenied

```solidity
error CallerAccessDenied()
```

### UnderCollateralized

```solidity
error UnderCollateralized()
```

### NotLiquidatable

```solidity
error NotLiquidatable()
```

### line

```solidity
function line() external returns (address)
```

### oracle

```solidity
function oracle() external returns (address)
```

### borrower

```solidity
function borrower() external returns (address)
```

### minimumCollateralRatio

```solidity
function minimumCollateralRatio() external returns (uint256)
```

### isLiquidatable

```solidity
function isLiquidatable() external returns (bool)
```

### updateLine

```solidity
function updateLine(address line_) external returns (bool)
```

### getCollateralRatio

```solidity
function getCollateralRatio() external returns (uint256)
```

### getCollateralValue

```solidity
function getCollateralValue() external returns (uint256)
```

### enableCollateral

```solidity
function enableCollateral(address token) external returns (bool)
```

### addCollateral

```solidity
function addCollateral(uint256 amount, address token) external returns (uint256)
```

### releaseCollateral

```solidity
function releaseCollateral(uint256 amount, address token, address to) external returns (uint256)
```

### liquidate

```solidity
function liquidate(uint256 amount, address token, address to) external returns (bool)
```

