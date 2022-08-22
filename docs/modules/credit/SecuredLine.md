# Solidity API

## SecuredLine

### constructor

```solidity
constructor(address oracle_, address arbiter_, address borrower_, address payable swapTarget_, address spigot_, address escrow_, uint256 ttl_, uint8 defaultSplit_) public
```

### _init

```solidity
function _init() internal virtual returns (enum LineLib.STATUS)
```

### rollover

```solidity
function rollover(address newLine) external returns (bool)
```

### liquidate

```solidity
function liquidate(uint256 amount, address targetToken) external returns (uint256)
```

- Forcefully take collateral from borrower and repay debt for lender

_- only called by neutral arbiter party/contract
- `status` must be LIQUIDATABLE
- callable by `arbiter`_

| Name | Type | Description |
| ---- | ---- | ----------- |
| amount | uint256 | - amount of `targetToken` expected to be sold off in  _liquidate |
| targetToken | address | - token in escrow that will be sold of to repay position |

### _healthcheck

```solidity
function _healthcheck() internal returns (enum LineLib.STATUS)
```

checks internal accounting logic for status and if ok, runs modules checks

### _canDeclareInsolvent

```solidity
function _canDeclareInsolvent() internal virtual returns (bool)
```

all insolvency conditions must pass for call to succeed

