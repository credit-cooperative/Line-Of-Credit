// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "openzeppelin/proxy/utils/Initializable.sol";

// Define the state of the credit line
enum CreditState {
        Deleted,
        Requested,
        Approved,
        GoodStanding,
        Delayed,
        Defaulted
    }

// Define the CreditRecord struct as specified
struct CreditRecord {
    uint96 unbilledPrincipal;
    uint64 dueDate;
    int96 correction;
    uint96 totalDue;
    uint96 feesAndInterestDue;
    uint16 missedPeriods;
    uint16 remainingPeriods;
    CreditState state;
}

// Interface for HumaRainPool
interface IHumaRainPool {
    function creditRecordMapping(address account) external view returns (CreditRecord memory);
}

// Implementation contract
contract GetDebtImplementation is Initializable {

    mapping(address => uint8) public orderOfLenders;
    uint8 public numberOfLenders;
    // Address of the HumaRainPool contract

    // Initialize the contract with the HumaRainPool address
    function initialize(address _humaRainPoolAddress) public initializer {
        orderOfLenders[_humaRainPoolAddress] = 1;
        numberOfLenders = 1;
    }

    // Function to get debt information
    function getDebt(address[] memory accounts) public view returns (uint96[] memory) {
        uint96[] memory totalDues = new uint96[](accounts.length);
        for (uint i = 0; i < accounts.length; i++) {
            totalDues[i] = humaDebt(accounts[i]);
        }
        return totalDues;
    }

    // Internal function to calculate debt using HumaRainPool
    function humaDebt(address account) internal view returns (uint96) {
        CreditRecord memory creditRecord = IHumaRainPool(account).creditRecordMapping(account);
        return creditRecord.totalDue;
    }
}
