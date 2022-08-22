# Solidity API

## Spigot

Contract allowing Owner to secure revenue streams from a DAO and split payments between them

_Should be deployed once per line. Can attach multiple revenue contracts_

### MAX_SPLIT

```solidity
uint8 MAX_SPLIT
```

### MAX_REVENUE

```solidity
uint256 MAX_REVENUE
```

### owner

```solidity
address owner
```

### operator

```solidity
address operator
```

### treasury

```solidity
address treasury
```

### escrowed

```solidity
mapping(address => uint256) escrowed
```

### whitelistedFunctions

```solidity
mapping(bytes4 => bool) whitelistedFunctions
```

### settings

```solidity
mapping(address => struct ISpigot.Setting) settings
```

### constructor

```solidity
constructor(address _owner, address _treasury, address _operator) public
```

_Configure data for contract owners and initial revenue contracts.
            Owner/operator/treasury can all be the same address_

| Name | Type | Description |
| ---- | ---- | ----------- |
| _owner | address | Third party that owns rights to contract's revenue stream |
| _treasury | address | Treasury of DAO that owns contract and receives leftover revenues |
| _operator | address | Operational account of DAO that actively manages contract health |

### whileNoUnclaimedRevenue

```solidity
modifier whileNoUnclaimedRevenue(address token)
```

### claimRevenue

```solidity
function claimRevenue(address revenueContract, bytes data) external returns (uint256 claimed)
```

- Claim push/pull payments through Spigots.
                 Calls predefined function in contract settings to claim revenue.
                 Automatically sends portion to treasury and escrows Owner's share.

_- callable by anyone_

| Name | Type | Description |
| ---- | ---- | ----------- |
| revenueContract | address | Contract with registered settings to claim revenue from |
| data | bytes | Transaction data, including function signature, to properly claim revenue on revenueContract |

| Name | Type | Description |
| ---- | ---- | ----------- |
| claimed | uint256 | -  The amount of tokens claimed from revenueContract and split in payments to `owner` and `treasury` |

### _claimRevenue

```solidity
function _claimRevenue(address revenueContract, bytes data, address token) internal returns (uint256 claimed)
```

### claimEscrow

```solidity
function claimEscrow(address token) external returns (uint256 claimed)
```

- Allows Spigot Owner to claim escrowed tokens from a revenue contract

_- callable by `owner`_

| Name | Type | Description |
| ---- | ---- | ----------- |
| token | address | Revenue token that is being escrowed by spigot |

| Name | Type | Description |
| ---- | ---- | ----------- |
| claimed | uint256 | -  The amount of tokens claimed from revenue garnish by `owner` |

### operate

```solidity
function operate(address revenueContract, bytes data) external returns (bool)
```

- Allows Operator to call whitelisted functions on revenue contracts to maintain their product
          while still allowing Spigot Owner to own revenue stream from contract

_- callable by `operator`_

| Name | Type | Description |
| ---- | ---- | ----------- |
| revenueContract | address | - smart contract to call |
| data | bytes | - tx data, including function signature, to call contract with |

### _operate

```solidity
function _operate(address revenueContract, bytes data) internal returns (bool)
```

- Checks that operation is whitelisted by Spigot Owner and calls revenue contract with supplied data

| Name | Type | Description |
| ---- | ---- | ----------- |
| revenueContract | address | - smart contracts to call |
| data | bytes | - tx data, including function signature, to call contracts with |

### addSpigot

```solidity
function addSpigot(address revenueContract, struct ISpigot.Setting setting) external returns (bool)
```

Allow owner to add new revenue stream to spigot

_- callable by `owner`_

| Name | Type | Description |
| ---- | ---- | ----------- |
| revenueContract | address | - smart contract to claim tokens from |
| setting | struct ISpigot.Setting | - spigot settings for smart contract |

### _addSpigot

```solidity
function _addSpigot(address revenueContract, struct ISpigot.Setting setting) internal returns (bool)
```

Checks  revenue contract doesn't already have spigot
     then registers spigot configuration for revenue contract

| Name | Type | Description |
| ---- | ---- | ----------- |
| revenueContract | address | - smart contract to claim tokens from |
| setting | struct ISpigot.Setting | - spigot configuration for smart contract |

### removeSpigot

```solidity
function removeSpigot(address revenueContract) external returns (bool)
```

- Change owner of revenue contract from Spigot (this contract) to Operator.
     Sends existing escrow to current Owner.

_- callable by `owner`_

| Name | Type | Description |
| ---- | ---- | ----------- |
| revenueContract | address | - smart contract to transfer ownership of |

### updateOwnerSplit

```solidity
function updateOwnerSplit(address revenueContract, uint8 ownerSplit) external returns (bool)
```

### updateOwner

```solidity
function updateOwner(address newOwner) external returns (bool)
```

- Update Owner role of Spigot contract.
     New Owner receives revenue stream split and can control Spigot

_- callable by `owner`_

| Name | Type | Description |
| ---- | ---- | ----------- |
| newOwner | address | - Address to give control to |

### updateOperator

```solidity
function updateOperator(address newOperator) external returns (bool)
```

- Update Operator role of Spigot contract.
     New Operator can interact with revenue contracts.

_- callable by `operator`_

| Name | Type | Description |
| ---- | ---- | ----------- |
| newOperator | address | - Address to give control to |

### updateTreasury

```solidity
function updateTreasury(address newTreasury) external returns (bool)
```

- Update Treasury role of Spigot contract.
     New Treasury receives revenue stream split

_- callable by `treasury`_

| Name | Type | Description |
| ---- | ---- | ----------- |
| newTreasury | address | - Address to divert funds to |

### updateWhitelistedFunction

```solidity
function updateWhitelistedFunction(bytes4 func, bool allowed) external returns (bool)
```

- Allows Owner to whitelist function methods across all revenue contracts for Operator to call.
          Can whitelist "transfer ownership" functions on revenue contracts
          allowing Spigot to give direct control back to Operator.

_- callable by `owner`_

| Name | Type | Description |
| ---- | ---- | ----------- |
| func | bytes4 | - smart contract function signature to whitelist |
| allowed | bool | - true/false whether to allow this function to be called by Operator |

### getEscrowed

```solidity
function getEscrowed(address token) external view returns (uint256)
```

- Retrieve amount of tokens tokens escrowed waiting for claim

| Name | Type | Description |
| ---- | ---- | ----------- |
| token | address | Revenue token that is being garnished from spigots |

### isWhitelisted

```solidity
function isWhitelisted(bytes4 func) external view returns (bool)
```

- If a function is callable on revenue contracts

| Name | Type | Description |
| ---- | ---- | ----------- |
| func | bytes4 | Function to check on whitelist |

### getSetting

```solidity
function getSetting(address revenueContract) external view returns (address, uint8, bytes4, bytes4)
```

### receive

```solidity
receive() external payable
```

