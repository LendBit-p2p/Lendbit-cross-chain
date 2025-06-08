// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../model/Protocol.sol";
import "../../model/Event.sol";
import "../../utils/validators/Error.sol";
import "../../utils/validators/Validator.sol";
import "../../utils/constants/Constant.sol";
import "../LibAppStorage.sol";
import {LibGettersImpl} from "../LibGetters.sol";
import {IWERC20} from "@chainlink/contracts/src/v0.8/shared/interfaces/IWERC20.sol";
import {Client} from "@chainlink/contract-ccip/contracts/libraries/Client.sol";
import {LibCCIP} from "./LibCCIP.sol";

library LibxShared {
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

        Client.EVMTokenAmount[]
            memory tokensToSendDetails = new Client.EVMTokenAmount[](1);
        tokensToSendDetails[0] = Client.EVMTokenAmount({
            token: _tokenCollateralAddress == Constants.NATIVE_TOKEN
                ? Constants.WETH
                : _tokenCollateralAddress,
            amount: _amount
        });

        // Handle withdrawal for native token vs ERC20 tokens
        if (_tokenCollateralAddress == Constants.NATIVE_TOKEN) {
            // Transfer native token to the user
            IWERC20(Constants.WETH).deposit{value: _amount}();
            IERC20(Constants.WETH).approve(Constants.CCIP_ROUTER, _amount);
        } else {
            IERC20(_tokenCollateralAddress).approve(
                Constants.CCIP_ROUTER,
                _amount
            );
        }

        //Handle Sending Of Token Crosschain.
        bytes32 messageId = LibCCIP._sendTokenCrosschain(
            _appStorage.s_senderSupported[_chainSelector],
            _tokenCollateralAddress == Constants.NATIVE_TOKEN,
            tokensToSendDetails,
            _chainSelector,
            _user
        );

        emit CCIPMessageSent(
            messageId,
            _chainSelector,
            abi.encode(_user),
            tokensToSendDetails
        );

        // Emit an event indicating successful collateral withdrawal
        emit CollateralWithdrawn(
            _user,
            _tokenCollateralAddress,
            _amount,
            _chainSelector
        );
    }
}
