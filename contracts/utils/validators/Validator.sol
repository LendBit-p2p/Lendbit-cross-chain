// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.9;

import "./Error.sol";
import "../constants/Constant.sol";
import "../../model/Protocol.sol";

/**
 * @title Validator
 * @dev A library for common validation functions used across the protocol.
 *      Contains checks for zero values, token allowance, bot access, and native token balance requirements.
 */
library Validator {
    /**
     * @dev Ensures that a given amount is greater than zero.
     *
     * @param _amount The amount to validate.
     *
     * @notice Reverts with `Protocol__MustBeMoreThanZero` if `_amount` is zero.
     */
    function _moreThanZero(uint256 _amount) internal pure {
        if (_amount == 0) {
            revert Protocol__MustBeMoreThanZero();
        }
    }

    /**
     * @dev Validates that a token is allowed by checking if its price feed address is non-zero.
     *
     * @param _priceFeeds The address of the token's price feed.
     *
     * @notice Reverts with `Protocol__TokenNotAllowed` if `_priceFeeds` is the zero address.
     */
    function _isTokenAllowed(address _priceFeeds) internal pure {
        if (_priceFeeds == address(0)) {
            revert Protocol__TokenNotAllowed();
        }
    }

    /**
     * @dev Ensures that when interacting with the native token, a non-zero `_value` is provided.
     *
     * @param _token The address of the token (can be the native token).
     * @param _value The value associated with the native token transaction.
     *
     * @notice Reverts with `Protocol__MustBeMoreThanZero` if `_token` is the native token and `_value` is zero.
     */
    function _nativeMoreThanZero(address _token, uint256 _value) internal pure {
        if (_token == Constants.NATIVE_TOKEN && _value == 0) {
            revert Protocol__MustBeMoreThanZero();
        }
    }

    /**
     * @dev Restricts access to a function to a specific bot address.
     *
     * @param _botAddress The designated bot address that is allowed access.
     * @param _sender The address of the entity attempting to access the function.
     *
     * @notice Reverts with `Protocol__OnlyBotCanAccess` if `_sender` is not the `_botAddress`.
     */
    function _onlyBot(address _botAddress, address _sender) internal pure {
        if (_botAddress != _sender) {
            revert Protocol__OnlyBotCanAccess();
        }
    }

    /**
     * @dev Ensures that a given amount is non-zero and, if interacting with the native token, that a non-zero `_value` is provided.
     *
     * @param _amount The amount to validate.
     * @param _token The address of the token (can be the native token).
     * @param _value The value associated with the native token transaction.
     *
     * @notice Reverts with `Protocol__MustBeMoreThanZero` if `_amount` is zero, or if `_token` is the native token and `_value` is zero.
     */
    function _valueMoreThanZero(uint256 _amount, address _token, uint256 _value) internal pure {
        if (_amount == 0) {
            revert Protocol__MustBeMoreThanZero();
        }
        if (_token == Constants.NATIVE_TOKEN && _value == 0) {
            revert Protocol__MustBeMoreThanZero();
        }
    }

    /**
     * @dev Validates the address is whitelisted by checking if the address is present in the whitelist.
     *
     * @param _listing The listing object containing the whitelist.
     *
     * @notice Reverts with `Protocol__NotWhitelisted` if the sender's address is not in the whitelist.
     */
    function _addressIsWhitelisted(LoanListing storage _listing) internal view {
        address[] memory _whitelist = _listing.whitelist;
        if (_whitelist.length == 0) {
            return;
        }
        for (uint256 i = 0; i < _whitelist.length; i++) {
            if (_whitelist[i] == msg.sender) {
                return;
            }
        }
        revert Protocol__NotWhitelisted();
    }
}
