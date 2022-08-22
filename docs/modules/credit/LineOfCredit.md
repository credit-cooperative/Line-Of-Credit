# Solidity API

## LineOfCredit

### deadline

```solidity
uint256 deadline
```

### borrower

```solidity
address borrower
```

### arbiter

```solidity
address arbiter
```

### oracle

```solidity
contract IOracle oracle
```

### interestRate

```solidity
contract InterestRateCredit interestRate
```

### count

```solidity
uint256 count
```

### ids

```solidity
bytes32[] ids
```

### credits

```solidity
mapping(bytes32 => struct ILineOfCredit.Credit) credits
```

### status

```solidity
enum LineLib.STATUS status
```

### constructor

```solidity
constructor(address oracle_, address arbiter_, address borrower_, uint256 ttl_) public
```

_- Line borrower and proposed lender agree on terms
            and add it to potential options for borrower to drawdown on
            Lender and borrower must both call function for MutualConsent to add credit position to Line_

| Name | Type | Description |
| ---- | ---- | ----------- |
| oracle_ | address | - price oracle to use for getting all token values |
| arbiter_ | address | - neutral party with some special priviliges on behalf of borrower and lender |
| borrower_ | address | - the debitor for all credit positions in this contract |
| ttl_ | uint256 | - time to live for line of credit contract across all lenders |

### init

```solidity
function init() external virtual returns (enum LineLib.STATUS)
```

### _init

```solidity
function _init() internal virtual returns (enum LineLib.STATUS)
```

### whileActive

```solidity
modifier whileActive()
```

### whileBorrowing

```solidity
modifier whileBorrowing()
```

### onlyBorrower

```solidity
modifier onlyBorrower()
```

### mutualConsentById

```solidity
modifier mutualConsentById(address _signerOne, bytes32 id)
```

- mutualConsent but uses position to get lender address instead of passing it in directly

### healthcheck

```solidity
function healthcheck() external returns (enum LineLib.STATUS)
```

### counts

```solidity
function counts() external view returns (uint256, uint256)
```

- getter for amount of active ids + total ids in list

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | - (uint, uint) - active positions, total length |
| [1] | uint256 |  |

### _healthcheck

```solidity
function _healthcheck() internal virtual returns (enum LineLib.STATUS)
```

### declareInsolvent

```solidity
function declareInsolvent() external returns (bool)
```

- Allow arbiter to signify that borrower is incapable of repaying debt permanently
          Recoverable funds for lender after declaring insolvency = deposit + interestRepaid - principal

_- Needed for onchain impairment accounting e.g. updating ERC4626 share price
          MUST NOT have collateral left for call to succeed.
          Callable only by arbiter._

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bool | bool - If borrower is insolvent or not |

### _canDeclareInsolvent

```solidity
function _canDeclareInsolvent() internal virtual returns (bool)
```

### updateOutstandingDebt

```solidity
function updateOutstandingDebt() external returns (uint256, uint256)
```

- Returns total credit obligation of borrower.
              Aggregated across all lenders.
              Denominated in USD 1e8.

_- callable by anyone_

### _updateOutstandingDebt

```solidity
function _updateOutstandingDebt() internal returns (uint256 principal, uint256 interest)
```

### accrueInterest

```solidity
function accrueInterest() external returns (bool)
```

_- Loops over all credit positions, calls InterestRate module with position data,
            then updates `interestAccrued` on position with returned data._

### _accrue

```solidity
function _accrue(struct ILineOfCredit.Credit credit, bytes32 id) internal returns (struct ILineOfCredit.Credit)
```

### addCredit

```solidity
function addCredit(uint128 drate, uint128 frate, uint256 amount, address token, address lender) external payable returns (bytes32)
```

- Line borrower and proposed lender agree on terms
                    and add it to potential options for borrower to drawdown on
                    Lender and borrower must both call function for MutualConsent to add credit position to Line

_- callable by `lender` and `borrower_

| Name | Type | Description |
| ---- | ---- | ----------- |
| drate | uint128 | - interest rate in bps on funds drawndown on LoC |
| frate | uint128 | - interest rate in bps on all unused funds in LoC |
| amount | uint256 | - amount of `token` to initially deposit |
| token | address | - the token to be lent out |
| lender | address | - address that will manage credit position |

### setRates

```solidity
function setRates(bytes32 id, uint128 drate, uint128 frate) external returns (bool)
```

- Let lender and borrower update rates on a aposition
                  - can set Rates even when LIQUIDATABLE for refinancing

_- include lender in params for cheap gas and consistent API for mutualConsent
             - callable by borrower or any lender_

| Name | Type | Description |
| ---- | ---- | ----------- |
| id | bytes32 | - credit id that we are updating |
| drate | uint128 | - new drawn rate |
| frate | uint128 | - new facility rate |

### increaseCredit

```solidity
function increaseCredit(bytes32 id, uint256 amount) external payable returns (bool)
```

- Let lender and borrower increase total capacity of position
                  - can only increase while line is healthy and ACTIVE.

_- include lender in params for cheap gas and consistent API for mutualConsent
             - callable by borrower_

| Name | Type | Description |
| ---- | ---- | ----------- |
| id | bytes32 | - credit id that we are updating |
| amount | uint256 | - amount to increase deposit / capaciity by |

### depositAndClose

```solidity
function depositAndClose() external payable returns (bool)
```

- Transfers enough tokens to repay entire credit position from `borrower` to Line contract.

_- callable by borrower_

### depositAndRepay

```solidity
function depositAndRepay(uint256 amount) external payable returns (bool)
```

- see _repay() for more details

_- Transfers token used in credit position from msg.sender to Line contract.
- callable by anyone_

| Name | Type | Description |
| ---- | ---- | ----------- |
| amount | uint256 | - amount of `token` in `id` to pay back |

### borrow

```solidity
function borrow(bytes32 id, uint256 amount) external returns (bool)
```

_- Transfers tokens from Line to lender.
       Only allowed to withdraw tokens not already lent out (prevents bank run)
- callable by lender on `id`_

| Name | Type | Description |
| ---- | ---- | ----------- |
| id | bytes32 | - the credit position to draw down credit on |
| amount | uint256 | - amount of tokens borrower wants to take out |

### withdraw

```solidity
function withdraw(bytes32 id, uint256 amount) external returns (bool)
```

_- Transfers tokens from Line to lender.
       Only allowed to withdraw tokens not already lent out (prevents bank run)
- callable by lender on `id`_

| Name | Type | Description |
| ---- | ---- | ----------- |
| id | bytes32 | -the credit position to pay down credit on and close |
| amount | uint256 | - amount of tokens lnder would like to withdraw (withdrawn amount may be lower) |

### close

```solidity
function close(bytes32 id) external payable returns (bool)
```

_- Deletes credit position preventing any more borrowing.
     - Only callable by borrower or lender for credit position
     - Requires that the credit has already been paid off
- callable by `borrower`_

| Name | Type | Description |
| ---- | ---- | ----------- |
| id | bytes32 | -the credit position to close |

### _updateStatus

```solidity
function _updateStatus(enum LineLib.STATUS status_) internal returns (enum LineLib.STATUS)
```

### _createCredit

```solidity
function _createCredit(address lender, address token, uint256 amount) internal returns (bytes32 id)
```

### _repay

```solidity
function _repay(struct ILineOfCredit.Credit credit, bytes32 id, uint256 amount) internal returns (struct ILineOfCredit.Credit)
```

_- Reduces `principal` and/or `interestAccrued` on credit position, increases lender's `deposit`.
            Reduces global USD principal and interestUsd values.
            Expects checks for conditions of repaying and param sanitizing before calling
            e.g. early repayment of principal, tokens have actually been paid by borrower, etc._

| Name | Type | Description |
| ---- | ---- | ----------- |
| credit | struct ILineOfCredit.Credit |  |
| id | bytes32 | - credit position struct with all data pertaining to line |
| amount | uint256 | - amount of token being repaid on credit position |

### _close

```solidity
function _close(struct ILineOfCredit.Credit credit, bytes32 id) internal virtual returns (bool)
```

- checks that credit is fully repaid and remvoes from available lines of credit.

_deletes Credit storage. Store any data u might need later in call before _close()_

### _sortIntoQ

```solidity
function _sortIntoQ(bytes32 p) internal returns (bool)
```

- Insert `p` into the next availble FIFO position in repayment queue
               - once earliest slot is found, swap places with `p` and position in slot.

| Name | Type | Description |
| ---- | ---- | ----------- |
| p | bytes32 | - position id that we are trying to find appropriate place for @return |

