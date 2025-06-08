// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {IAny2EVMMessageReceiver} from "@chainlink/contract-ccip/contracts/interfaces/IAny2EVMMessageReceiver.sol";

import {Client} from "@chainlink/contract-ccip/contracts/libraries/Client.sol";

import {Constants} from "../constants/Constant.sol";
import {AppStorage} from "./AppStorage.sol";

/** This Code was taken from the Chainlink CCIP repo with some modifications */
/// @title CCIPReceiver - Base contract for CCIP applications that can receive messages.
abstract contract CCIPReceiver is AppStorage, IAny2EVMMessageReceiver {
    /// @inheritdoc IAny2EVMMessageReceiver
    function ccipReceive(
        Client.Any2EVMMessage calldata message
    )
        external
        virtual
        override
        onlyRouter
        onlySupportedChain(
            message.sourceChainSelector,
            message.sender,
            message.messageId
        )
    {
        _ccipReceive(message);
    }

    /// @notice Override this function in your implementation.
    /// @param message Any2EVMMessage.
    function _ccipReceive(
        Client.Any2EVMMessage memory message
    ) internal virtual;

    /// @notice Return the current router
    /// @return CCIP router address
    function getRouter() public view virtual returns (address) {
        return address(Constants.CCIP_ROUTER);
    }

    error InvalidRouter(address router);
    error ChainSelectorNotSupported(uint64 chainSelector);
    error SenderNotSupported(address sender);
    error MessageAlreadyConsumed(bytes32 messageId);

    /// @dev only calls from the set router are accepted.
    modifier onlyRouter() {
        if (msg.sender != getRouter()) revert InvalidRouter(msg.sender);
        _;
    }

    /// @dev only calls from the supported chain and sender are accepted.
    modifier onlySupportedChain(
        uint64 _chainSelector,
        bytes calldata _sender,
        bytes32 _messageId
    ) {
        address sender = abi.decode(_sender, (address));

        if (!_appStorage.s_chainSelectorSupported[_chainSelector])
            revert ChainSelectorNotSupported(_chainSelector);
        if (_appStorage.s_senderSupported[_chainSelector] != sender)
            revert SenderNotSupported(sender);
        if (_appStorage.s_messageConsumed[_messageId])
            revert MessageAlreadyConsumed(_messageId);
        _;
    }
}
