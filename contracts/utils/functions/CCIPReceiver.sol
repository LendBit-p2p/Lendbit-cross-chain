// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {IAny2EVMMessageReceiver} from "@chainlink/contracts-ccip/contracts/interfaces/IAny2EVMMessageReceiver.sol";

import {Client} from "@chainlink/contracts-ccip/contracts/libraries/Client.sol";

import {IERC165} from "@chainlink/contracts/src/v0.8/vendor/openzeppelin-solidity/v5.0.2/contracts/utils/introspection/IERC165.sol";
import {Constants} from "../constants/Constant.sol";
import {AppStorage} from "./AppStorage.sol";

/** This Code was taken from the Chainlink CCIP repo with some modifications */
/// @title CCIPReceiver - Base contract for CCIP applications that can receive messages.
abstract contract CCIPReceiver is AppStorage, IAny2EVMMessageReceiver, IERC165 {
    /// @notice IERC165 supports an interfaceId.
    /// @param interfaceId The interfaceId to check.
    /// @return true if the interfaceId is supported.
    /// @dev Should indicate whether the contract implements IAny2EVMMessageReceiver.
    /// e.g. return interfaceId == type(IAny2EVMMessageReceiver).interfaceId || interfaceId == type(IERC165).interfaceId
    /// This allows CCIP to check if ccipReceive is available before calling it.
    /// - If this returns false or reverts, only tokens are transferred to the receiver.
    /// - If this returns true, tokens are transferred and ccipReceive is called atomically.
    /// Additionally, if the receiver address does not have code associated with it at the time of
    /// execution (EXTCODESIZE returns 0), only tokens will be transferred.
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override returns (bool) {
        return
            interfaceId == type(IAny2EVMMessageReceiver).interfaceId ||
            interfaceId == type(IERC165).interfaceId;
    }

    /// @inheritdoc IAny2EVMMessageReceiver
    function ccipReceive(
        Client.Any2EVMMessage calldata message
    )
        external
        virtual
        override
        onlyRouter
        onlySupportedChain(message.sourceChainSelector, message.sender)
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

    /// @dev only calls from the set router are accepted.
    modifier onlyRouter() {
        if (msg.sender != getRouter()) revert InvalidRouter(msg.sender);
        _;
    }

    /// @dev only calls from the supported chain and sender are accepted.
    modifier onlySupportedChain(uint64 _chainSelector, bytes calldata _sender) {
        address sender = abi.decode(_sender, (address));

        if (!_appStorage.s_chainSelectorSupported[_chainSelector])
            revert ChainSelectorNotSupported(_chainSelector);
        if (_appStorage.s_senderSupported[_chainSelector] != sender)
            revert SenderNotSupported(sender);
        _;
    }
}
