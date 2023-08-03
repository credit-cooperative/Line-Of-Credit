// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.17;

import "openzeppelin/access/Ownable.sol";
import "openzeppelin/token/ERC20/IERC20.sol";
import "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "./IMockRainCollateralFactory.sol";
import "./IMockRainCollateral.sol";

contract MockRainCollateralController is Ownable {
    address public controllerAdmin;

    /// @notice Treasury contract address where Rain Company keeps its treasury.
    ///         Payment and liqudation moves assets to treasury.
    address public treasury;


    constructor(address _controllerAdmin, address _treasury, address initialOwner) Ownable(initialOwner) {
        controllerAdmin = _controllerAdmin;
        treasury = _treasury;
    }

    function _transferToTreasury(
        address _collateralProxy,
        address _asset,
        uint256 _amount
    ) internal {
        IMockRainCollateral(_collateralProxy).withdrawAsset(
            _asset,
            treasury,
            _amount
        );
    }

    function liquidateAsset(
        address _collateralProxy,
        address[] calldata _assets,
        uint256[] calldata _amounts
    ) external {
        require(msg.sender == controllerAdmin, "Not controller admin");
        require(_assets.length == _amounts.length, "Invalid Params");
        for (uint256 i = 0; i < _assets.length; i++) {
            _transferToTreasury(_collateralProxy, _assets[i], _amounts[i]);
        }

    }

    /**
     * @notice Used to update controller admin address
     * @dev only owner can call this function
     * @param _controllerAdmin new controller admin address
     * Requirements:
     * - `_controllerAdmin` should not be NullAddress.
     */
    function updateControllerAdmin(address _controllerAdmin)
        external
        onlyOwner
    {
        require(_controllerAdmin != address(0), "Zero Address");
        controllerAdmin = _controllerAdmin;
    }

    /**
     * @notice Used to update treasury contract address
     * @dev only owner can call this function
     * @param _treasury new treasury contract address
     * Requirements:
     * - `_newAddress` should not be NullAddress.
     */
    function updateTreasury(address _treasury) external onlyOwner {
        require(_treasury != address(0), "Zero Address");
        treasury = _treasury;
    }

}