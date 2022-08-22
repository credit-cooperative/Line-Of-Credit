# Solidity API

## MutualConsent

### mutualConsents

```solidity
mapping(bytes32 => bool) mutualConsents
```

### Unauthorized

```solidity
error Unauthorized()
```

### MutualConsentRegistered

```solidity
event MutualConsentRegistered(bytes32 _consentHash)
```

### mutualConsent

```solidity
modifier mutualConsent(address _signerOne, address _signerTwo)
```

- allows a function to be called if only two specific stakeholders signoff on the tx data
        - signers can be anyone. only two signers per contract or dynamic signers per tx.

### _mutualConsent

```solidity
function _mutualConsent(address _signerOne, address _signerTwo) internal returns (bool)
```

### _getNonCaller

```solidity
function _getNonCaller(address _signerOne, address _signerTwo) internal view returns (address)
```

