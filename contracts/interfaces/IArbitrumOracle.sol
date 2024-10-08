 pragma solidity ^0.8.16;

interface IArbitrumOracle {
    /** current price for token asset. denominated in USD */
    function getLatestAnswer(address token) external returns (int256);

    /** Readonly function providing the current price for token asset. denominated in USD */
    function _getLatestAnswer(address token) external view returns (int256);

    function setPriceFeed(address token, address priceFeed) external;
}