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
import {LibGettersImpl} from "../libraries/LibGetters.sol";
import {LibInterestAccure} from "./LibInterestAccure.sol";
import {Constants} from "../utils/constants/Constant.sol";

library LibShared {
    using SafeERC20 for IERC20;

    /**
     * @dev Allows a user to deposit collateral.
     * @param _tokenCollateralAddress The address of the collateral token to deposit.
     * @param _amountOfCollateral The amount of collateral to deposit.
     * @param _user The address of the user depositing the collateral.
     */
    function _depositCollateral(
        LibAppStorage.Layout storage _appStorage,
        address _tokenCollateralAddress,
        uint256 _amountOfCollateral,
        address _user,
        uint64 _chainSelector
    ) internal {
        // Validate the input parameters: `_amountOfCollateral` must be greater than zero,
        // and `_tokenCollateralAddress` must have a valid price feed (non-zero address).
        Validator._valueMoreThanZero(
            _amountOfCollateral,
            _tokenCollateralAddress,
            msg.value
        );
        Validator._isTokenAllowed(
            _appStorage.s_priceFeeds[_tokenCollateralAddress]
        );

        // Determine if the collateral is the native token
        bool _isNativeToken = _tokenCollateralAddress == Constants.NATIVE_TOKEN;

        // Set `_amountOfCollateral` to `msg.value` if it's a native token
        if (_isNativeToken) {
            _amountOfCollateral = msg.value;
        }
        // Transfer ERC-20 tokens from the sender to the contract if not the native token
        if (!_isNativeToken) {
            IERC20(_tokenCollateralAddress).safeTransferFrom(
                _user,
                address(this),
                _amountOfCollateral
            );
        }

        // Update the user's collateral and available balance in storage
        _appStorage.s_addressToCollateralDeposited[_user][
            _tokenCollateralAddress
        ] += _amountOfCollateral;
        _appStorage.s_addressToAvailableBalance[_user][
            _tokenCollateralAddress
        ] += _amountOfCollateral;

        // Emit an event for the collateral deposit
        emit CollateralDeposited(
            _user,
            _tokenCollateralAddress,
            _amountOfCollateral,
            _chainSelector
        );
    }


    function _addressZeroCheck(address _user, address _debtorAddress, address _tokenAddress) internal pure {
        if (_user == address(0) || _debtorAddress == address(0) || _tokenAddress == address(0)) {
            revert Protocol__AddressZero();
        }
    }
    /**
     * @dev Allows a user to withdraw a specified amount of collateral.
     * @param _tokenCollateralAddress The address of the collateral token to withdraw.
     * @param _amount The amount of collateral to withdraw.
     * @param _user The address of the user withdrawing the collateral.
     */
    function _withdrawCollateral(
        LibAppStorage.Layout storage _appStorage,
        address _tokenCollateralAddress,
        uint256 _amount,
        address _user,
        uint64 _chainSelector
    ) internal {
        // Validate that the token is allowed and the amount is greater than zero
        Validator._isTokenAllowed(
            _appStorage.s_priceFeeds[_tokenCollateralAddress]
        );
        Validator._moreThanZero(_amount);

        // Retrieve the user's deposited amount for the specified token
        uint256 depositedAmount = _appStorage.s_addressToAvailableBalance[
            _user
        ][_tokenCollateralAddress];

        // Check if the user has sufficient collateral to withdraw the requested amount
        if (depositedAmount < _amount) {
            revert Protocol__InsufficientCollateralDeposited();
        }

        // Update storage to reflect the withdrawal of collateral
        _appStorage.s_addressToCollateralDeposited[_user][
            _tokenCollateralAddress
        ] -= _amount;
        _appStorage.s_addressToAvailableBalance[_user][
            _tokenCollateralAddress
        ] -= _amount;

        // Handle withdrawal for native token vs ERC20 tokens
        if (_tokenCollateralAddress == Constants.NATIVE_TOKEN) {
            // Transfer native token to the user
            (bool sent, ) = payable(_user).call{value: _amount}("");
            if (!sent) revert Protocol__TransferFailed();
        } else {
            // Transfer ERC20 token to the user
            IERC20(_tokenCollateralAddress).safeTransfer(_user, _amount);
        }

        // Emit an event indicating successful collateral withdrawal
        emit CollateralWithdrawn(
            _user,
            _tokenCollateralAddress,
            _amount,
            _chainSelector
        );
    }

      // /**
    //  * @dev Allows a user to liquidate a LP.
    //  * @param _borrowIndex The index of the borrow in the LP.
    //  * @param _user The address of the user liquidating the collateral.
    //  * @param _chainSelector The chain selector of the chain the request is on.
    //  */
    /**
     * @dev Allows a user to liquidate a LP position when borrower's health factor is below 1.
     * @param _appStorage The app storage layout
     * @param _liquidatorAddress The address of the user liquidating the position
     * @param _debtorAddress The address of the borrower being liquidated
     * @param _tokenAddress The address of the borrowed token
     * @param _amount The amount to liquidate (0 for full liquidation)
     * @param _chainSelector The chain selector of the chain the request is on
     */
    function _liquidateLp(
        LibAppStorage.Layout storage _appStorage,
        address _liquidatorAddress,
        address _debtorAddress,
        address _tokenAddress,
        uint256 _amount,
        uint64 _chainSelector
    ) internal {
        // validate that the protocol pool is initialized
        if (!_appStorage.s_protocolPool[_tokenAddress].initialize) {
            revert ProtocolPool__NotInitialized();
        }

        // sanitity check for zero address
        _addressZeroCheck(_liquidatorAddress, _debtorAddress, _tokenAddress);

        // Check if the token is supported for loaning
        if (!_appStorage.s_isLoanable[_tokenAddress]) {
            revert ProtocolPool__TokenNotSupported();
        }

        // Check if the liquidator is trying to liquidate their own position
        if (_liquidatorAddress == _debtorAddress) {
            revert Protocol__OwnerCantLiquidateRequest();
        }

        // Get storage references
        ProtocolPool storage protocolBorrowPool = _appStorage.s_protocolPool[_tokenAddress];
        TokenData storage borrowTokenData = _appStorage.s_tokenData[_tokenAddress];
        UserBorrowData storage userBorrowData = _appStorage.s_userBorrows[_debtorAddress][_tokenAddress];

        // Validate that the borrower has an active borrow
        if (!userBorrowData.isActive || userBorrowData.borrowedAmount == 0) {
            revert ProtocolPool__NoBorrow();
        }

        // Store original values before any updates
        uint256 originalBorrowedAmount = userBorrowData.borrowedAmount;
        uint256 originalPoolLiquidity = borrowTokenData.poolLiquidity;
        uint256 originalTotalBorrows = borrowTokenData.totalBorrows;

        // CRITICAL: Update borrow index BEFORE calculating debt
        LibInterestAccure.updateBorrowIndex(borrowTokenData, protocolBorrowPool);

        // Calculate current debt with accrued interest
        uint256 currentDebt = LibGettersImpl.calculateUserDebt(userBorrowData, borrowTokenData, protocolBorrowPool);

        if (currentDebt == 0) {
            revert ProtocolPool__NoDebt();
        }

        // Calculate health factor
        uint8 tokenDecimal = LibGettersImpl._getTokenDecimal(_tokenAddress);
        uint256 currentDebtUsdValue = LibGettersImpl._getUsdValue(_appStorage, _tokenAddress, currentDebt, tokenDecimal);
        uint256 healthFactor = LibGettersImpl._healthFactor(_appStorage, _debtorAddress, currentDebtUsdValue);

        if (healthFactor >= 1e18) {
            revert ProtocolPool__PositionStillHealthy(); // Position is still healthy
        }

        // Determine liquidation amount
        uint256 liquidationAmount;
        if (_amount == 0 || _amount > currentDebt) {
            // Full liquidation
            liquidationAmount = currentDebt;
        } else {
            // Partial liquidation - ensure minimum liquidation threshold
            liquidationAmount = _amount;
            // Ensure minimum liquidation threshold is met  security
            if (liquidationAmount < (currentDebt * Constants.MIN_LIQUIDATION_THRESHOLD) / 10000) {
                revert Protocol__LiquidationTooSmall();
            }
        }

        // Handle debt repayment from liquidator
        if (_tokenAddress == Constants.NATIVE_TOKEN) {
            // For native token (ETH), ensure sufficient ETH was sent
            if (msg.value < liquidationAmount) revert Protocol__InsufficientETH();

            // Refund excess ETH to liquidator
            uint256 excess = msg.value - liquidationAmount;
            if (excess > 0) {
                (bool refundSent,) = payable(_liquidatorAddress).call{value: excess}("");
                if (!refundSent) revert Protocol__RefundFailed();
            }
        } else {
            // For ERC20 tokens, transfer from liquidator to contract
            IERC20(_tokenAddress).safeTransferFrom(_liquidatorAddress, address(this), liquidationAmount);
        }

        // Calculate collateral to seize
        uint256 liquidationUsdAmount =
            LibGettersImpl._getUsdValue(_appStorage, _tokenAddress, liquidationAmount, tokenDecimal);

        //  Get user's collateral tokens
        address[] memory collateralTokens = LibGettersImpl._getUserCollateralTokens(_appStorage, _debtorAddress);
        uint256 totalCollateralSeizedUsd = 0;

        // Get total collateral value for proportional calculation
        uint256 totalCollateralValue = LibGettersImpl._getAccountCollateralValue(_appStorage, _debtorAddress);

        if (totalCollateralValue == 0) {
            revert Protocol__NoCollateralToSeize();
        }

        // Seize collateral proportionally with liquidation discount
        for (uint256 i = 0; i < collateralTokens.length && liquidationUsdAmount > totalCollateralSeizedUsd; i++) {
            address collateralToken = collateralTokens[i];
            uint256 userCollateralBalance = _appStorage.s_addressToCollateralDeposited[_debtorAddress][collateralToken];

            if (userCollateralBalance == 0) continue;

            uint8 collateralDecimal = LibGettersImpl._getTokenDecimal(collateralToken);
            uint256 collateralUsdValue =
                LibGettersImpl._getUsdValue(_appStorage, collateralToken, userCollateralBalance, collateralDecimal);

            // Calculate proportional seizure correctly
            uint256 remainingToSeizeUsd = liquidationUsdAmount - totalCollateralSeizedUsd;
            uint256 collateralToSeizeUsd = (collateralUsdValue * remainingToSeizeUsd) / totalCollateralValue;

            // Ensure we don't seize more than this collateral's value
            if (collateralToSeizeUsd > collateralUsdValue) {
                collateralToSeizeUsd = collateralUsdValue;
            }

            uint256 collateralToSeize = LibGettersImpl._getConvertValue(
                _appStorage,
                _tokenAddress,
                collateralToken,
                (collateralToSeizeUsd * (10 ** tokenDecimal))
                    / LibGettersImpl._getUsdValue(_appStorage, _tokenAddress, 10 ** tokenDecimal, tokenDecimal)
            );

            // Ensure we don't seize more than available
            if (collateralToSeize > userCollateralBalance) {
                collateralToSeize = userCollateralBalance;
            }

            if (collateralToSeize > 0) {
                // Apply liquidation discount (liquidator gets bonus)
                uint256 discountedAmount = (collateralToSeize * (10000 + Constants.LIQUIDATION_DISCOUNT)) / 10000;

                // Ensure contract has enough balance to pay liquidator
                if (collateralToken == Constants.NATIVE_TOKEN) {
                    if (address(this).balance < discountedAmount) {
                        discountedAmount = address(this).balance;
                    }
                    (bool sent,) = payable(_liquidatorAddress).call{value: discountedAmount}("");
                    if (!sent) revert Protocol__ETHTransferFailed();
                } else {
                    uint256 contractBalance = IERC20(collateralToken).balanceOf(address(this));
                    if (discountedAmount > contractBalance) {
                        discountedAmount = contractBalance;
                    }
                    IERC20(collateralToken).safeTransfer(_liquidatorAddress, discountedAmount);
                }

                // Update user's collateral balances
                _appStorage.s_addressToCollateralDeposited[_debtorAddress][collateralToken] -= collateralToSeize;

                // FIXED: Update available balance correctly
                uint256 availableBalance = _appStorage.s_addressToAvailableBalance[_debtorAddress][collateralToken];
                if (availableBalance >= collateralToSeize) {
                    _appStorage.s_addressToAvailableBalance[_debtorAddress][collateralToken] -= collateralToSeize;
                } else {
                    _appStorage.s_addressToAvailableBalance[_debtorAddress][collateralToken] = 0;
                }

                // Reduce locked collateral if any
                uint256 lockedCollateral = _appStorage.s_addressToLockedPoolCollateral[_debtorAddress][collateralToken];
                if (lockedCollateral > 0) {
                    uint256 lockedToReduce =
                        lockedCollateral >= collateralToSeize ? collateralToSeize : lockedCollateral;
                    _appStorage.s_addressToLockedPoolCollateral[_debtorAddress][collateralToken] -= lockedToReduce;
                }

                // Calculate actual USD value seized
                uint256 actualUsdSeized =
                    LibGettersImpl._getUsdValue(_appStorage, collateralToken, discountedAmount, collateralDecimal);
                totalCollateralSeizedUsd += actualUsdSeized;
            }
        }

        // The liquidator pays liquidationAmount, which covers both principal and accrued interest
        // We need to update the pool state to reflect this correctly

        // Calculate the proportion of debt being liquidated
        uint256 liquidationProportion = (liquidationAmount * 1e18) / currentDebt;

        // Calculate principal portion being liquidated
        uint256 principalPortion = (originalBorrowedAmount * liquidationProportion) / 1e18;

        // Update user's borrow data
        if (liquidationAmount >= currentDebt) {
            // Full liquidation - clear the borrow
            userBorrowData.isActive = false;
            userBorrowData.borrowedAmount = 0;
            userBorrowData.borrowIndex = 0;
            userBorrowData.lastUpdateTimestamp = 0;

            // For full liquidation, reduce total borrows by the full original amount
            if (borrowTokenData.totalBorrows >= originalBorrowedAmount) {
                borrowTokenData.totalBorrows -= originalBorrowedAmount;
            } else {
                borrowTokenData.totalBorrows = 0;
            }
        } else {
            // Partial liquidation - update remaining debt
            uint256 remainingPrincipal = originalBorrowedAmount - principalPortion;
            userBorrowData.borrowedAmount = remainingPrincipal;
            userBorrowData.borrowIndex = borrowTokenData.borrowIndex;
            userBorrowData.lastUpdateTimestamp = block.timestamp;

            // For partial liquidation, reduce total borrows by principal portion
            if (borrowTokenData.totalBorrows >= principalPortion) {
                borrowTokenData.totalBorrows -= principalPortion;
            } else {
                borrowTokenData.totalBorrows = 0;
            }
        }

        // This is the amount the liquidator paid to the protocol
        borrowTokenData.poolLiquidity += liquidationAmount;

        // Update timestamp
        borrowTokenData.lastUpdateTimestamp = block.timestamp;

        // Update liquidator's activity metrics
        User storage liquidator = _appStorage.addressToUser[_liquidatorAddress];
        liquidator.totalLiquidationAmount += totalCollateralSeizedUsd;

        // Emit liquidation event
        emit LpLiquidated(
            _debtorAddress,
            _liquidatorAddress,
            _tokenAddress,
            liquidationAmount,
            totalCollateralSeizedUsd,
            _chainSelector
        );
    }

    /**
     * @dev Allows a user to liquidate a request.
     * @param _requestId The ID of the request to liquidate.
     * @param _user The address of the user liquidating the collateral.
     * @param _chainSelector The chain selector of the chain the request is on.
     */
    function _liquidateRequest(
        LibAppStorage.Layout storage _appStorage,
        uint96 _requestId,
        address _user,
        uint64 _chainSelector
    ) internal {
        Request storage request = _appStorage.request[_requestId];

        if (request.status != Status.SERVICED) {
            revert Protocol__RequestNotServiced();
        }

        if (request.author == _user) {
            revert Protocol__OwnerCantLiquidateRequest();
        }

        // Store key loan details for easier reference and gas optimization
        address borrower = request.author;
        address lender = request.lender;
        address loanToken = request.loanRequestAddr;
        uint256 totalDebt = request.totalRepayment;

        // Calculate loan value in USD
        uint8 loanTokenDecimal = LibGettersImpl._getTokenDecimal(loanToken);
        uint256 loanUsdValue = LibGettersImpl._getUsdValue(
            _appStorage,
            loanToken,
            totalDebt,
            loanTokenDecimal
        );

        // Calculate total value of collateral in USD
        uint256 totalCollateralValue = 0;
        for (uint256 i = 0; i < request.collateralTokens.length; i++) {
            address collateralToken = request.collateralTokens[i];
            uint256 collateralAmount = _appStorage.s_idToCollateralTokenAmount[
                _requestId
            ][collateralToken];

            if (collateralAmount > 0) {
                uint8 collateralDecimal = LibGettersImpl._getTokenDecimal(
                    collateralToken
                );
                totalCollateralValue += LibGettersImpl._getUsdValue(
                    _appStorage,
                    collateralToken,
                    collateralAmount,
                    collateralDecimal
                );
            }
        }

        // Check if loan is past due date (liquidation only allowed for overdue loans)
        bool isPastDue = block.timestamp > request.returnDate;
        // Verify loan is undercollateralized (health factor check)
        // Health factor broken when loan value exceeds collateral value
        bool isUnhealthy = loanUsdValue > totalCollateralValue;
        if (!isPastDue || !isUnhealthy) revert Protocol__NotLiquidatable();

        // Update request status to prevent re-entrancy and multiple liquidations
        request.status = Status.LIQUIDATED;

        // Handle debt repayment from liquidator to lender
        if (loanToken == Constants.NATIVE_TOKEN) {
            // For native token (ETH), ensure sufficient ETH was sent
            if (msg.value < totalDebt) revert Protocol__InsufficientETH();

            // Refund excess ETH to liquidator
            uint256 excess = msg.value - totalDebt;
            if (excess > 0) {
                (bool refundSent, ) = payable(_user).call{value: excess}("");
                if (!refundSent) revert Protocol__RefundFailed();
            }

            // Transfer the debt amount to the lender
            (bool lenderSent, ) = payable(lender).call{value: totalDebt}("");
            if (!lenderSent) revert Protocol__ETHTransferFailed();
        } else {
            // For ERC20 tokens, transfer from liquidator to lender
            IERC20(loanToken).safeTransferFrom(_user, lender, totalDebt);
        }

        // Process each collateral token and transfer to liquidator with discount
        for (uint256 i = 0; i < request.collateralTokens.length; i++) {
            address collateralToken = request.collateralTokens[i];
            uint256 collateralAmount = _appStorage.s_idToCollateralTokenAmount[
                _requestId
            ][collateralToken];

            if (collateralAmount > 0) {
                // Calculate discounted amount (apply liquidation discount)
                uint256 discountedAmount = (collateralAmount *
                    (10000 - Constants.LIQUIDATION_DISCOUNT)) / 10000;

                // Transfer discounted amount to liquidator
                if (collateralToken == Constants.NATIVE_TOKEN) {
                    (bool sent, ) = payable(_user).call{
                        value: discountedAmount
                    }("");
                    if (!sent) revert Protocol__ETHTransferFailed();
                } else {
                    IERC20(collateralToken).safeTransfer(
                        _user,
                        discountedAmount
                    );
                }

                // The difference between original collateral and discounted amount goes to protocol as fee
                uint256 protocolAmount = collateralAmount - discountedAmount;
                if (
                    protocolAmount > 0 &&
                    _appStorage.s_protocolFeeRecipient != address(0)
                ) {
                    if (collateralToken == Constants.NATIVE_TOKEN) {
                        (bool sent, ) = payable(
                            _appStorage.s_protocolFeeRecipient
                        ).call{value: protocolAmount}("");
                        if (!sent) revert Protocol__ETHFeeTransferFailed();
                    } else {
                        IERC20(collateralToken).safeTransfer(
                            _appStorage.s_protocolFeeRecipient,
                            protocolAmount
                        );
                    }
                }

                // Reset collateral tracking to prevent double-spending
                _appStorage.s_idToCollateralTokenAmount[_requestId][
                    collateralToken
                ] = 0;
            }
        }

        // Update liquidator's activity metrics for potential rewards
        User storage liquidator = _appStorage.addressToUser[_user];
        liquidator.totalLiquidationAmount += totalCollateralValue;

        // Emit event for off-chain tracking and transparency
        emit RequestLiquidated(
            _requestId,
            _user,
            totalCollateralValue,
            _chainSelector
        );
    }
}
