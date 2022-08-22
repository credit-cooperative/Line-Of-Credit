# Solidity API

## CreditListLib

Core logic and variables to be reused across all Debt DAO Marketplace loans

### removePosition

```solidity
function removePosition(bytes32[] ids, bytes32 id) external returns (bool)
```

_assumes that `id` is stored only once in `positions` array bc no reason for Loans to store multiple times.
          This means cleanup on _close() and checks on addDebtPosition are CRITICAL. If `id` is duplicated then the position can't be closed_

| Name | Type | Description |
| ---- | ---- | ----------- |
| ids | bytes32[] | - all current active positions on the loan |
| id | bytes32 | - hash id that must be removed from active positions |

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bool | newPositions - all active positions on loan after `id` is removed |

### stepQ

```solidity
function stepQ(bytes32[] ids) external returns (bool)
```

- removes debt position from head of repayement queue and puts it at end of line
        - moves 2nd in line to first

| Name | Type | Description |
| ---- | ---- | ----------- |
| ids | bytes32[] | - all current active positions on the loan |

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bool | newPositions - positions after moving first to last in array |

