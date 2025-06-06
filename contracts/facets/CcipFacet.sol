// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Client} from "@chainlink/contracts-ccip/contracts/libraries/Client.sol";
import {CCIPReceiver} from "../utils/functions/CCIPReceiver.sol";
import {CCIPMessageReceived, CCIPMessageExecuted} from "../model/Event.sol";
import {CCIPMessageType} from "../model/Protocol.sol";
import {LibCCIP} from "../libraries/LibCCIP.sol";
import {LibAppStorage} from "../libraries/LibAppStorage.sol";

/**
 * @title CcipFacet
 * @notice This facet is responsible for handling CCIP messages.
 */
contract CcipFacet is CCIPReceiver {
    using LibCCIP for LibAppStorage.Layout;

    /**
     * @dev This function is called when a CCIP message is received.
     * @param message The CCIP message received.
     * message contains:
     * - messageId: The ID of the message.
     * - sourceChainSelector: The chain selector of the source chain.
     * - sender: The sender of the message.
     * - data: The data of the message.
     * - destTokenAmounts: The token amounts in the destination chain representation.
     */
    function _ccipReceive(
        Client.Any2EVMMessage memory message
    ) internal override {
        emit CCIPMessageReceived(
            message.messageId,
            message.sourceChainSelector,
            message.sender,
            message.destTokenAmounts
        );

        //decode the data
        (CCIPMessageType messageType, bytes memory messageData) = abi.decode(
            message.data,
            (CCIPMessageType, bytes)
        );

        _appStorage._resolveCCIPMessage(
            messageType,
            messageData,
            message.sourceChainSelector
        );

        emit CCIPMessageExecuted(
            message.messageId,
            message.sourceChainSelector,
            message.sender,
            message.destTokenAmounts
        );
    }
}
