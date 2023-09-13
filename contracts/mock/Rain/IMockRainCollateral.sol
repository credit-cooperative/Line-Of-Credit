// make an interface for the Rain Collateral
pragma solidity ^0.8.17;

interface IMockRainCollateral {
    function isAdmin(address _admin) external view returns (bool);

    function withdrawAsset(
        address _asset,
        address _to,
        uint256 _amount
    ) external;
}