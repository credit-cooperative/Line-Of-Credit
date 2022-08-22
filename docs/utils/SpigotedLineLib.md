# Solidity API

## SpigotedLineLib

### MAX_SPLIT

```solidity
uint8 MAX_SPLIT
```

### NoSpigot

```solidity
error NoSpigot()
```

### TradeFailed

```solidity
error TradeFailed()
```

### BadTradingPair

```solidity
error BadTradingPair()
```

### CallerAccessDenied

```solidity
error CallerAccessDenied()
```

### ReleaseSpigotFailed

```solidity
error ReleaseSpigotFailed()
```

### NotInsolvent

```solidity
error NotInsolvent(address module)
```

### UsedExcessTokens

```solidity
error UsedExcessTokens(address token, uint256 amountAvailable)
```

### TradeSpigotRevenue

```solidity
event TradeSpigotRevenue(address revenueToken, uint256 revenueTokenAmount, address debtToken, uint256 debtTokensBought)
```

### claimAndTrade

```solidity
function claimAndTrade(address claimToken, address targetToken, address payable swapTarget, address spigot, uint256 unused, bytes zeroExTradeData) external returns (uint256, uint256)
```

allows tokens in escrow to be sold immediately but used to pay down credit later

_MUST trade all available claim tokens to target
   priviliged internal function_

| Name | Type | Description |
| ---- | ---- | ----------- |
| claimToken | address | - the token escrowed in spigot to sell in trade |
| targetToken | address | - the token borrow owed debt in and needs to buy. Always `credits[ids[0]].token` |
| swapTarget | address payable | - 0x exchange router address to call for trades |
| spigot | address | - spigot to claim from. Must be owned by adddress(this) |
| unused | uint256 | - current amount of unused claimTokens |
| zeroExTradeData | bytes | - 0x API data to use in trade to sell `claimToken` for target |

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | (uint, uint) - (amount of target tokens bought, total unused claim tokens after trade) |
| [1] | uint256 |  |

### trade

```solidity
function trade(uint256 amount, address sellToken, address payable swapTarget, bytes zeroExTradeData) public returns (bool)
```

### rollover

```solidity
function rollover(address spigot, address newLine) external returns (bool)
```

cleanup function when borrower this line ends

### canDeclareInsolvent

```solidity
function canDeclareInsolvent(address spigot, address arbiter) external view returns (bool)
```

### updateSplit

```solidity
function updateSplit(address spigot, address revenueContract, enum LineLib.STATUS status, uint8 defaultSplit) external returns (bool)
```

changes the revenue split between borrower treasury and lan repayment based on line health

_- callable `arbiter` + `borrower`_

| Name | Type | Description |
| ---- | ---- | ----------- |
| spigot | address |  |
| revenueContract | address | - spigot to update |
| status | enum LineLib.STATUS |  |
| defaultSplit | uint8 |  |

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bool | whether or not split was updated |

### releaseSpigot

```solidity
function releaseSpigot(address spigot, enum LineLib.STATUS status, address borrower, address arbiter) external returns (bool)
```

-  transfers revenue streams to borrower if repaid or arbiter if liquidatable
             -  doesnt transfer out if line is unpaid and/or healthy

_- callable by anyone_

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bool | - whether or not spigot was released |

### sweep

```solidity
function sweep(address to, address token, uint256 amount, enum LineLib.STATUS status, address borrower, address arbiter) external returns (bool)
```

-  transfers revenue streams to borrower if repaid or arbiter if liquidatable
             -  doesnt transfer out if line is unpaid and/or healthy

_- callable by anyone_

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bool | - whether or not spigot was released |

