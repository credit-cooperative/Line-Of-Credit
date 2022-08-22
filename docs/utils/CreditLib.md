# Solidity API

## CreditLib

Core logic and variables to be reused across all Debt DAO Marketplace lines

### AddCredit

```solidity
event AddCredit(address lender, address token, uint256 deposit, bytes32 positionId)
```

### WithdrawDeposit

```solidity
event WithdrawDeposit(bytes32 id, uint256 amount)
```

### WithdrawProfit

```solidity
event WithdrawProfit(bytes32 id, uint256 amount)
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

### NoTokenPrice

```solidity
error NoTokenPrice()
```

### PositionExists

```solidity
error PositionExists()
```

### computeId

```solidity
function computeId(address line, address lender, address token) external pure returns (bytes32)
```

_- Create deterministic hash id for a debt position on `line` given position details_

| Name | Type | Description |
| ---- | ---- | ----------- |
| line | address | - line that debt position exists on |
| lender | address | - address managing debt position |
| token | address | - token that is being lent out in debt position |

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bytes32 | positionId |

### getOutstandingDebt

```solidity
function getOutstandingDebt(struct ILineOfCredit.Credit credit, bytes32 id, address oracle, address interestRate) external returns (struct ILineOfCredit.Credit c, uint256 principal, uint256 interest)
```

### calculateValue

```solidity
function calculateValue(int256 price, uint256 amount, uint8 decimals) public pure returns (uint256)
```

- calculates value of tokens in US

_- Assumes oracles all return answers in USD with 1e8 decimals
                       - Does not check if price < 0. HAndled in Oracle or Line_

| Name | Type | Description |
| ---- | ---- | ----------- |
| price | int256 | - oracle price of asset. 8 decimals |
| amount | uint256 | - amount of tokens vbeing valued. |
| decimals | uint8 | - token decimals to remove for usd price |

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | - total USD value of amount in 8 decimals |

### create

```solidity
function create(bytes32 id, uint256 amount, address lender, address token, address oracle) external returns (struct ILineOfCredit.Credit credit)
```

### repay

```solidity
function repay(struct ILineOfCredit.Credit credit, bytes32 id, uint256 amount) external returns (struct ILineOfCredit.Credit)
```

### withdraw

```solidity
function withdraw(struct ILineOfCredit.Credit credit, bytes32 id, uint256 amount) external returns (struct ILineOfCredit.Credit)
```

### accrue

```solidity
function accrue(struct ILineOfCredit.Credit credit, bytes32 id, address interest) public returns (struct ILineOfCredit.Credit)
```

