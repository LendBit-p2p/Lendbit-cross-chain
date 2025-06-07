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

    // lp

    /**
     * @notice Deposit tokens into the pool
     * @param token The address of the token to deposit
     * @param amount The amount of tokens to deposit
     * @return shares The amount of shares received
     */
    function deposit(
        address token,
        uint256 amount
    ) external payable returns (uint256 shares) {
        //TODO: // Currently Working on the Todo
        return 0;
    }

    /**
     * @notice Withdraw tokens from the pool
     * @param token The address of the token to withdraw
     * @param amount The amount of tokens to withdraw
     * @return amountWithdrawn The amount of tokens withdrawn
     */
    function withdraw(
        address token,
        uint256 amount
    ) external returns (uint256 amountWithdrawn) {
        //TODO: // Currently Working on the Todo
        return 0;
    }

    /**
     * @notice Borrow tokens from the pool
     * @param token The address of the token to borrow
     * @param amount The amount of tokens to borrow
     */
    function borrowFromPool(address token, uint256 amount) external {
        //TODO: // Currently Working on the Todo
    }

    /**
     * @notice Repay tokens to the pool
     * @param token The address of the token to repay
     * @param amount The amount of tokens to repay
     * @return amountRepaid The amount of tokens repaid
     */
    function repay(
        address token,
        uint256 amount
    ) external payable returns (uint256 amountRepaid) {
        //TODO: // Currently Working on the Todo
        return 0;
    }
}
