# Solidity API

## IEscrowedLine

### Liquidate

```solidity
event Liquidate(bytes32 positionId, uint256 amount, address token)
```

### liquidate

```solidity
function liquidate(uint256 amount, address targetToken) external returns (uint256)
```

