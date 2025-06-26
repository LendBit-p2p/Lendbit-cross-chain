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
import {LibxLiquidityPool} from "./LibxLiquidityPool.sol";
import {LibxProtocol} from "./LibxProtocol.sol";

library LibCCIP {
    using LibxShared for LibAppStorage.Layout;
    using LibProtocol for LibAppStorage.Layout;
    using LibxLiquidityPool for LibAppStorage.Layout;
    using LibxProtocol for LibAppStorage.Layout;

    function _resolveCCIPMessage(
        LibAppStorage.Layout storage _appStorage,
        CCIPMessageType _messageType,
        bytes memory _messageData,
        uint64 _sourceChainSelector,
        Client.EVMTokenAmount[] memory _destTokenAmounts
    ) internal {
        // deposit the token to the liquidity pool
        // LP
        if (_messageType == CCIPMessageType.DEPOSIT) {
            //decode the data
            (bool isNative, uint256 _amount, address _user) = abi.decode(_messageData, (bool, uint256, address));

            if (isNative) {
                //unwrap wrapped version of the native token
                IWERC20(_destTokenAmounts[0].token).withdraw(_destTokenAmounts[0].amount);

                _appStorage._deposit(Constants.NATIVE_TOKEN, _destTokenAmounts[0].amount, _user, _sourceChainSelector);
            } else {
                _appStorage._deposit(
                    _destTokenAmounts[0].token, _destTokenAmounts[0].amount, _user, _sourceChainSelector
                );
            }
        }
        if (_messageType == CCIPMessageType.WITHDRAW) {
            //decode the data
            (address _token, uint256 _amount, address _user) = abi.decode(_messageData, (address, uint256, address));

            // withdraw the token from the liquidity pool
            _appStorage._withdraw(_token, _amount, _user, _sourceChainSelector);
        }
        if (_messageType == CCIPMessageType.BORROW) {
            //decode the data
            (address _token, uint256 _amount, address _user) = abi.decode(_messageData, (address, uint256, address));
            _appStorage._borrowFromPool(_token, _amount, _user, _sourceChainSelector);

            // borrow the token from the liquidity pool
        }

        if (_messageType == CCIPMessageType.REPAY) {
            //decode the data
            (bool isNative, address _token, address _user, uint256 _amount) =
                abi.decode(_messageData, (bool, address, address, uint256));

            if (isNative) {
                //unwrap wrapped version of the native token
                IWERC20(_destTokenAmounts[0].token).withdraw(_destTokenAmounts[0].amount);

                _appStorage._repay(Constants.NATIVE_TOKEN, _destTokenAmounts[0].amount, _user, _sourceChainSelector);
            } else {
                _appStorage._repay(_destTokenAmounts[0].token, _destTokenAmounts[0].amount, _user, _sourceChainSelector);
            }
            // repay the token to the liquidity pool
        }
        // P2P
        if (_messageType == CCIPMessageType.CREATE_LISTING) {
            //decode the data
            (
                address _sender,
                address _token,
                uint256 _amount,
                uint256 _minAmount,
                uint256 _maxAmount,
                uint16 _interestRate,
                uint256 _duration,
                address[] memory _whitelistedUsers
            ) = abi.decode(_messageData, (address, address, uint256, uint256, uint256, uint16, uint256, address[]));

            // create the listing
            _appStorage._createLoanListing(
                _sender,
                _token,
                _amount,
                _minAmount,
                _maxAmount,
                _interestRate,
                _duration,
                _whitelistedUsers,
                _sourceChainSelector
            );
        }
        if (_messageType == CCIPMessageType.CREATE_REQUEST) {
            //decode the data
            (uint256 _amount, uint16 _interestRate, uint256 _duration, address _token, address _user) =
                abi.decode(_messageData, (uint256, uint16, uint256, address, address));

            // create the request
            _appStorage._createLendingRequest(_amount, _interestRate, _duration, _token, _sourceChainSelector, _user);
        }
        if (_messageType == CCIPMessageType.SERVICE_REQUEST) {
            //decode the data
            (uint96 _requestId, bool _isNative, address _user) = abi.decode(_messageData, (uint96, bool, address));

            // service the request
            _appStorage._serviceLendingRequest(
                _requestId, _destTokenAmounts[0].token, _destTokenAmounts[0].amount, _isNative, _user
            );
        }
        if (_messageType == CCIPMessageType.BORROW_FROM_LISTING) {
            //decode the data
            (address _user, uint96 _listingId, uint256 _amount) = abi.decode(_messageData, (address, uint96, uint256));

            _appStorage._requestLoanFromListing(_user, _listingId, _amount, _sourceChainSelector);
        }
        if (_messageType == CCIPMessageType.REPAY_LOAN) {
            //decode the data
            (uint96 _requestId, uint256 _amount, address _user) = abi.decode(_messageData, (uint96, uint256, address));

            _appStorage._repayLoan(_user, _requestId, _amount, _sourceChainSelector);
        }

        // Shared
        if (_messageType == CCIPMessageType.DEPOSIT_COLLATERAL) {
            //decode the data
            (bool isNative, address _user) = abi.decode(_messageData, (bool, address));

            if (isNative) {
                //unwrap wrapped version of the native token
                IWERC20(_destTokenAmounts[0].token).withdraw(_destTokenAmounts[0].amount);

                _appStorage._depositCollateral(
                    Constants.NATIVE_TOKEN, _destTokenAmounts[0].amount, _user, _sourceChainSelector
                );
            } else {
                _appStorage._depositCollateral(
                    _destTokenAmounts[0].token, _destTokenAmounts[0].amount, _user, _sourceChainSelector
                );
            }
        }
        if (_messageType == CCIPMessageType.DEPOSIT_COLLATERAL_NOT_INTERPROABLE) {
            (address _user, address _token, uint256 _amount) = abi.decode(_messageData, (address, address, uint256));
            _appStorage._depositCollateral(_token, _amount, _user, _sourceChainSelector);
        }

        if (_messageType == CCIPMessageType.WITHDRAW_COLLATERAL) {
            //decode the data
            (address _token, uint256 _amount, address _user) = abi.decode(_messageData, (address, uint256, address));
            _appStorage._withdrawCollateral(_token, _amount, _user, _sourceChainSelector);
        }

        if (_messageType == CCIPMessageType.WITHDRAW_COLLATERAL_NOT_INTERPOLABLE) {
            (address _user, address _token, uint256 _amount) = abi.decode(_messageData, (address, address, uint256));
            _appStorage._withdrawReleaseCollateral(_user, _token, _amount, _sourceChainSelector);
        }

        if (_messageType == CCIPMessageType.CLOSE_REQUEST) {
            //decode the data
            (uint96 _requestId, address _user) = abi.decode(_messageData, (uint96, address));

            // close the request
            _appStorage._closeRequest(_user, _requestId);
        }

        if (_messageType == CCIPMessageType.CLOSE_LISTING) {
            //decode the data
            (uint96 _listingId, address _user) = abi.decode(_messageData, (uint96, address));

            // close the request
            _appStorage._closeListingAd(_user, _listingId);
        }
    }

    /**
     * @notice Sends tokens cross-chain via CCIP with actual token transfer
     * @dev This function physically transfers tokens from source to destination chain
     * @param _receiver The address of the receiver contract on destination chain
     * @param _isNative Whether the token being sent is the native token (ETH/MATIC etc.)
     * @param _destTokenAmounts Array of tokens and amounts to send cross-chain
     * @param _destChainSelector The CCIP chain selector for the destination chain
     * @param _user The end user who will receive the tokens on destination chain
     * @return messageId The CCIP message ID for tracking the cross-chain transfer
     */
    function _sendTokenCrosschain(
        address _receiver,
        bool _isNative,
        Client.EVMTokenAmount[] memory _destTokenAmounts,
        uint64 _destChainSelector,
        address _user
    ) internal returns (bytes32) {
        bytes memory data = abi.encode(_user, _isNative, _destTokenAmounts, false);

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(_receiver),
            data: data,
            tokenAmounts: _destTokenAmounts,
            extraArgs: Client._argsToBytes(Client.GenericExtraArgsV2({gasLimit: 200_000, allowOutOfOrderExecution: true})),
            feeToken: Constants.LINK
        });

        uint256 fee = IRouterClient(Constants.CCIP_ROUTER).getFee(_destChainSelector, message);

        IERC20(Constants.LINK).approve(Constants.CCIP_ROUTER, fee);

        bytes32 messageId = IRouterClient(Constants.CCIP_ROUTER).ccipSend(_destChainSelector, message);

        return messageId;
    }

    /**
     * @notice Notifies destination chain to release tokens from local storage
     * @dev This function sends a message without transferring tokens - destination releases stored tokens
     * @param _receiver The address of the receiver contract on destination chain
     * @param _user The end user who will receive the released tokens
     * @param _tokenAddressToRelease The token contract address on destination chain to release
     * @param _tokenAmountToRelease The amount of tokens to release from destination storage
     * @param _destChainSelector The CCIP chain selector for the destination chain
     * @return messageId The CCIP message ID for tracking
     * @return releaseTokenAmounts The token amounts that should be released on destination
     */
    function _notifyCrossChainTokenRelease(
        address _receiver,
        address _user,
        address _tokenAddressToRelease,
        uint256 _tokenAmountToRelease,
        uint64 _destChainSelector
    ) internal returns (bytes32, Client.EVMTokenAmount[] memory) {
        //encode token and amount release message cross-chain
        Client.EVMTokenAmount[] memory releaseTokenAmounts = new Client.EVMTokenAmount[](1);
        releaseTokenAmounts[0] = Client.EVMTokenAmount({token: _tokenAddressToRelease, amount: _tokenAmountToRelease});

        bytes memory data = abi.encode(_user, false, releaseTokenAmounts, true);

        Client.EVMTokenAmount[] memory emptyTokenAmounts = new Client.EVMTokenAmount[](0);

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(_receiver),
            data: data,
            tokenAmounts: emptyTokenAmounts,
            extraArgs: Client._argsToBytes(Client.GenericExtraArgsV2({gasLimit: 200_000, allowOutOfOrderExecution: true})),
            feeToken: Constants.LINK
        });

        uint256 fee = IRouterClient(Constants.CCIP_ROUTER).getFee(_destChainSelector, message);
        IERC20(Constants.LINK).approve(Constants.CCIP_ROUTER, fee);
        bytes32 messageId = IRouterClient(Constants.CCIP_ROUTER).ccipSend(_destChainSelector, message);

        return (messageId, releaseTokenAmounts);
    }
}
