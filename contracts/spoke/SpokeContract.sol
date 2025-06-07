// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {IERC20} from "@chainlink/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@chainlink/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/utils/SafeERC20.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/contracts/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/contracts/libraries/Client.sol";

contract SpokeContract {
    address immutable i_hub;
    uint64 immutable i_chainSelector;
    LinkTokenInterface immutable i_link;
    IRouterClient immutable i_router;

    constructor(
        address _hub,
        uint64 _chainSelector,
        address _link,
        address _router
    ) {
        i_hub = _hub;
        i_chainSelector = _chainSelector;
        i_link = LinkTokenInterface(_link);
        i_router = IRouterClient(_router);

        i_link.approve(address(i_router), type(uint256).max);
    }
}
