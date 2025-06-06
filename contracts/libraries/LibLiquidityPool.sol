// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../model/Protocol.sol";
import "../model/Event.sol";
import "../utils/validators/Error.sol";
import "../utils/validators/Validator.sol";
import "../utils/constants/Constant.sol";
import "./LibAppStorage.sol";
import {LibGettersImpl} from "./LibGetters.sol";
import {LibInterestAccure} from "./LibInterestAccure.sol";
import {LibInterestRateModel} from "./LibInterestRateModel.sol";
import {LibRateCalculations} from "./LibRateCalculation.sol";
import {Utils} from "../utils/functions/Utils.sol";




library LibLiquidityPool {
    using SafeERC20 for IERC20;

    /**
     * @dev Allows users to deposit tokens into the liquidity pool
     * @param _appStorage The app storage layout
     * @param _token The address of the token to deposit
     * @param _amount The amount of tokens to deposit
     * @param _user The address of the user depositing
     * @param _chainSelector The chain selector for cross-chain operations
     * @return shares The number of LP shares minted for the deposit
     */
    function _deposit(
        LibAppStorage.Layout storage _appStorage,
        address _token,
        uint256 _amount,
        address _user,
        uint64 _chainSelector
    ) internal returns (uint256 shares) {
        if (!_appStorage.s_protocolPool[_token].initialize) {
            revert ProtocolPool__NotInitialized();
        }

        if (_amount == 0) revert ProtocolPool__ZeroAmount();
        if (!_appStorage.s_isLoanable[_token]) {
            revert ProtocolPool__TokenNotSupported();
        }
        if (!_appStorage.s_protocolPool[_token].isActive) {
            revert ProtocolPool__IsNotActive();
        }
           // Handle deposit based on token type
        if (_token == Constants.NATIVE_TOKEN) {
            require(msg.value == _amount, "Incorrect ETH amount");

        } else {
            require(msg.value == 0, "ETH sent with token deposit");
            IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        }
 
        // Calculate shares based on the amount deposited
        shares = Utils.convertToShares(_appStorage.s_tokenData[_token], _amount);

        // Update state variables
        _appStorage.s_protocolPool[_token].totalSupply += shares;
        _appStorage.s_tokenData[_token].totalSupply += shares;
        _appStorage.s_tokenData[_token].poolLiquidity += _amount;
        _appStorage.s_tokenData[_token].lastUpdateTimestamp = block.timestamp;
        _appStorage.s_addressToUserPoolShare[_user][_token] += shares;

        // Emit an event for the deposit
        emit Deposit(_user, _token, _amount, shares, _chainSelector);
    }

     /**
     * @dev Allows users to borrow tokens from the liquidity pool
     * @param _appStorage The app storage layout
     * @param _token The address of the token to borrow
     * @param _amount The amount of tokens to borrow
     * @param _user The address of the user borrowing
     * @param _chainSelector The chain selector for cross-chain operations
     */
    function _borrowFromPool(
        LibAppStorage.Layout storage _appStorage,
        address _token,
        uint256 _amount,
        address _user,
        uint64 _chainSelector
    ) internal {
        if (!_appStorage.s_protocolPool[_token].initialize) {
            revert ProtocolPool__NotInitialized();
        }
        if (_amount == 0) revert ProtocolPool__ZeroAmount();
        if (!_appStorage.s_isLoanable[_token]) {
            revert ProtocolPool__TokenNotSupported();
        }

        ProtocolPool storage _protocolPool = _appStorage.s_protocolPool[_token];
        TokenData storage tokenData = _appStorage.s_tokenData[_token];

        if (_protocolPool.totalSupply == 0) revert ProtocolPool__NoLiquidity();
        if (_protocolPool.totalBorrows + _amount > _protocolPool.totalSupply) {
            revert ProtocolPool__NotEnoughLiquidity();
        }

        if (!_appStorage.s_protocolPool[_token].isActive) {
            revert ProtocolPool__IsNotActive();
        }

        if (tokenData.poolLiquidity < _amount) {
            revert ProtocolPool__NotEnoughLiquidity();
        }

        // Update borrow index to accrue interest
        LibInterestAccure.updateBorrowIndex(tokenData, _protocolPool);
        
        // Verify user has sufficient collateral
        uint8 tokenDecimals = LibGettersImpl._getTokenDecimal(_token);
        uint256 loanUsdValue = LibGettersImpl._getUsdValue(
            _appStorage,
            _token,
            _amount,
            tokenDecimals
        );

        // Check health factor after potential borrow
        if (
            LibGettersImpl._healthFactor(_appStorage, _user, loanUsdValue) < 1e18
        ) {
            revert ProtocolPool__InsufficientCollateral();
        }

        // Lock collateral
        _lockCollateral(_appStorage, _user, _token, _amount);

        // Update user borrow data
        UserBorrowData storage userBorrowData = _appStorage.s_userBorrows[_user][_token];

        // If user has an existing borrow, update it with accrued interest first
        if (userBorrowData.isActive) {
            uint256 currentDebt = _calculateUserDebt(tokenData, userBorrowData);
            userBorrowData.borrowedAmount = currentDebt + _amount;
        } else {
            userBorrowData.borrowedAmount = _amount;
            userBorrowData.isActive = true;
        }

        // Update the user's borrow index to current index
        userBorrowData.borrowIndex = tokenData.borrowIndex;
        userBorrowData.lastUpdateTimestamp = block.timestamp;

        // Update pool state
        tokenData.totalBorrows += _amount;
        tokenData.poolLiquidity -= _amount;

        // Transfer tokens to the user
        if (_token == Constants.NATIVE_TOKEN) {
            (bool success, ) = payable(_user).call{value: _amount}("");
            require(success, "ETH transfer failed");
        } else {
            IERC20(_token).safeTransfer(_user, _amount);
        }

        // Emit an event for the borrow
        emit Borrow(_user, _token, _amount, _chainSelector);
    }

    /**
     * @dev Allows users to repay their borrowed tokens
     * @param _appStorage The app storage layout
     * @param _token The address of the token to repay
     * @param _amount The amount to repay, use type(uint256).max to repay full debt
     * @param _user The address of the user repaying
     * @param _chainSelector The chain selector for cross-chain operations
     * @return amountRepaid The actual amount repaid
     */
    function _repay(
        LibAppStorage.Layout storage _appStorage,
        address _token,
        uint256 _amount,
        address _user,
        uint64 _chainSelector
    ) internal returns (uint256 amountRepaid) {
        // Validate repay
        if (!_appStorage.s_protocolPool[_token].initialize) {
            revert ProtocolPool__NotInitialized();
        }
        if (_amount == 0) revert ProtocolPool__ZeroAmount();
        if (!_appStorage.s_isLoanable[_token]) {
            revert ProtocolPool__TokenNotSupported();
        }

        // Get storage references
        ProtocolPool storage protocolPool = _appStorage.s_protocolPool[_token];
        TokenData storage tokenData = _appStorage.s_tokenData[_token];
        UserBorrowData storage userBorrowData = _appStorage.s_userBorrows[_user][_token];

        // If no active borrow, revert
        if (!userBorrowData.isActive || userBorrowData.borrowedAmount == 0) {
            revert ProtocolPool__NoBorrow();
        }

        // Update borrow index to accrue interest
        LibInterestAccure.updateBorrowIndex(tokenData, protocolPool);

        // Calculate current debt with accrued interest
        uint256 currentDebt = _calculateUserDebt(tokenData, userBorrowData);

        // If requested amount is max uint, repay the full debt
        if (_amount == type(uint256).max) {
            amountRepaid = currentDebt;
        } else {
            // Otherwise repay the requested amount, or the full debt if it's less
            amountRepaid = _amount > currentDebt ? currentDebt : _amount;
        }

        // Handle token transfer
        if (_token == Constants.NATIVE_TOKEN) {
            require(msg.value >= amountRepaid, "Insufficient ETH sent");

            // Refund excess ETH if any
            if (msg.value > amountRepaid) {
                (bool success, ) = payable(_user).call{
                    value: msg.value - amountRepaid
                }("");
                require(success, "ETH refund failed");
            }
        } else {
            uint256 contractBalance = IERC20(_token).balanceOf(address(this));
            if (contractBalance < amountRepaid) {
                revert ProtocolPool__InsufficientBalance();
            }
            IERC20(_token).safeTransferFrom(_user, address(this), amountRepaid);
        }

        // Update user data
        if (amountRepaid == currentDebt) {
            // Full repayment
            delete _appStorage.s_userBorrows[_user][_token];
            _unlockAllCollateral(_appStorage, _user);
        } else {
            // Partial repayment
            userBorrowData.borrowedAmount = currentDebt - amountRepaid;
            userBorrowData.borrowIndex = tokenData.borrowIndex;
            userBorrowData.lastUpdateTimestamp = block.timestamp;

            _unlockCollateral(_appStorage, _user, _token, amountRepaid);
        }

        // Update pool state
        tokenData.totalBorrows -= amountRepaid;
        tokenData.poolLiquidity += amountRepaid;

        // Emit an event for the repayment
        emit Repay(_user, _token, amountRepaid, _chainSelector);
    }

    /**
     * @dev Allows users to withdraw tokens from the liquidity pool
     * @param _appStorage The app storage layout
     * @param _token The address of the token to withdraw
     * @param _amount The amount of token to withdraw and burn corresponding shares
     * @param _user The address of the user withdrawing
     * @param _chainSelector The chain selector for cross-chain operations
     * @return amountWithdrawn The actual amount of tokens withdrawn
     */
    function _withdraw(
        LibAppStorage.Layout storage _appStorage,
        address _token,
        uint256 _amount,
        address _user,
        uint64 _chainSelector
    ) internal returns (uint256 amountWithdrawn) {
        // Validate withdraw conditions
        if (!_appStorage.s_protocolPool[_token].initialize) {
            revert ProtocolPool__NotInitialized();
        }
        if (_amount == 0) revert ProtocolPool__ZeroAmount();
        if (!_appStorage.s_isLoanable[_token]) {
            revert ProtocolPool__TokenNotSupported();
        }

        // Check user has sufficient shares
        uint256 userShares = _appStorage.s_addressToUserPoolShare[_user][_token];
        uint256 shares = Utils.convertToShares(_appStorage.s_tokenData[_token], _amount);
        if (userShares < shares) revert ProtocolPool__InsufficientShares();

        // Get storage references
        TokenData storage tokenData = _appStorage.s_tokenData[_token];
        ProtocolPool storage protocolPool = _appStorage.s_protocolPool[_token];

        // Ensure pool has liquidity
        if (tokenData.poolLiquidity == 0) revert ProtocolPool__NoLiquidity();
        
        // Update borrow index to accrue interest before withdrawal
        LibInterestAccure.updateBorrowIndex(tokenData, protocolPool);

        // Ensure pool has enough liquidity to fulfill the withdrawal
        if (tokenData.poolLiquidity < _amount) {
            revert ProtocolPool__NotEnoughLiquidity();
        }

        // Update user's share balance
        _appStorage.s_addressToUserPoolShare[_user][_token] -= shares;

        // Update protocol pool state
        protocolPool.totalSupply -= shares;
        tokenData.totalSupply -= shares;
        tokenData.poolLiquidity -= _amount;
        tokenData.lastUpdateTimestamp = block.timestamp;

        // Transfer tokens to user
        if (_token == Constants.NATIVE_TOKEN) {
            (bool success, ) = payable(_user).call{value: _amount}("");
            require(success, "ETH transfer failed");
        } else {
            IERC20(_token).safeTransfer(_user, _amount);
        }

        amountWithdrawn = _amount;

        // Emit an event for the withdrawal
        emit Withdraw(_user, _token, _amount, shares, _chainSelector);
    }

    /**
     * @dev Calculates the current debt for a specific user including accrued interest
     * @param tokenData The token data with current index
     * @param userBorrowData The user's borrow data
     * @return The current debt amount including interest
     */
    function _calculateUserDebt(
        TokenData memory tokenData,
        UserBorrowData memory userBorrowData
    ) internal pure returns (uint256) {
        if (userBorrowData.borrowedAmount == 0) return 0;

        // Calculate the ratio between current index and user's borrow index
        // This represents how much interest has accumulated since user borrowed
        uint256 currentDebt = (userBorrowData.borrowedAmount * tokenData.borrowIndex) / 
                             userBorrowData.borrowIndex;

        return currentDebt;
    }

    /**
     * @dev Locks collateral for a loan being taken
     * @param _appStorage The app storage layout
     * @param _user Address of the user whose collateral should be locked
     * @param _loanToken Address of the token that is being borrowed
     * @param _amount Amount of loan token being borrowed, used to calculate how much collateral to lock
     */
    function _lockCollateral(
        LibAppStorage.Layout storage _appStorage,
        address _user,
        address _loanToken,
        uint256 _amount
    ) internal {
        // Retrieve the loan currency's decimal precision
        uint8 _decimal = LibGettersImpl._getTokenDecimal(_loanToken);
        // Get the total USD collateral value for the borrower
        uint256 collateralValueInLoanCurrency = LibGettersImpl._getAccountCollateralValue(_appStorage, _user);
        // Calculate the maximum loanable amount based on the collateral value
        uint256 maxLoanableAmount = Utils.maxLoanableAmount(collateralValueInLoanCurrency);

        // Calculate the USD equivalent of the loan amount
        uint256 _loanUsdValue = LibGettersImpl._getUsdValue(_appStorage, _loanToken, _amount, _decimal);
        // Calculate the amount of collateral to lock based on the loan value
        uint256 collateralToLock = Utils.calculateColateralToLock(_loanUsdValue, maxLoanableAmount);

        address[] memory _collateralTokens = LibGettersImpl._getUserCollateralTokens(_appStorage, _user);

        // For each collateral token, lock an appropriate amount based on its USD value
        for (uint256 i = 0; i < _collateralTokens.length; i++) {
            address token = _collateralTokens[i];
            uint8 _decimalToken = LibGettersImpl._getTokenDecimal(token);
            uint256 userBalance = _appStorage.s_addressToCollateralDeposited[_user][token];

            // Calculate the amount to lock in USD for each token based on the proportional collateral
            uint256 amountToLockUSD = (LibGettersImpl._getUsdValue(_appStorage, token, userBalance, _decimalToken) * collateralToLock) / 100;

            // Convert USD amount to token amount and apply the correct decimal scaling
            uint256 amountToLock = ((((amountToLockUSD) * 10) / LibGettersImpl._getUsdValue(_appStorage, token, 10, 0)) * (10 ** _decimalToken)) / (Constants.PRECISION);

            _appStorage.s_addressToAvailableBalance[_user][token] -= amountToLock;

            // Store the locked amount for each collateral token
            _appStorage.s_addressToLockedPoolCollateral[_user][token] += amountToLock;
        }
    }

    /**
     * @dev Unlocks collateral that was previously locked for a loan
     * @param _appStorage The app storage layout
     * @param _user Address of the user whose collateral should be unlocked
     * @param _loanToken Address of the token that was borrowed
     * @param _amount Amount of loan token being repaid, used to calculate how much collateral to unlock
     */
    function _unlockCollateral(
        LibAppStorage.Layout storage _appStorage,
        address _user,
        address _loanToken,
        uint256 _amount
    ) internal {
        // Retrieve the loan currency's decimal precision
        uint8 _decimal = LibGettersImpl._getTokenDecimal(_loanToken);
        // Get the total USD collateral value for the borrower
        uint256 collateralValueInLoanCurrency = LibGettersImpl._getAccountCollateralValue(_appStorage, _user);
        // Calculate the maximum loanable amount based on the collateral value
        uint256 maxLoanableAmount = Utils.maxLoanableAmount(collateralValueInLoanCurrency);

        // Calculate the USD equivalent of the loan amount
        uint256 _loanUsdValue = LibGettersImpl._getUsdValue(_appStorage, _loanToken, _amount, _decimal);
        // Calculate the amount of collateral to unlock based on the loan value
        uint256 collateralToUnlock = Utils.calculateColateralToLock(_loanUsdValue, maxLoanableAmount);

        address[] memory _collateralTokens = LibGettersImpl._getUserCollateralTokens(_appStorage, _user);

        // For each collateral token, unlock an appropriate amount based on its USD value
        for (uint256 i = 0; i < _collateralTokens.length; i++) {
            address token = _collateralTokens[i];
            uint8 _decimalToken = LibGettersImpl._getTokenDecimal(token);
            uint256 userBalance = _appStorage.s_addressToCollateralDeposited[_user][token];

            // Calculate the amount to unlock in USD for each token based on the proportional collateral
            uint256 amountToUnlockUSD = (LibGettersImpl._getUsdValue(_appStorage, token, userBalance, _decimalToken) * collateralToUnlock) / 100;

            // Convert USD amount to token amount and apply the correct decimal scaling
            uint256 amountToUnlock = ((((amountToUnlockUSD) * 10) / LibGettersImpl._getUsdValue(_appStorage, token, 10, 0)) * (10 ** _decimalToken)) / (Constants.PRECISION);

            _appStorage.s_addressToAvailableBalance[_user][token] += amountToUnlock;

            // Reduce the locked amount for each collateral token
            _appStorage.s_addressToLockedPoolCollateral[_user][token] -= amountToUnlock;
        }
    }

    /**
     * @dev Fully unlocks all collateral for a user when their loan is completely repaid
     * @param _appStorage The app storage layout
     * @param _user Address of the user whose collateral should be fully unlocked
     */
    function _unlockAllCollateral(
        LibAppStorage.Layout storage _appStorage,
        address _user
    ) internal {
        address[] memory _collateralTokens = LibGettersImpl._getUserCollateralTokens(_appStorage, _user);

        for (uint256 i = 0; i < _collateralTokens.length; i++) {
            address token = _collateralTokens[i];

            // Get the locked collateral amount for this token
            uint256 lockedAmount = _appStorage.s_addressToLockedPoolCollateral[_user][token];
            if (lockedAmount == 0) continue;

            // Move locked collateral to available balance
            _appStorage.s_addressToAvailableBalance[_user][token] += lockedAmount;

            // Reset the locked collateral
            _appStorage.s_addressToLockedPoolCollateral[_user][token] = 0;
        }
    }
}

