// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/CCIPReceiver.sol";

contract CcipFacet is AppStorage, CCIPReceiver, CCIPSender {}
