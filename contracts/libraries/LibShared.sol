// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../model/Protocol.sol";
import "../model/Event.sol";
import "../utils/validators/Error.sol";
import "../utils/validators/Validator.sol";
import "../utils/constants/Constant.sol";
import "./LibAppStorage.sol";

library LibShared {
    using SafeERC20 for IERC20;

    /**
     * @dev Allows a user to deposit collateral.
     * @param _tokenCollateralAddress The address of the collateral token to deposit.
     * @param _amountOfCollateral The amount of collateral to deposit.
     * @param _user The address of the user depositing the collateral.
     */
    function _depositCollateral(
        LibAppStorage.Layout storage _appStorage,
        address _tokenCollateralAddress,
        uint256 _amountOfCollateral,
        address _user,
        uint64 _chainSelector
    ) internal {
        // Validate the input parameters: `_amountOfCollateral` must be greater than zero,
        // and `_tokenCollateralAddress` must have a valid price feed (non-zero address).
        Validator._valueMoreThanZero(
            _amountOfCollateral,
            _tokenCollateralAddress,
            msg.value
        );
        Validator._isTokenAllowed(
            _appStorage.s_priceFeeds[_tokenCollateralAddress]
        );

        // Determine if the collateral is the native token
        bool _isNativeToken = _tokenCollateralAddress == Constants.NATIVE_TOKEN;

        // Set `_amountOfCollateral` to `msg.value` if it's a native token
        if (_isNativeToken) {
            _amountOfCollateral = msg.value;
        }
        // Transfer ERC-20 tokens from the sender to the contract if not the native token
        if (!_isNativeToken) {
            IERC20(_tokenCollateralAddress).safeTransferFrom(
                _user,
                address(this),
                _amountOfCollateral
            );
        }

        // Update the user's collateral and available balance in storage
        _appStorage.s_addressToCollateralDeposited[_user][
            _tokenCollateralAddress
        ] += _amountOfCollateral;
        _appStorage.s_addressToAvailableBalance[_user][
            _tokenCollateralAddress
        ] += _amountOfCollateral;

        // Emit an event for the collateral deposit
        emit CollateralDeposited(
            _user,
            _tokenCollateralAddress,
            _amountOfCollateral,
            _chainSelector
        );
    }

    /**
     * @dev Allows a user to withdraw a specified amount of collateral.
     * @param _tokenCollateralAddress The address of the collateral token to withdraw.
     * @param _amount The amount of collateral to withdraw.
     * @param _user The address of the user withdrawing the collateral.
     */
    function _withdrawCollateral(
        LibAppStorage.Layout storage _appStorage,
        address _tokenCollateralAddress,
        uint256 _amount,
        address _user,
        uint64 _chainSelector
    ) internal {
        // Validate that the token is allowed and the amount is greater than zero
        Validator._isTokenAllowed(
            _appStorage.s_priceFeeds[_tokenCollateralAddress]
        );
        Validator._moreThanZero(_amount);

        // Retrieve the user's deposited amount for the specified token
        uint256 depositedAmount = _appStorage.s_addressToAvailableBalance[
            _user
        ][_tokenCollateralAddress];

        // Check if the user has sufficient collateral to withdraw the requested amount
        if (depositedAmount < _amount) {
            revert Protocol__InsufficientCollateralDeposited();
        }

        // Update storage to reflect the withdrawal of collateral
        _appStorage.s_addressToCollateralDeposited[_user][
            _tokenCollateralAddress
        ] -= _amount;
        _appStorage.s_addressToAvailableBalance[_user][
            _tokenCollateralAddress
        ] -= _amount;

        // Handle withdrawal for native token vs ERC20 tokens
        if (_tokenCollateralAddress == Constants.NATIVE_TOKEN) {
            // Transfer native token to the user
            (bool sent, ) = payable(_user).call{value: _amount}("");
            if (!sent) revert Protocol__TransferFailed();
        } else {
            // Transfer ERC20 token to the user
            IERC20(_tokenCollateralAddress).safeTransfer(_user, _amount);
        }

        // Emit an event indicating successful collateral withdrawal
        emit CollateralWithdrawn(
            _user,
            _tokenCollateralAddress,
            _amount,
            _chainSelector
        );
    }
}
