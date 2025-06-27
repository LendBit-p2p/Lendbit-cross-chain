// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../libraries/LibLiquidityPool.sol";
import "../libraries/LibAppStorage.sol";
import "../utils/functions/AppStorage.sol";
// import "../utils/constants/Constant.sol";
// import {LibGettersImpl} from "../libraries/LibGetters.sol";
// import {LibInterestAccure} from "../libraries/LibInterestAccure.sol";
// import {LibInterestRateModel} from "../libraries/LibInterestRateModel.sol";
// import {ProtocolPool, TokenData, UserBorrowData} from "../model/Protocol.sol";
// import {LibGettersImpl} from "../libraries/LibGetters.sol";
import {LibVaultNotifications} from "../libraries/LibVaultNotifications.sol";

// import {VTokenVault} from "../vaults/VTokenVault.sol";

/**
 * @title LiquidityPoolFacet
 * @notice This facet provides functions for interacting with liquidity pools.
 * @dev All state-changing operations are delegated to LibLiquidityPool
 */
contract LiquidityPoolFacet is AppStorage {
    using LibLiquidityPool for LibAppStorage.Layout;
    using LibVaultNotifications for LibAppStorage.Layout;

    /**
     * @notice Allows users to deposit tokens into the liquidity pool
     * @dev Handles both native token (ETH) and ERC20 deposits
     * @param token The address of the token to deposit
     * @param amount The amount of tokens to deposit
     * @return shares The number of LP shares minted for the deposit
     * Requirements:
     * - Pool must be initialized and active
     * - Token must be supported for lending
     * - Amount must be greater than zero
     *
     * Emits a `Deposit` event on successful deposit.
     */
    function deposit(address token, uint256 amount) external payable returns (uint256 shares) {
        return _appStorage._deposit(token, amount, msg.sender, Constants.CHAIN_SELECTOR);
    }

    /**
     * @notice Allows users to borrow tokens from the liquidity pool
     * @param token The address of the token to borrow
     * @param amount The amount of tokens to borrow
     *
     * Requirements:
     * - Pool must be initialized and active
     * - Token must be supported for lending
     * - Amount must be greater than zero
     * - User must have sufficient collateral
     * - Pool must have sufficient liquidity
     *
     * Emits a `Borrow` event on successful borrow.
     */
    function borrowFromPool(address token, uint256 amount) external {
        _appStorage._borrowFromPool(token, amount, msg.sender, Constants.CHAIN_SELECTOR);
    }

    /**
     * @notice Allows users to repay their borrowed tokens
     * @param token The address of the token to repay
     * @param amount The amount to repay, use type(uint256).max to repay full debt
     * @return amountRepaid The actual amount repaid
     *
     * Requirements:
     * - Pool must be initialized
     * - Token must be supported for lending
     * - Amount must be greater than zero
     * - User must have an active borrow
     *
     * Emits a `Repay` event on successful repayment.
     */
    function repay(address token, uint256 amount) external payable returns (uint256 amountRepaid) {
        return _appStorage._repay(token, amount, msg.sender, Constants.CHAIN_SELECTOR);
    }

    /**
     * @notice Allows users to withdraw tokens from the liquidity pool
     * @param token The address of the token to withdraw
     * @param amount The amount of token to withdraw and burn corresponding shares
     * @return amountWithdrawn The actual amount of tokens withdrawn
     *
     * Requirements:
     * - Pool must be initialized
     * - Token must be supported for lending
     * - Amount must be greater than zero
     * - User must have sufficient shares
     * - Pool must have sufficient liquidity
     *
     * Emits a `Withdraw` event on successful withdrawal.
     */
    function withdraw(address token, uint256 amount) external returns (uint256 amountWithdrawn) {
        return _appStorage._withdraw(token, amount, msg.sender, Constants.CHAIN_SELECTOR);
    }

    ////////////////////
    ///VAULT ////////////
    ///////////////////

    /**
     * @notice External function called by vaults when deposits occur
     * @param asset Token deposited
     * @param amount Amount deposited
     * @param depositor Address of the depositor
     * @param transferAssets Whether to transfer assets
     * @return shares Number of shares minted
     */
    function notifyVaultDeposit(address asset, uint256 amount, address depositor, bool transferAssets)
        external
        returns (uint256 shares)
    {
        return _appStorage.notifyVaultDeposit(asset, amount, depositor, transferAssets);
    }

    /**
     * @notice External function called by vaults when withdrawals occur
     * @param asset Token withdrawn
     * @param shares Shares being burned
     * @param receiver Address receiving tokens
     * @param transferAssets Whether to transfer assets
     * @return amount Actual amount withdrawn
     */
    function notifyVaultWithdrawal(address asset, uint256 shares, address receiver, bool transferAssets)
        external
        returns (uint256 amount)
    {
        return _appStorage.notifyVaultWithdrawal(asset, shares, receiver, transferAssets);
    }

    /**
     * @notice External function called by vaults when transfers occur
     * @param asset Token being transferred
     * @param shares Amount of shares transferred
     * @param sender Address sending shares
     * @param receiver Address receiving shares
     * @return success Whether transfer was successful
     */
    function notifyVaultTransfer(address asset, uint256 shares, address sender, address receiver)
        external
        returns (bool success)
    {
        return _appStorage.notifyVaultTransfer(asset, shares, sender, receiver);
    }
}
