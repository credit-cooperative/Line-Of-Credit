# Solidity API

## IInterestRateCredit

### Rate

```solidity
struct Rate {
  uint128 drawnRate;
  uint128 facilityRate;
  uint256 lastAccrued;
}
```

### accrueInterest

```solidity
function accrueInterest(bytes32 positionId, uint256 drawnAmount, uint256 facilityAmount) external returns (uint256)
```

### setRate

```solidity
function setRate(bytes32 positionId, uint128 drawnRate, uint128 facilityRate) external returns (bool)
```

