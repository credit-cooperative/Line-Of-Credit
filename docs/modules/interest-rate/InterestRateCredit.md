# Solidity API

## InterestRateCredit

### ONE_YEAR

```solidity
uint256 ONE_YEAR
```

### BASE_DENOMINATOR

```solidity
uint256 BASE_DENOMINATOR
```

### INTEREST_DENOMINATOR

```solidity
uint256 INTEREST_DENOMINATOR
```

### lineContract

```solidity
address lineContract
```

### rates

```solidity
mapping(bytes32 => struct IInterestRateCredit.Rate) rates
```

### constructor

```solidity
constructor() public
```

Interest contract for line of credit contracts

### onlyLineContract

```solidity
modifier onlyLineContract()
```

### accrueInterest

```solidity
function accrueInterest(bytes32 id, uint256 drawnBalance, uint256 facilityBalance) external returns (uint256)
```

_accrueInterest function for revolver line
   - callable by `line`_

| Name | Type | Description |
| ---- | ---- | ----------- |
| id | bytes32 |  |
| drawnBalance | uint256 | balance of drawn funds |
| facilityBalance | uint256 | balance of facility funds |

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | repayBalance amount to be repaid for this interest period |

### _accrueInterest

```solidity
function _accrueInterest(bytes32 id, uint256 drawnBalance, uint256 facilityBalance) internal returns (uint256)
```

### setRate

```solidity
function setRate(bytes32 id, uint128 drawnRate, uint128 facilityRate) external returns (bool)
```

update interest rates for a position

_- Line contract responsible for calling accrueInterest() before updateInterest() if necessary
   - callable by `line`_

