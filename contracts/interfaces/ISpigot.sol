// SPDX-License-Identifier: GPL-3.0
// Copyright: https://github.com/credit-cooperative/Line-Of-Credit/blob/master/COPYRIGHT.md

 pragma solidity ^0.8.16;

interface ISpigot {
    struct Setting {
        uint8 ownerSplit; // x/100 % to Owner, rest to Operator
        bytes4 claimFunction; // function signature on contract to call and claim revenue
        bytes4 transferOwnerFunction; // function signature on contract to call and transfer ownership
    }

    struct Beneficiary {
        address bennyOperator;
        uint256 allocation;
        address creditToken;
       // uint256 readyForRepayment; Maybe we store tokens here and have a different function for repaying, might need to be automation.
        uint256 debtOwed;
        mapping(address => uint256) bennyTokens;
        mapping(address => uint256) tokensToDistribute;
        address poolAddress; // will this ALWAYS be the same as the benny address?
        bytes4 repaymentFunc; // we NEED this
        bytes4 getDebtFunc; // could do without this and just update via amend and extend (for huma at least)
        
        
    }

    // Spigot Events
    event AddSpigot(address indexed revenueContract, uint256 ownerSplit, bytes4 claimFnSig, bytes4 trsfrFnSig);

    event RemoveSpigot(address indexed revenueContract, address token);

    event UpdateWhitelistFunction(bytes4 indexed func, bool indexed allowed);

    event UpdateOwnerSplit(address indexed revenueContract, uint8 indexed split);

    event ClaimRevenue(address indexed token, uint256 indexed amount, uint256 escrowed, address revenueContract);

    event ClaimOwnerTokens(address indexed token, uint256 indexed amount, address owner);

    event ClaimOperatorTokens(address indexed token, uint256 indexed amount, address operator);

    // Stakeholder Events

    event UpdateOwner(address indexed newOwner);

    event UpdateOperator(address indexed newOperator);

    // Errors
    error BadFunction();

    error OperatorFnNotWhitelisted();

    error OperatorFnNotValid();

    error OperatorFnCallFailed();

    error ClaimFailed();

    error NoRevenue();

    error UnclaimedRevenue();

    error CallerAccessDenied();

    error BadSetting();

    error InvalidRevenueContract();

    error NoTokensToDistribute();

    error NotInitialized();

    // ops funcs

    function claimRevenue(
        address revenueContract,
        address token,
        bytes calldata data
    ) external returns (uint256 claimed);

    function repayLender(address lender, bytes memory args) external returns (bool);

    function operate(address revenueContract, bytes calldata data) external returns (bool);

    // owner funcs

    function claimOwnerTokens(address token) external returns (uint256 claimed);

    function claimOperatorTokens(address token) external returns (uint256);

    function distributeFunds(address token) external returns (uint256[] memory);

    function addSpigot(address revenueContract, Setting memory setting) external returns (bool);

    function removeSpigot(address revenueContract) external returns (bool);

    function updateBeneficiaryInfo(address beneficiary, address newOperator, uint256 newAllocation, address newCreditToken, uint256 newOutstandingDebt) external;

    // stakeholder funcs

    function updateOwnerSplit(address revenueContract, uint8 ownerSplit) external returns (bool);

    function updateOwner(address newOwner) external returns (bool);

    function updateOperator(address newOperator) external returns (bool);

    function updateWhitelistedFunction(bytes4 func, bool allowed) external returns (bool);

    function deleteBeneficiaries() external;

    function addBeneficiaryAddress(address beneficiary) external;

    // Getters

    function getBeneficiaryBasicInfo(address beneficiary) external view returns (
        address bennyOperator,
        uint256 allocation,
        address creditToken,
        uint256 debtOwed
    );

    function getBennyTokenAmount(address beneficiary, address token) external view returns (uint256);

    function beneficiaries() external view returns (address[] memory);

    function owner() external view returns (address);

    function operator() external view returns (address);

    function isWhitelisted(bytes4 func) external view returns (bool);

    function getOwnerTokens(address token) external view returns (uint256);

    function getLenderTokens(address token, address lender) external view returns (uint256);

    function getOperatorTokens(address token) external view returns (uint256);

    function getSetting(
        address revenueContract
    ) external view returns (uint8 split, bytes4 claimFunc, bytes4 transferFunc);

    function hasBeneficiaryDebtOutstanding() external view returns (bool);
}
