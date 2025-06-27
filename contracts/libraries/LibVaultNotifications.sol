// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Utils} from "../utils/functions/Utils.sol";
import "./LibAppStorage.sol";
import {LibInterestAccure} from "./LibInterestAccure.sol";
import {IWeth} from "../interfaces/Iweth.sol";
import {ILendbitTokenVault} from "../interfaces/ILendbitTokenVault.sol";
import "../utils/constants/Constant.sol";
import "../utils/validators/Error.sol";
import "../model/Event.sol";

/**
 * @title Vault Notification Library
 * @notice Handles callbacks from VToken vaults with proper state management and exchange rate updates
 */
library LibVaultNotifications {
    using SafeERC20 for IERC20;

    /**
     * @notice Callback from VToken vault when deposit occurs
     * @param _appStorage The app storage layout
     * @param asset Token deposited
     * @param amount Amount deposited
     * @param depositor Address of the depositor
     * @param transferAssets Whether to transfer assets (false if already done)
     * @return shares The shares minted to the user
     */
    function notifyVaultDeposit(
        LibAppStorage.Layout storage _appStorage,
        address asset,
        uint256 amount,
        address depositor,
        bool transferAssets
    ) internal returns (uint256 shares) {
        // Verify caller is a valid vault
        if (_appStorage.s_vaults[asset] != msg.sender) {
            revert UnauthorizedVault();
        }

        if (amount == 0) revert ZeroAmount();
        if (depositor == address(0)) revert InvalidReceiver();

        // Update interest before calculating shares
        _updateInterestAndExchangeRate(_appStorage, asset);

        shares = Utils.convertToShares(_appStorage.s_tokenData[asset], amount);

        // Handle asset transfers
        if (transferAssets) {
            if (asset == Constants.NATIVE_TOKEN) {
                // For ETH deposits, ensure WETH is used internally
                IWeth(Constants.WETH).deposit{value: amount}();
                asset = Constants.WETH; // Use WETH for internal accounting
            } else {
                IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
            }
        }

        // Update protocol state
        TokenData storage tokenData = _appStorage.s_tokenData[asset];
        ProtocolPool storage protocolPool = _appStorage.s_protocolPool[asset];

        // Update user positions
        _appStorage.s_addressToUserPoolShare[depositor][asset] += shares;
        _appStorage.s_vaultDeposits[asset] += amount;

        // Update vault and pool state
        _appStorage.s_vaultDeposits[asset] += amount;
        tokenData.poolLiquidity += amount;
        tokenData.totalSupply += shares;
        protocolPool.totalSupply += shares;
        tokenData.lastUpdateTimestamp = block.timestamp;

        // Update exchange rate post-deposit
        _syncVaultExchangeRate(_appStorage, asset);

        emit VaultDeposited(asset, depositor, amount, shares);
    }

    /**
     * @notice Callback from VToken vault when withdrawal occurs
     * @param _appStorage The app storage layout
     * @param asset Token withdrawn
     * @param shares Shares being burned
     * @param receiver Address receiving the tokens
     * @param transferAssets Whether to transfer assets
     * @return amount The actual amount withdrawn
     */
    function notifyVaultWithdrawal(
        LibAppStorage.Layout storage _appStorage,
        address asset,
        uint256 shares,
        address receiver,
        bool transferAssets
    ) internal returns (uint256 amount) {
        // Verify caller is a valid vault
        if (_appStorage.s_vaults[asset] != msg.sender) {
            revert UnauthorizedVault();
        }

        if (shares == 0) revert ZeroAmount();
        if (receiver == address(0)) revert InvalidReceiver();

        // Update interest before calculating amount
        _updateInterestAndExchangeRate(_appStorage, asset);

        // Calculate amount based on current exchange rate
        amount = Utils.convertToAmount(_appStorage.s_tokenData[asset], shares);

        TokenData storage tokenData = _appStorage.s_tokenData[asset];

        // Ensure sufficient liquidity
        if (tokenData.poolLiquidity < amount) revert InsufficientLiquidity();

        // Ensure user has enough shares
        if (_appStorage.s_addressToUserPoolShare[receiver][asset] < shares) {
            revert InsufficientShares();
        }

        // Update user positions
        _appStorage.s_addressToUserPoolShare[receiver][asset] -= shares;
        _appStorage.s_vaultDeposits[asset] -= amount;

        // Update vault and pool state
        _appStorage.s_vaultDeposits[asset] -= amount;
        tokenData.poolLiquidity -= amount;
        tokenData.totalSupply -= shares;
        _appStorage.s_protocolPool[asset].totalSupply -= shares;
        tokenData.lastUpdateTimestamp = block.timestamp;

        // Transfer assets if requested
        if (transferAssets) {
            if (asset == Constants.NATIVE_TOKEN || asset == Constants.WETH) {
                // Handle ETH withdrawals
                if (asset == Constants.WETH) {
                    IWeth(Constants.WETH).withdraw(amount);
                }
                (bool success,) = payable(receiver).call{value: amount}("");
                require(success, "ETH transfer failed");
            } else {
                IERC20(asset).safeTransfer(receiver, amount);
            }
        }

        // Update exchange rate post-withdrawal
        _syncVaultExchangeRate(_appStorage, asset);

        emit VaultWithdrawn(asset, receiver, amount, shares);
    }

    /**
     * @notice Callback from VToken vault when transfer occurs
     * @param _appStorage The app storage layout
     * @param asset Token being transferred
     * @param shares Amount of shares transferred
     * @param sender Address sending the shares
     * @param receiver Address receiving the shares
     * @return success Whether the transfer was successful
     */
    function notifyVaultTransfer(
        LibAppStorage.Layout storage _appStorage,
        address asset,
        uint256 shares,
        address sender,
        address receiver
    ) internal returns (bool success) {
        // Verify caller is a valid vault
        if (_appStorage.s_vaults[asset] != msg.sender) {
            revert UnauthorizedVault();
        }

        if (shares == 0) revert ZeroAmount();
        if (sender == address(0) || receiver == address(0)) {
            revert InvalidReceiver();
        }
        if (sender == receiver) revert InvalidReceiver();

        // Check if sender has enough shares
        if (_appStorage.s_addressToUserPoolShare[sender][asset] < shares) {
            revert InsufficientShares();
        }

        // Update user positions
        _appStorage.s_addressToUserPoolShare[sender][asset] -= shares;
        _appStorage.s_addressToUserPoolShare[receiver][asset] += shares;

        emit VaultTransferred(asset, sender, receiver, shares);

        return true;
    }

    /**
     * @notice Update vault exchange rate to reflect current protocol state
     * @param _appStorage The app storage layout
     * @param asset Token address
     */
    function updateVaultExchangeRate(LibAppStorage.Layout storage _appStorage, address asset) internal {
        if (_appStorage.s_vaults[asset] == address(0)) revert VaultNotExists();

        _updateInterestAndExchangeRate(_appStorage, asset);
        _syncVaultExchangeRate(_appStorage, asset);
    }

    /**
     * @notice Get vault's total assets including accrued interest
     * @param _appStorage The app storage layout
     * @param asset Token address
     * @return totalAssets Total assets for the vault
     */
    function getVaultTotalAssets(LibAppStorage.Layout storage _appStorage, address asset)
        internal
        view
        returns (uint256 totalAssets)
    {
        TokenData storage tokenData = _appStorage.s_tokenData[asset];

        // Total assets = poolLiquidity + totalBorrows (including accrued interest)
        totalAssets = tokenData.poolLiquidity + tokenData.totalBorrows;

        return totalAssets;
    }

    /**
     * @notice Get vault's current exchange rate
     * @param _appStorage The app storage layout
     * @param asset Token address
     * @return exchangeRate Current exchange rate (assets per share * 1e18)
     */
    function getVaultExchangeRate(LibAppStorage.Layout storage _appStorage, address asset)
        internal
        view
        returns (uint256 exchangeRate)
    {
        TokenData storage tokenData = _appStorage.s_tokenData[asset];

        uint256 totalAssets = getVaultTotalAssets(_appStorage, asset);
        uint256 totalShares = tokenData.totalSupply;

        if (totalShares == 0) return 1e18; // Initial exchange rate

        // Exchange rate = (totalAssets * 1e18) / totalShares
        exchangeRate = (totalAssets * 1e18) / totalShares;

        return exchangeRate;
    }

    /**
     * @notice Internal function to update interest and exchange rate
     * @param _appStorage The app storage layout
     * @param asset Token address
     */
    function _updateInterestAndExchangeRate(LibAppStorage.Layout storage _appStorage, address asset) internal {
        TokenData storage tokenData = _appStorage.s_tokenData[asset];
        ProtocolPool storage protocolPool = _appStorage.s_protocolPool[asset];

        // Update borrow index to accrue interest
        LibInterestAccure.updateBorrowIndex(tokenData, protocolPool);

        // Update timestamp
        tokenData.lastUpdateTimestamp = block.timestamp;
    }

    /**
     * @notice Sync vault exchange rate with current protocol state
     * @param _appStorage The app storage layout
     * @param asset Token address
     */
    function _syncVaultExchangeRate(LibAppStorage.Layout storage _appStorage, address asset) internal {
        address vaultAddress = _appStorage.s_vaults[asset];
        if (vaultAddress == address(0)) return;

        uint256 oldRate = getVaultExchangeRate(_appStorage, asset);

        // Calculate new exchange rate
        uint256 totalAssets = getVaultTotalAssets(_appStorage, asset);
        uint256 totalShares = _appStorage.s_tokenData[asset].totalSupply;

        uint256 newRate = totalShares > 0 ? (totalAssets * 1e18) / totalShares : 1e18;

        // Ensure exchange rate can only increase or stay the same (prevents manipulation)
        if (newRate < oldRate) revert ExchangeRateDecrease();

        // Update vault exchange rate via interface call
        ILendbitTokenVault(vaultAddress).updateExchangeRate(newRate);

        emit ExchangeRateUpdated(asset, newRate, oldRate);
    }
}
