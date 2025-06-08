// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Client} from "@chainlink/contract-ccip/contracts/libraries/Client.sol";
import {LibProtocol} from "../LibProtocol.sol";
import {CCIPMessageType} from "../../model/Protocol.sol";
import {LibAppStorage} from "../LibAppStorage.sol";
import {IRouterClient} from "@chainlink/contract-ccip/contracts/interfaces/IRouterClient.sol";
import {IWERC20} from "@chainlink/contracts/src/v0.8/shared/interfaces/IWERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Constants} from "../../utils/constants/Constant.sol";
import {LibxShared} from "./LibxShared.sol";

library LibCCIP {
    using LibxShared for LibAppStorage.Layout;
    using LibProtocol for LibAppStorage.Layout;

    function _resolveCCIPMessage(
        LibAppStorage.Layout storage _appStorage,
        CCIPMessageType _messageType,
        bytes memory _messageData,
        uint64 _sourceChainSelector,
        Client.EVMTokenAmount[] memory _destTokenAmounts
    ) internal {
        //handle the message based on the type
        // LP
        if (_messageType == CCIPMessageType.DEPOSIT) {
            //decode the data
            (address _token, uint256 _amount) = abi.decode(
                _messageData,
                (address, uint256)
            );

            // deposit the token to the liquidity pool
        }
        if (_messageType == CCIPMessageType.WITHDRAW) {
            //decode the data
            (address _token, uint256 _amount) = abi.decode(
                _messageData,
                (address, uint256)
            );

            // withdraw the token from the liquidity pool
        }
        if (_messageType == CCIPMessageType.BORROW) {
            //decode the data
            (address _token, uint256 _amount) = abi.decode(
                _messageData,
                (address, uint256)
            );

            // borrow the token from the liquidity pool
        }
        if (_messageType == CCIPMessageType.REPAY) {
            //decode the data
            (address _token, uint256 _amount) = abi.decode(
                _messageData,
                (address, uint256)
            );

            // repay the token to the liquidity pool
        }
        // P2P
        if (_messageType == CCIPMessageType.CREATE_LISTING) {
            //decode the data
            (
                address token,
                uint256 amount,
                uint256 interestRate,
                uint256 duration,
                address[] memory whitelistedTokens
            ) = abi.decode(
                    _messageData,
                    (address, uint256, uint256, uint256, address[])
                );

            // create the listing
        }
        if (_messageType == CCIPMessageType.CREATE_REQUEST) {
            //decode the data
            (
                address token,
                uint256 amount,
                uint256 interestRate,
                uint256 duration
            ) = abi.decode(_messageData, (address, uint256, uint256, uint256));

            // create the request
        }
        if (_messageType == CCIPMessageType.SERVICE_REQUEST) {
            //decode the data
            (address _token, uint256 _amount, uint96 _requestId) = abi.decode(
                _messageData,
                (address, uint256, uint96)
            );
        }
        if (_messageType == CCIPMessageType.BORROW_FROM_LISTING) {
            //decode the data
            (address _token, uint256 _amount, address _user) = abi.decode(
                _messageData,
                (address, uint256, address)
            );
        }
        if (_messageType == CCIPMessageType.REPAY_LOAN) {
            //decode the data
            (address _token, uint256 _amount, address _user) = abi.decode(
                _messageData,
                (address, uint256, address)
            );
        }

        // Shared
        if (_messageType == CCIPMessageType.DEPOSIT_COLLATERAL) {
            //decode the data
            (bool isNative, address _user) = abi.decode(
                _messageData,
                (bool, address)
            );

            if (isNative) {
                //unwrap wrapped version of the native token
                IWERC20(_destTokenAmounts[0].token).withdraw(
                    _destTokenAmounts[0].amount
                );

                _appStorage._depositCollateral(
                    Constants.NATIVE_TOKEN,
                    _destTokenAmounts[0].amount,
                    _user,
                    _sourceChainSelector
                );
            } else {
                _appStorage._depositCollateral(
                    _destTokenAmounts[0].token,
                    _destTokenAmounts[0].amount,
                    _user,
                    _sourceChainSelector
                );
            }
        }
        if (_messageType == CCIPMessageType.WITHDRAW_COLLATERAL) {
            //decode the data
            (address _token, uint256 _amount, address _user) = abi.decode(
                _messageData,
                (address, uint256, address)
            );
            _appStorage._withdrawCollateral(
                _token,
                _amount,
                _user,
                _sourceChainSelector
            );
        }
    }

    function _sendTokenCrosschain(
        address _receiver,
        bool _isNative,
        Client.EVMTokenAmount[] memory _destTokenAmounts,
        uint64 _destChainSelector,
        address _user
    ) internal returns (bytes32) {
        bytes memory data = abi.encode(_isNative, _destTokenAmounts, _user);

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(_receiver),
            data: data,
            tokenAmounts: _destTokenAmounts,
            extraArgs: Client._argsToBytes(
                Client.GenericExtraArgsV2({
                    gasLimit: 200_000,
                    allowOutOfOrderExecution: true
                })
            ),
            feeToken: Constants.LINK
        });

        uint256 fee = IRouterClient(Constants.CCIP_ROUTER).getFee(
            _destChainSelector,
            message
        );

        IERC20(Constants.LINK).approve(Constants.CCIP_ROUTER, fee);

        bytes32 messageId = IRouterClient(Constants.CCIP_ROUTER).ccipSend(
            _destChainSelector,
            message
        );

        return messageId;
    }
}
