// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.17;

import "openzeppelin/access/Ownable.sol";
import "openzeppelin/token/ERC20/IERC20.sol";
import "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "./IMockRainCollateralFactory.sol";

using SafeERC20 for IERC20;

contract RainCollateral is Ownable {

    address public factory;

    modifier onlyController() {
        require(_getController() == msg.sender, "Unauthorized");
        _;
    }

    constructor(address initialOwner, address _factory) Ownable(initialOwner) {
        factory = _factory;
    }

    

    /**
     * @notice Used to withdraw asset that this contract owns.
     * @dev only active RainCollateralController can call this function
     * @param _recipient recipient address
     * @param _amount withdrawed amount
     */
    function withdrawAsset(
        address _asset,
        address _recipient,
        uint256 _amount
    ) external onlyController {
        IERC20(_asset).safeTransfer(_recipient, _amount);
    }

    function _getController() internal view returns (address) {
        // Controller address is kept in RainCollateralFactory
        return IMockRainCollateralFactory(factory).controller();
    }
}


