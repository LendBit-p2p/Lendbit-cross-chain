// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {LibGettersImpl} from "../LibGetters.sol";
import {Utils} from "../../utils/functions/Utils.sol";
import "../../model/Protocol.sol";
import "../../model/Event.sol";
import "../../utils/validators/Error.sol";
import "../../utils/validators/Validator.sol";
import "../../utils/constants/Constant.sol";
import "../LibAppStorage.sol";

library LibxProtocol {
    using SafeERC20 for IERC20;

    function _serviceLendingRequest(
        AppStorage storage _appStorage,
        uint96 _requestId,
        bool _isNative,
        address _user
    ) internal {
        //TODO: Implement the logic to service the lending request
    }
}
