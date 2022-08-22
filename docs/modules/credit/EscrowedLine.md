# Solidity API

## EscrowedLine

### escrow

```solidity
contract IEscrow escrow
```

### constructor

```solidity
constructor(address _escrow) internal
```

### _init

```solidity
function _init() internal virtual returns (enum LineLib.STATUS)
```

### _healthcheck

```solidity
function _healthcheck() internal virtual returns (enum LineLib.STATUS)
```

_see BaseLine._healthcheck_

### _liquidate

```solidity
function _liquidate(bytes32 positionId, uint256 amount, address targetToken, address to) internal virtual returns (uint256)
```

sends escrowed tokens to liquidation. 
(@dev priviliegad function. Do checks before calling.

| Name | Type | Description |
| ---- | ---- | ----------- |
| positionId | bytes32 | - position being repaid in liquidation |
| amount | uint256 | - amount of tokens to take from escrow and liquidate |
| targetToken | address | - the token to take from escrow |
| to | address | - the liquidator to send tokens to. could be OTC address or smart contract |

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | amount - the total amount of `targetToken` sold to repay credit |

### _canDeclareInsolvent

```solidity
function _canDeclareInsolvent() internal virtual returns (bool)
```

require all collateral sold off before declaring insolvent
(@dev priviliegad internal function.

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bool | if line is insolvent or not |

### _rollover

```solidity
function _rollover(address newLine) internal virtual returns (bool)
```

