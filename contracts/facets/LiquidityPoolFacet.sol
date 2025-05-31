// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.9;

import {AppStorage} from "../utils/functions/AppStorage.sol";
import {LibGettersImpl} from "../libraries/LibGetters.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {Constants} from "../utils/constants/Constant.sol";
import {ProtocolPool, TokenData, UserBorrowData} from "../model/Protocol.sol";
import "../model/Event.sol";
import {console} from "forge-std/console.sol";
import "../utils/validators/Error.sol";
import {LibInterestAccure} from "../libraries/LibInterestAccure.sol";
import {LibInterestRateModel} from "../libraries/LibInterestRateModel.sol";
import {LibRateCalculations} from "../libraries/LibRateCalculation.sol";
import {Utils} from "../utils/functions/Utils.sol";

/**
 * @title LiquidityPoolFacet
 * @notice Handles deposits, withdrawals, and interest accrual in liquidity pools
 * @author Claude
 */
contract LiquidityPoolFacet is AppStorage {
    using SafeERC20 for IERC20;

    /**
     * @notice Initializes the protocol pool with the given parameters
     * @dev Only callable by contract owner
     * @param _token The address of the token to be used in the protocol pool
     * @param reserveFactor The reserve factor for the protocol pool (percentage of interest that goes to reserves)
     * @param optimalUtilization The optimal utilization rate for the protocol pool (in basis points, 10000 = 100%)
     * @param baseRate The base interest rate for the protocol pool (in basis points)
     * @param slopeRate The slope rate for the protocol pool (determines how quickly interest rates increase)
     */
    function initializeProtocolPool(
        address _token,
        uint256 reserveFactor,
        uint256 optimalUtilization,
        uint256 baseRate,
        uint256 slopeRate // uint256 initialSupply
    ) external payable {
        // Check caller is contract owner
        LibDiamond.enforceIsContractOwner();

        // Validate protocol state
        if (_appStorage.s_protocolPool[_token].isActive) {
            revert ProtocolPool__IsNotActive();
        }
        if (_appStorage.s_protocolPool[_token].initialize) {
            revert ProtocolPool__AlreadyInitialized();
        }
        if (!_appStorage.s_isLoanable[_token]) {
            revert ProtocolPool__TokenNotSupported();
        }

        // Validate parameters
        require(
            reserveFactor <= Constants.MAX_RESERVE_FACTOR,
            "Reserve factor too high"
        );
        require(optimalUtilization <= 9000, "Optimal utilization too high");
        require(baseRate <= 1000, "Base rate too high");

        ProtocolPool storage _protocolPool = _appStorage.s_protocolPool[_token];

        // Set protocol pool parameters
        _protocolPool.token = _token;
        _protocolPool.reserveFactor = reserveFactor;
        _protocolPool.optimalUtilization = optimalUtilization;
        _protocolPool.baseRate = baseRate;
        _protocolPool.slopeRate = slopeRate;
        _protocolPool.isActive = true;
        _protocolPool.initialize = true;

        // Initialize token data
        _appStorage.s_tokenData[_token].lastUpdateTimestamp = block.timestamp;
        _appStorage.s_tokenData[_token].borrowIndex = 1e18; // Initialize with 1.0 in 18 decimals

        emit ProtocolPoolInitialized(_token, reserveFactor);
    }

    /**
     * @notice Allows users to deposit tokens into the liquidity pool
     * @dev Handles both native token (ETH) and ERC20 deposits
     * @param token The address of the token to deposit
     * @param amount The amount of tokens to deposit
     * @return shares The number of LP shares minted for the deposit
     */
    function deposit(
        address token,
        uint256 amount
    ) external payable returns (uint256 shares) {
        if (!_appStorage.s_protocolPool[token].initialize) {
            revert ProtocolPool__NotInitialized();
        }

        if (amount == 0) revert ProtocolPool__ZeroAmount();
        if (!_appStorage.s_isLoanable[token]) {
            revert ProtocolPool__TokenNotSupported();
        }
        if (!_appStorage.s_protocolPool[token].isActive) {
            revert ProtocolPool__IsNotActive();
        }

        // Handle deposit based on token type
        if (token == Constants.NATIVE_TOKEN) {
            require(msg.value == amount, "Incorrect ETH amount");
        } else {
            require(msg.value == 0, "ETH sent with token deposit");
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        }
        // Calculate shares based on the amount deposited
        // calculate user interest
        shares = Utils.convertToShares(_appStorage.s_tokenData[token], amount);

        // Update state variables
        _appStorage.s_protocolPool[token].totalSupply += shares;

        _appStorage.s_tokenData[token].totalSupply += shares;
        _appStorage.s_tokenData[token].poolLiquidity += amount;
        _appStorage.s_tokenData[token].lastUpdateTimestamp = block.timestamp;
        // _appStorage.s_addressToUserPoolDeposit[msg.sender][token] += amount;
        _appStorage.s_addressToUserPoolShare[msg.sender][token] += shares;

        emit Deposit(msg.sender, token, amount, shares);
    }

    /**
     * @notice Allows users to withdraw tokens from the liquidity pool
     * @param token The address of the token to withdraw
     * @param amount The amount of tokens to withdraw
     */
    function borrowFromPool(address token, uint256 amount) external {
        if (!_appStorage.s_protocolPool[token].initialize) {
            revert ProtocolPool__NotInitialized();
        }
        if (amount == 0) revert ProtocolPool__ZeroAmount();
        if (!_appStorage.s_isLoanable[token]) {
            revert ProtocolPool__TokenNotSupported();
        }

        ProtocolPool storage _protocolPool = _appStorage.s_protocolPool[token];

        TokenData storage tokenData = _appStorage.s_tokenData[token];

        if (_protocolPool.totalSupply == 0) revert ProtocolPool__NoLiquidity();
        if (_protocolPool.totalBorrows + amount > _protocolPool.totalSupply) {
            revert ProtocolPool__NotEnoughLiquidity();
        }

        if (!_appStorage.s_protocolPool[token].isActive) {
            revert ProtocolPool__IsNotActive();
        }

        if (tokenData.poolLiquidity < amount) {
            revert ProtocolPool__NotEnoughLiquidity();
        }
        // Update borrow index to accrue interest
        LibInterestAccure.updateBorrowIndex(tokenData, _protocolPool);
        // Verify user has sufficient collateral
        uint8 tokenDecimals = LibGettersImpl._getTokenDecimal(token);
        uint256 loanUsdValue = LibGettersImpl._getUsdValue(
            _appStorage,
            token,
            amount,
            tokenDecimals
        );

        // Check health factor after potential borrow
        if (
            LibGettersImpl._healthFactor(
                _appStorage,
                msg.sender,
                loanUsdValue
            ) < 1e18
        ) {
            revert ProtocolPool__InsufficientCollateral();
        }

        // lock collateral
        _lockCollateral(msg.sender, token, amount);

        // Update user borrow data
        UserBorrowData storage userBorrowData = _appStorage.s_userBorrows[
            msg.sender
        ][token];

        // If user has an existing borrow, update it with accrued interest first
        if (userBorrowData.isActive) {
            uint256 currentDebt = _calculateUserDebt(tokenData, userBorrowData);
            userBorrowData.borrowedAmount = currentDebt + amount;
        } else {
            userBorrowData.borrowedAmount = amount;
            userBorrowData.isActive = true;
        }

        // Update the user's borrow index to current index
        userBorrowData.borrowIndex = tokenData.borrowIndex;
        userBorrowData.lastUpdateTimestamp = block.timestamp;

        // Update pool state
        tokenData.totalBorrows += amount;
        tokenData.poolLiquidity -= amount;

        // Transfer tokens to the user
        if (token == Constants.NATIVE_TOKEN) {
            (bool success, ) = payable(msg.sender).call{value: amount}("");
            require(success, "ETH transfer failed");
        } else {
            IERC20(token).safeTransfer(msg.sender, amount);
        }

        emit Borrow(msg.sender, token, amount);
    }

    /**
     * @notice Allows users to repay their borrowed tokens
     * @param token The address of the token to repay
     * @param amount The amount to repay, use type(uint256).max to repay full debt
     * @return amountRepaid The actual amount repaid
     */
    function repay(
        address token,
        uint256 amount
    ) external payable returns (uint256 amountRepaid) {
        // Validate repay
        if (!_appStorage.s_protocolPool[token].initialize) {
            revert ProtocolPool__NotInitialized();
        }
        if (amount == 0) revert ProtocolPool__ZeroAmount();
        if (!_appStorage.s_isLoanable[token]) {
            revert ProtocolPool__TokenNotSupported();
        }

        // Get storage references
        ProtocolPool storage protocolPool = _appStorage.s_protocolPool[token];
        TokenData storage tokenData = _appStorage.s_tokenData[token];
        UserBorrowData storage userBorrowData = _appStorage.s_userBorrows[
            msg.sender
        ][token];

        // If no active borrow, revert
        if (!userBorrowData.isActive || userBorrowData.borrowedAmount == 0) {
            revert ProtocolPool__NoBorrow();
        }

        // Update borrow index to accrue interest
        LibInterestAccure.updateBorrowIndex(tokenData, protocolPool);

        // Calculate current debt with accrued interest
        uint256 currentDebt = _calculateUserDebt(tokenData, userBorrowData);

        // If requested amount is max uint, repay the full debt
        if (amount == type(uint256).max) {
            amountRepaid = currentDebt;
        } else {
            // Otherwise repay the requested amount, or the full debt if it's less
            amountRepaid = amount > currentDebt ? currentDebt : amount;
        }

        // Handle token transfer
        if (token == Constants.NATIVE_TOKEN) {
            require(msg.value >= amountRepaid, "Insufficient ETH sent");

            // Refund excess ETH if any
            if (msg.value > amountRepaid) {
                (bool success, ) = payable(msg.sender).call{
                    value: msg.value - amountRepaid
                }("");
                require(success, "ETH refund failed");
            }
        } else {
            uint256 userBalance = IERC20(token).balanceOf(address(this));
            if (userBalance < amountRepaid) {
                revert ProtocolPool__InsufficientBalance();
            }
            IERC20(token).safeTransferFrom(
                msg.sender,
                address(this),
                amountRepaid
            );
        }

        // Update user data
        if (amountRepaid == currentDebt) {
            // Full repayment
            delete _appStorage.s_userBorrows[msg.sender][token];
            _unlockAllCollateral(msg.sender);
        } else {
            // Partial repayment
            userBorrowData.borrowedAmount = currentDebt - amountRepaid;
            userBorrowData.borrowIndex = tokenData.borrowIndex;
            userBorrowData.lastUpdateTimestamp = block.timestamp;

            _unlockCollateral(msg.sender, token, amountRepaid);
        }

        // Update pool state
        tokenData.totalBorrows -= amountRepaid;
        tokenData.poolLiquidity += amountRepaid;

        emit Repay(msg.sender, token, amountRepaid);
    }

    /**
     * @notice Allows users to withdraw tokens from the liquidity pool
     * @param token The address of the token to withdraw
     * @param amount The amount of token to withdraw and burn corresponding shares
     * @return amountWithdrawn The actual amount of tokens withdrawn
     */
    function withdraw(
        address token,
        uint256 amount
    ) external returns (uint256 amountWithdrawn) {
        // Validate withdraw conditions
        if (!_appStorage.s_protocolPool[token].initialize) {
            revert ProtocolPool__NotInitialized();
        }
        if (amount == 0) revert ProtocolPool__ZeroAmount();
        if (!_appStorage.s_isLoanable[token]) {
            revert ProtocolPool__TokenNotSupported();
        }

        // Check user has sufficient shares
        uint256 userShares = _appStorage.s_addressToUserPoolShare[msg.sender][
            token
        ];
        uint256 shares = Utils.convertToShares(
            _appStorage.s_tokenData[token],
            amount
        );
        if (userShares < shares) revert ProtocolPool__InsufficientShares();

        // Get storage references
        TokenData storage tokenData = _appStorage.s_tokenData[token];
        ProtocolPool storage protocolPool = _appStorage.s_protocolPool[token];

        // Ensure pool has liquidity
        if (tokenData.poolLiquidity == 0) revert ProtocolPool__NoLiquidity();
        // Update borrow index to accrue interest before withdrawal
        LibInterestAccure.updateBorrowIndex(tokenData, protocolPool);

        // Ensure pool has enough liquidity to fulfill the withdrawal
        if (tokenData.poolLiquidity < amount) {
            revert ProtocolPool__NotEnoughLiquidity();
        }

        // Update user's share balance
        _appStorage.s_addressToUserPoolShare[msg.sender][token] -= shares;

        // Update protocol pool state
        protocolPool.totalSupply -= shares;

        tokenData.totalSupply -= shares;
        tokenData.poolLiquidity -= amount;
        tokenData.lastUpdateTimestamp = block.timestamp;

        // Transfer tokens to user
        if (token == Constants.NATIVE_TOKEN) {
            (bool success, ) = payable(msg.sender).call{value: amount}("");
            require(success, "ETH transfer failed");
        } else {
            uint256 balance = IERC20(token).balanceOf(msg.sender);
            if (balance < amount) revert ProtocolPool__InsufficientBalance();

            IERC20(token).safeTransfer(msg.sender, amount);
        }

        amountWithdrawn = amount;

        emit Withdraw(msg.sender, token, amount, shares);
    }

    /////////////////////////
    /////READ ONLY FUNCTION///
    /////////////////////////

    /**
     * @notice Gets the borrow data for a specific user and token
     * @param _user The address of the user
     * @param _token The address of the token
     * @return borrowedAmount The amount borrowed by the user
     * @return borrowIndex The borrow index for the user
     * @return lastUpdateTimestamp The last update timestamp for the user's borrow data
     * @return isActive Whether the user's borrow is active
     */
    function getUserBorrowData(
        address _user,
        address _token
    )
        external
        view
        returns (
            uint256 borrowedAmount,
            uint256 borrowIndex,
            uint256 lastUpdateTimestamp,
            bool isActive
        )
    {
        borrowedAmount = _calculateUserDebt(
            _appStorage.s_tokenData[_token],
            _appStorage.s_userBorrows[_user][_token]
        );

        return (
            // _appStorage.s_userBorrows[_user][_token].borrowedAmount,
            borrowedAmount,
            _appStorage.s_userBorrows[_user][_token].borrowIndex,
            _appStorage.s_userBorrows[_user][_token].lastUpdateTimestamp,
            _appStorage.s_userBorrows[_user][_token].isActive
        );
    }

    /**
     * @notice Gets the configuration of the protocol pool
     * @return token The token address used in the pool
     * @return totalSupply The total supply of tokens in the pool
     * @return totalBorrows The total amount borrowed from the pool
     * @return reserveFactor The reserve factor of the pool
     * @return optimalUtilization The optimal utilization rate
     * @return baseRate The base interest rate
     * @return slopeRate The slope rate for interest calculation
     * @return isActive Whether the pool is active
     * @return initialize Whether the pool is initialized
     */
    function getProtocolPoolConfig(
        address _token
    )
        external
        view
        returns (
            address token,
            uint256 totalSupply,
            uint256 totalBorrows,
            uint256 reserveFactor,
            uint256 optimalUtilization,
            uint256 baseRate,
            uint256 slopeRate,
            bool isActive,
            bool initialize
        )
    {
        return (
            _appStorage.s_protocolPool[_token].token,
            _appStorage.s_protocolPool[_token].totalSupply,
            _appStorage.s_protocolPool[_token].totalBorrows,
            _appStorage.s_protocolPool[_token].reserveFactor,
            _appStorage.s_protocolPool[_token].optimalUtilization,
            _appStorage.s_protocolPool[_token].baseRate,
            _appStorage.s_protocolPool[_token].slopeRate,
            _appStorage.s_protocolPool[_token].isActive,
            _appStorage.s_protocolPool[_token].initialize
        );
    }

    /**
     * @notice Allows users to withdraw tokens from the liquidity pool
     * @param user The address of the token to withdraw
     * @param token The amount of tokens to withdraw
     * @return sharesBurned The number of LP shares burned for the withdrawal
     */
    function getUserPoolDeposit(
        address user,
        address token
    ) external view returns (uint256) {
        return maxRedeemable(user, token);
    }

    /**
     * @notice gets token data for a specific token
     * @param token The address of the token
     * @return totalSupply The total supply of the token
     * @return poolLiquidity The total liquidity in the pool for the token
     * @return totalBorrows The total amount borrowed from the pool for the token
     * @return lastUpdateTimestamp The last time the token data was updated
     */
    function getPoolTokenData(
        address token
    )
        external
        view
        returns (
            uint256 totalSupply,
            uint256 poolLiquidity,
            uint256 totalBorrows,
            uint256 lastUpdateTimestamp
        )
    {
        return (
            _appStorage.s_tokenData[token].totalSupply,
            _appStorage.s_tokenData[token].poolLiquidity,
            _appStorage.s_tokenData[token].totalBorrows,
            _appStorage.s_tokenData[token].lastUpdateTimestamp
        );
    }

    /**
     * @notice Calculates the current debt for a specific user including accrued interest
     * @param user The address of the user
     * @param token The address of the token
     * @return debt The current debt amount including interest
     */
    function getUserDebt(
        address user,
        address token
    ) external view returns (uint256 debt) {
        UserBorrowData memory userBorrowData = _appStorage.s_userBorrows[user][
            token
        ];
        TokenData memory tokenData = _appStorage.s_tokenData[token];
        ProtocolPool memory protocolPool = _appStorage.s_protocolPool[token];

        if (!userBorrowData.isActive || userBorrowData.borrowedAmount == 0) {
            return 0;
        }

        if (
            block.timestamp == tokenData.lastUpdateTimestamp ||
            tokenData.totalBorrows == 0
        ) {
            return userBorrowData.borrowedAmount;
        }

        if (userBorrowData.borrowIndex == 0) {
            return userBorrowData.borrowedAmount;
        }

        uint256 timeElapsed = block.timestamp - tokenData.lastUpdateTimestamp;
        uint256 utilization = LibInterestRateModel.calculateUtilization(
            tokenData.totalBorrows,
            tokenData.poolLiquidity
        );
        uint256 interestRate = LibInterestRateModel.calculateInterestRate(
            protocolPool,
            utilization
        );
        uint256 factor = ((interestRate * timeElapsed) * 1e18) /
            (10000 * 31536000);
        uint256 currentBorrowIndex = tokenData.borrowIndex +
            ((tokenData.borrowIndex * factor) / 1e18);
        debt =
            (userBorrowData.borrowedAmount * currentBorrowIndex) /
            userBorrowData.borrowIndex;

        return debt;
    }

    /**
     * @notice Calculates the APY for a given APR and compounding periods
     * @param apr The APR in basis points
     * @param compoundingPeriods The number of compounding periods per year
     * @return _apy The APY in basis points
     */
    function calculatePoolAPY(
        uint256 apr,
        uint256 compoundingPeriods
    ) external pure returns (uint256 _apy) {
        _apy = LibRateCalculations.calculateAPY(apr, compoundingPeriods);
    }

    /**
     * @notice Calculates the APR for a given pool based on its parameters
     * @param baseRate The base interest rate in basis points
     * @param slopeRate The slope of the interest rate curve in basis points
     * @param optimalUtilization The optimal utilization rate in basis points
     * @param totalBorrows Total borrowed amount
     * @param poolLiquidity Total available liquidity
     * @return _apr Annual Percentage Rate in basis points
     */
    function calculatePoolAPR(
        uint256 baseRate,
        uint256 slopeRate,
        uint256 optimalUtilization,
        uint256 totalBorrows,
        uint256 poolLiquidity
    ) external pure returns (uint256 _apr) {
        _apr = LibRateCalculations.calculateAPR(
            baseRate,
            slopeRate,
            optimalUtilization,
            totalBorrows,
            poolLiquidity
        );
    }

    /**
     * @notice Retrieves both APR and APY for frontend consumption using direct values
     * @param baseRate The base interest rate in basis points
     * @param slopeRate The slope of the interest rate curve in basis points
     * @param optimalUtilization The optimal utilization rate in basis points
     * @param totalBorrows Total borrowed amount
     * @param poolLiquidity Total available liquidity
     * @return apr Annual Percentage Rate in basis points
     * @return apy Annual Percentage Yield in basis points
     */
    function getRatesFromPool(
        uint256 baseRate,
        uint256 slopeRate,
        uint256 optimalUtilization,
        uint256 totalBorrows,
        uint256 poolLiquidity
    ) external pure returns (uint256 apr, uint256 apy) {
        apr = LibRateCalculations.calculateAPR(
            baseRate,
            slopeRate,
            optimalUtilization,
            totalBorrows,
            poolLiquidity
        );

        apy = LibRateCalculations.calculateAPY(
            apr,
            Constants.DEFAULT_COMPOUNDING_PERIODS
        );

        return (apr, apy);
    }

    /////////////////////////
    /////ONLY OWNER FUNCTION///
    /////////////////////////

    /**
     * @notice Sets the active status of a protocol pool
     * @param token The address of the token
     * @param isActive The new active status
     */
    function setPoolActive(address token, bool isActive) external {
        LibDiamond.enforceIsContractOwner();
        _appStorage.s_protocolPool[token].isActive = isActive;
    }

    /////////////////////////
    /////INTERNAL FUNCTION///
    /////////////////////////

    /**
     * @notice Calculates the maximum redeemable amount for a user based on their shares
     * @param user The address of the user
     * @param token The address of the token
     * @return maxRedeemableAmount The maximum redeemable amount for the user
     */
    function maxRedeemable(
        address user,
        address token
    ) internal view returns (uint256) {
        // Check if the user has any shares in the pool
        uint256 _shares = _appStorage.s_addressToUserPoolShare[user][token];
        if (_shares == 0) return 0;

        TokenData memory _token = _appStorage.s_tokenData[token];
        // Calculate the maximum redeemable amount based on shares and pool liquidity
        uint256 _maxRedeemableAmount = Utils.convertToAmount(_token, _shares);

        return _maxRedeemableAmount;
    }

    /**
     * @notice Calculates the current debt for a specific user including accrued interest
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
        uint256 currentDebt = (userBorrowData.borrowedAmount *
            tokenData.borrowIndex) / userBorrowData.borrowIndex;

        return currentDebt;
    }

    /**
     * @notice Locks collateral for a loan being taken
     * @param _user Address of the user whose collateral should be locked
     * @param _loanToken Address of the token that is being borrowed
     * @param _amount Amount of loan token being borrrowed, used to calculate how much collateral to lock
     * @dev This function is called internally when a user takes a loan
     */
    function _lockCollateral(
        address _user,
        address _loanToken,
        uint256 _amount
    ) internal {
        // Retrieve the loan currency's decimal precision
        uint8 _decimal = LibGettersImpl._getTokenDecimal(_loanToken);
        // Get the total USD collateral value for the borrower
        uint256 collateralValueInLoanCurrency = LibGettersImpl
            ._getAccountCollateralValue(_appStorage, _user);
        // Calculate the maximum loanable amount based on the collateral value
        uint256 maxLoanableAmount = Utils.maxLoanableAmount(
            collateralValueInLoanCurrency
        );

        // Calculate the USD equivalent of the loan amount
        uint256 _loanUsdValue = LibGettersImpl._getUsdValue(
            _appStorage,
            _loanToken,
            _amount,
            _decimal
        );
        // Calculate the amount of collateral to lock based on the loan value
        uint256 collateralToLock = Utils.calculateColateralToLock(
            _loanUsdValue,
            maxLoanableAmount
        );

        address[] memory _collateralTokens = LibGettersImpl
            ._getUserCollateralTokens(_appStorage, _user);

        // For each collateral token, lock an appropriate amount based on its USD value
        for (uint256 i = 0; i < _collateralTokens.length; i++) {
            address token = _collateralTokens[i];
            uint8 _decimalToken = LibGettersImpl._getTokenDecimal(token);
            uint256 userBalance = _appStorage.s_addressToCollateralDeposited[
                _user
            ][token];

            // Calculate the amount to lock in USD for each token based on the proportional collateral
            uint256 amountToLockUSD = (LibGettersImpl._getUsdValue(
                _appStorage,
                token,
                userBalance,
                _decimalToken
            ) * collateralToLock) / 100;

            // Convert USD amount to token amount and apply the correct decimal scaling
            uint256 amountToLock = ((((amountToLockUSD) * 10) /
                LibGettersImpl._getUsdValue(_appStorage, token, 10, 0)) *
                (10 ** _decimalToken)) / (Constants.PRECISION);

            _appStorage.s_addressToAvailableBalance[_user][
                token
            ] -= amountToLock;

            // Store the locked amount for each collateral token
            _appStorage.s_addressToLockedPoolCollateral[_user][
                token
            ] += amountToLock;
        }
    }

    /**
     * @notice Unlocks collateral that was previously locked for a loan
     * @param _user Address of the user whose collateral should be unlocked
     * @param _loanToken Address of the token that was borrowed
     * @param _amount Amount of loan token being repaid, used to calculate how much collateral to unlock
     * @dev This function is called internally when a user repays a loan or when a loan is liquidated
     */
    function _unlockCollateral(
        address _user,
        address _loanToken,
        uint256 _amount
    ) internal {
        // Retrieve the loan currency's decimal precision
        uint8 _decimal = LibGettersImpl._getTokenDecimal(_loanToken);
        // Get the total USD collateral value for the borrower
        uint256 collateralValueInLoanCurrency = LibGettersImpl
            ._getAccountCollateralValue(_appStorage, _user);
        // Calculate the maximum loanable amount based on the collateral value
        uint256 maxLoanableAmount = Utils.maxLoanableAmount(
            collateralValueInLoanCurrency
        );

        // Calculate the USD equivalent of the loan amount
        uint256 _loanUsdValue = LibGettersImpl._getUsdValue(
            _appStorage,
            _loanToken,
            _amount,
            _decimal
        );
        // Calculate the amount of collateral to lock based on the loan value
        uint256 collateralToLock = Utils.calculateColateralToLock(
            _loanUsdValue,
            maxLoanableAmount
        );

        address[] memory _collateralTokens = LibGettersImpl
            ._getUserCollateralTokens(_appStorage, _user);

        // For each collateral token, lock an appropriate amount based on its USD value
        for (uint256 i = 0; i < _collateralTokens.length; i++) {
            address token = _collateralTokens[i];
            uint8 _decimalToken = LibGettersImpl._getTokenDecimal(token);
            uint256 userBalance = _appStorage.s_addressToCollateralDeposited[
                _user
            ][token];

            // Calculate the amount to lock in USD for each token based on the proportional collateral
            uint256 amountToLockUSD = (LibGettersImpl._getUsdValue(
                _appStorage,
                token,
                userBalance,
                _decimalToken
            ) * collateralToLock) / 100;

            // Convert USD amount to token amount and apply the correct decimal scaling
            uint256 amountToLock = ((((amountToLockUSD) * 10) /
                LibGettersImpl._getUsdValue(_appStorage, token, 10, 0)) *
                (10 ** _decimalToken)) / (Constants.PRECISION);

            _appStorage.s_addressToAvailableBalance[_user][
                token
            ] += amountToLock;

            // Store the
            _appStorage.s_addressToLockedPoolCollateral[_user][
                token
            ] -= amountToLock;
        }
    }

    /**
     * @notice Fully unlocks all collateral for a user when their loan is completely repaid
     * @param _user Address of the user whose collateral should be fully unlocked
     * @dev This function is called when a user has repaid all their loans
     */
    function _unlockAllCollateral(address _user) internal {
        address[] memory _collateralTokens = LibGettersImpl
            ._getUserCollateralTokens(_appStorage, _user);

        for (uint256 i = 0; i < _collateralTokens.length; i++) {
            address token = _collateralTokens[i];

            // Get the locked collateral amount for this token
            uint256 lockedAmount = _appStorage.s_addressToLockedPoolCollateral[
                _user
            ][token];
            if (lockedAmount == 0) continue;

            // Move locked collateral to available balance
            _appStorage.s_addressToAvailableBalance[_user][
                token
            ] += lockedAmount;

            // Reset the locked collateral
            _appStorage.s_addressToLockedPoolCollateral[_user][token] = 0;
        }
    }
}
