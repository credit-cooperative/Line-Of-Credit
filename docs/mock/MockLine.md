# Solidity API

## MockLine

### debtValueUSD

```solidity
uint256 debtValueUSD
```

### escrow

```solidity
address escrow
```

### arbiter

```solidity
address arbiter
```

### status

```solidity
enum LineLib.STATUS status
```

### constructor

```solidity
constructor(uint256 _debt, address arbiter_) public
```

### setEscrow

```solidity
function setEscrow(address _escrow) public
```

### setArbiter

```solidity
function setArbiter(address _arbiter) public
```

### setDebtValue

```solidity
function setDebtValue(uint256 _debt) external
```

### setStatus

```solidity
function setStatus(enum LineLib.STATUS _status) external
```

### liquidate

```solidity
function liquidate(uint256 positionId, uint256 amount, address token, address to) external
```

### accrueInterest

```solidity
function accrueInterest() external pure returns (uint256)
```

### updateOutstandingDebt

```solidity
function updateOutstandingDebt() external view returns (uint256, uint256)
```

