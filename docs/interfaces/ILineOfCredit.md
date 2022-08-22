# Solidity API

## ILineOfCredit

### Credit

```solidity
struct Credit {
  uint256 deposit;
  uint256 principal;
  uint256 interestAccrued;
  uint256 interestRepaid;
  uint8 decimals;
  address token;
  address lender;
}
```

### UpdateStatus

```solidity
event UpdateStatus(uint256 status)
```

### DeployLine

```solidity
event DeployLine(address oracle, address arbiter, address borrower)
```

### AddCredit

```solidity
event AddCredit(address lender, address token, uint256 deposit, bytes32 positionId)
```

### SetRates

```solidity
event SetRates(bytes32 id, uint128 drawnRate, uint128 facilityRate)
```

### IncreaseCredit

```solidity
event IncreaseCredit(bytes32 id, uint256 deposit)
```

### WithdrawDeposit

```solidity
event WithdrawDeposit(bytes32 id, uint256 amount)
```

### WithdrawProfit

```solidity
event WithdrawProfit(bytes32 id, uint256 amount)
```

### CloseCreditPosition

```solidity
event CloseCreditPosition(bytes32 id)
```

### InterestAccrued

```solidity
event InterestAccrued(bytes32 id, uint256 amount)
```

### Borrow

```solidity
event Borrow(bytes32 id, uint256 amount)
```

### RepayInterest

```solidity
event RepayInterest(bytes32 id, uint256 amount)
```

### RepayPrincipal

```solidity
event RepayPrincipal(bytes32 id, uint256 amount)
```

### Default

```solidity
event Default(bytes32 id)
```

### NotActive

```solidity
error NotActive()
```

### NotBorrowing

```solidity
error NotBorrowing()
```

### CallerAccessDenied

```solidity
error CallerAccessDenied()
```

### TokenTransferFailed

```solidity
error TokenTransferFailed()
```

### NoTokenPrice

```solidity
error NoTokenPrice()
```

### BadModule

```solidity
error BadModule(address module)
```

### NoLiquidity

```solidity
error NoLiquidity()
```

### PositionExists

```solidity
error PositionExists()
```

### CloseFailedWithPrincipal

```solidity
error CloseFailedWithPrincipal()
```

### NotInsolvent

```solidity
error NotInsolvent(address module)
```

### NotLiquidatable

```solidity
error NotLiquidatable()
```

### AlreadyInitialized

```solidity
error AlreadyInitialized()
```

### init

```solidity
function init() external returns (enum LineLib.STATUS)
```

### addCredit

```solidity
function addCredit(uint128 drate, uint128 frate, uint256 amount, address token, address lender) external payable returns (bytes32)
```

### setRates

```solidity
function setRates(bytes32 id, uint128 drate, uint128 frate) external returns (bool)
```

### increaseCredit

```solidity
function increaseCredit(bytes32 id, uint256 amount) external payable returns (bool)
```

### borrow

```solidity
function borrow(bytes32 id, uint256 amount) external returns (bool)
```

### depositAndRepay

```solidity
function depositAndRepay(uint256 amount) external payable returns (bool)
```

### depositAndClose

```solidity
function depositAndClose() external payable returns (bool)
```

### close

```solidity
function close(bytes32 id) external payable returns (bool)
```

### withdraw

```solidity
function withdraw(bytes32 id, uint256 amount) external returns (bool)
```

### declareInsolvent

```solidity
function declareInsolvent() external returns (bool)
```

### accrueInterest

```solidity
function accrueInterest() external returns (bool)
```

### healthcheck

```solidity
function healthcheck() external returns (enum LineLib.STATUS)
```

### updateOutstandingDebt

```solidity
function updateOutstandingDebt() external returns (uint256, uint256)
```

### status

```solidity
function status() external returns (enum LineLib.STATUS)
```

### borrower

```solidity
function borrower() external returns (address)
```

### arbiter

```solidity
function arbiter() external returns (address)
```

### oracle

```solidity
function oracle() external returns (contract IOracle)
```

### counts

```solidity
function counts() external view returns (uint256, uint256)
```

