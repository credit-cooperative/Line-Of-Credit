# Solidity API

## Escrow

### minimumCollateralRatio

```solidity
uint256 minimumCollateralRatio
```

### MAX_INT

```solidity
uint256 MAX_INT
```

### oracle

```solidity
address oracle
```

### borrower

```solidity
address borrower
```

### line

```solidity
address line
```

### _collateralTokens

```solidity
address[] _collateralTokens
```

### enabled

```solidity
mapping(address => bool) enabled
```

### deposited

```solidity
mapping(address => struct IEscrow.Deposit) deposited
```

### constructor

```solidity
constructor(uint256 _minimumCollateralRatio, address _oracle, address _line, address _borrower) public
```

### isLiquidatable

```solidity
function isLiquidatable() external returns (bool)
```

### updateLine

```solidity
function updateLine(address _line) external returns (bool)
```

### _getLatestCollateralRatio

```solidity
function _getLatestCollateralRatio() internal returns (uint256)
```

updates the cratio according to the collateral value vs line value

_calls accrue interest on the line contract to update the latest interest payable_

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | the updated collateral ratio in 18 decimals |

### _percent

```solidity
function _percent(uint256 numerator, uint256 denominator, uint256 precision) internal pure returns (uint256 quotient)
```

- computes the ratio of one value to another
               - e.g. _percent(100, 100, 18) = 1 ether = 100%

| Name | Type | Description |
| ---- | ---- | ----------- |
| numerator | uint256 | - value to compare |
| denominator | uint256 | - value to compare against |
| precision | uint256 | - number of decimal places of accuracy to return in answer |

| Name | Type | Description |
| ---- | ---- | ----------- |
| quotient | uint256 | -  the result of num / denom |

### _getCollateralValue

```solidity
function _getCollateralValue() internal returns (uint256)
```

_calculate the USD value of all the collateral stored_

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | - the collateral's USD value in 8 decimals |

### addCollateral

```solidity
function addCollateral(uint256 amount, address token) external returns (uint256)
```

add collateral to your position

_updates cratio
requires that the token deposited can be valued by the escrow's oracle & the depositor has approved this contract
- callable by anyone_

| Name | Type | Description |
| ---- | ---- | ----------- |
| amount | uint256 | - the amount of collateral to add |
| token | address | - the token address of the deposited token |

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | - the updated cratio |

### enableCollateral

```solidity
function enableCollateral(address token) external returns (bool)
```

- allows  the lines arbiter to  enable thdeposits of an asset
       - gives  better risk segmentation forlenders

_- whitelisting protects against malicious 4626 tokens and DoS attacks
      - only need to allow once. Can not disable collateral once enabled._

| Name | Type | Description |
| ---- | ---- | ----------- |
| token | address | - the token to all borrow to deposit as collateral |

### _enableToken

```solidity
function _enableToken(address token) internal returns (bool)
```

track the tokens used as collateral. Ensures uniqueness,
              flags if its a EIP 4626 token, and gets its decimals

_- if 4626 token then Deposit.asset s the underlying asset, not the 4626 token
return bool - if collateral is now enabled or not._

### releaseCollateral

```solidity
function releaseCollateral(uint256 amount, address token, address to) external returns (uint256)
```

remove collateral from your position. Must remain above min collateral ratio

_callable by `borrower`
updates cratio_

| Name | Type | Description |
| ---- | ---- | ----------- |
| amount | uint256 | - the amount of collateral to release |
| token | address | - the token address to withdraw |
| to | address | - who should receive the funds |

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | - the updated cratio |

### getCollateralRatio

```solidity
function getCollateralRatio() external returns (uint256)
```

calculates the cratio

_callable by anyone_

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | - the calculated cratio |

### getCollateralValue

```solidity
function getCollateralValue() external returns (uint256)
```

calculates the collateral value in USD to 8 decimals

_callable by anyone_

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | - the calculated collateral value to 8 decimals |

### liquidate

```solidity
function liquidate(uint256 amount, address token, address to) external returns (bool)
```

liquidates borrowers collateral by token and amount
        line can liquidate at anytime based off other covenants besides cratio

_requires that the cratio is at or below the liquidation threshold
callable by `line`_

| Name | Type | Description |
| ---- | ---- | ----------- |
| amount | uint256 | - the amount of tokens to liquidate |
| token | address | - the address of the token to draw funds from |
| to | address | - the address to receive the funds |

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bool | - true if successful |

