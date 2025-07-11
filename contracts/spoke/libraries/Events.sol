// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Client} from "@chainlink/contract-ccip/contracts/libraries/Client.sol";

event CCIPMessageSent(
    bytes32 indexed messageId,
    uint64 indexed sourceChainSelector,
    address indexed sender,
    Client.EVMTokenAmount[] destTokenAmounts
);

event CCIPMessageFailed(
    bytes32 indexed messageId,
    uint64 indexed sourceChainSelector,
    bytes indexed sender,
    Client.EVMTokenAmount[] destTokenAmounts
);

event CCIPMessageExecuted(
    bytes32 indexed messageId,
    uint64 indexed sourceChainSelector,
    address indexed receiver,
    Client.EVMTokenAmount[] destTokenAmounts
);

event CollateralDeposited(address indexed sender, address indexed _token, uint256 indexed _amount);
