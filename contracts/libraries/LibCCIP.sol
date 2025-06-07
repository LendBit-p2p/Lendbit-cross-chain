// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Client} from "@chainlink/contracts-ccip/contracts/libraries/Client.sol";
import {LibShared} from "./LibShared.sol";
import {LibProtocol} from "./LibProtocol.sol";
import {CCIPMessageType} from "../model/Protocol.sol";
import {LibAppStorage} from "./LibAppStorage.sol";
import {LibLiquidityPool} from "../libraries/LibLiquidityPool.sol";


library LibCCIP {
    using LibShared for LibAppStorage.Layout;
    using LibProtocol for LibAppStorage.Layout;
    using LibLiquidityPool for LibAppStorage.Layout;

    function _resolveCCIPMessage(
        LibAppStorage.Layout storage _appStorage,
        CCIPMessageType _messageType,
        bytes memory _messageData,
        uint64 _sourceChainSelector
    ) internal {
        //handle the message based on the type
        // LP
        if (_messageType == CCIPMessageType.DEPOSIT) {
            //decode the data
            (address _token, address _user, uint256 _amount) = abi.decode(_messageData, (address, address, uint256));
            _appStorage._deposit(_appStorage, _token, _amount, _user);
            // deposit the token to the liquidity pool
        }
        if (_messageType == CCIPMessageType.WITHDRAW) {
            //decode the data
            (address _token, uint256 _amount) = abi.decode(_messageData, (address, uint256));

            // withdraw the token from the liquidity pool
        }
        if (_messageType == CCIPMessageType.BORROW) {
            //decode the data
            (address _token, uint256 _amount) = abi.decode(_messageData, (address, uint256));

            // borrow the token from the liquidity pool
        }
        if (_messageType == CCIPMessageType.REPAY) {
            //decode the data
            (address _token, uint256 _amount) = abi.decode(_messageData, (address, uint256));

            // repay the token to the liquidity pool
        }
        // P2P
        if (_messageType == CCIPMessageType.CREATE_LISTING) {
            //decode the data
            (address token, uint256 amount, uint256 interestRate, uint256 duration, address[] memory whitelistedTokens)
            = abi.decode(_messageData, (address, uint256, uint256, uint256, address[]));

            // create the listing
        }
        if (_messageType == CCIPMessageType.CREATE_REQUEST) {
            //decode the data
            (address token, uint256 amount, uint256 interestRate, uint256 duration) =
                abi.decode(_messageData, (address, uint256, uint256, uint256));

            // create the request
        }
        if (_messageType == CCIPMessageType.SERVICE_REQUEST) {
            //decode the data
            (address _token, uint256 _amount, uint96 _requestId) = abi.decode(_messageData, (address, uint256, uint96));
        }
        if (_messageType == CCIPMessageType.BORROW_FROM_LISTING) {
            //decode the data
            (address _token, uint256 _amount, address _user) = abi.decode(_messageData, (address, uint256, address));
        }
        if (_messageType == CCIPMessageType.REPAY_LOAN) {
            //decode the data
            (address _token, uint256 _amount, address _user) = abi.decode(_messageData, (address, uint256, address));
        }

        // Shared
        if (_messageType == CCIPMessageType.DEPOSIT_COLLATERAL) {
            //decode the data
            (address _token, uint256 _amount, address _user) = abi.decode(_messageData, (address, uint256, address));
            _appStorage._depositCollateral(_token, _amount, _user, _sourceChainSelector);
        }
        if (_messageType == CCIPMessageType.WITHDRAW_COLLATERAL) {
            //decode the data
            (address _token, uint256 _amount, address _user) = abi.decode(_messageData, (address, uint256, address));
            _appStorage._withdrawCollateral(_token, _amount, _user, _sourceChainSelector);
        }
    }
}
