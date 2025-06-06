// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../libraries/LibShared.sol";
import "../libraries/LibAppStorage.sol";
import "../utils/functions/AppStorage.sol";

/**
 * @title SharedFacet
 * @notice This facet provides functions that both the LiquidityPoolsFacet and P2PFacet share.
 */
contract SharedFacet is AppStorage {
    using LibShared for LibAppStorage.Layout;

    /**
     * @dev Allows a user to deposit collateral.
     * @param _tokenCollateralAddress The address of the collateral token to deposit.
     * @param _amountOfCollateral The amount of collateral to deposit.
     *
     * Requirements:
     * - The token address must be valid and allowed by the protocol.
     * - The deposit amount must be greater than zero.
     *
     * Emits a `CollateralDeposited` event on successful deposit.
     */
    function depositCollateral(
        address _tokenCollateralAddress,
        uint256 _amountOfCollateral
    ) external payable {
        _appStorage._depositCollateral(
            _tokenCollateralAddress,
            _amountOfCollateral,
            msg.sender,
            Constants.CHAIN_SELECTOR
        );
    }

    /**
     * @dev Allows a user to withdraw a specified amount of collateral.
     * @param _tokenCollateralAddress The address of the collateral token to withdraw.
     * @param _amountOfCollateral The amount of collateral to withdraw.
     *
     * Requirements:
     * - The token address must be valid and allowed by the protocol.
     * - The withdrawal amount must be greater than zero.
     * - User must have at least the specified amount of collateral deposited.
     *
     * Emits a `CollateralWithdrawn` event on successful withdrawal.
     */
    function withdrawCollateral(
        address _tokenCollateralAddress,
        uint256 _amountOfCollateral
    ) external {
        _appStorage._withdrawCollateral(
            _tokenCollateralAddress,
            _amountOfCollateral,
            msg.sender,
            Constants.CHAIN_SELECTOR
        );
    }

    /**
     * @dev Allows anyone to liquidate a loan.
     * @param _requestId The ID of the loan to liquidate.
     * @param _isLP Whether the loan is from the liquidity pool.
     *
     * Requirements:
     * - The loan must be in the active state.
     * - The loan must be undercollateralized.
     * - The loan must have a valid lender.
     * - The loan must have a valid borrower.
     * @return _isLiquidated Whether the loan was successfully liquidated.
     */
    function liquidateLoans(
        uint96 _requestId,
        bool _isLP
    ) external payable returns (bool _isLiquidated) {
        if (_isLP) {
            _appStorage._liquidateLp(
                _requestId,
                msg.sender,
                Constants.CHAIN_SELECTOR
            );
        } else {
            _appStorage._liquidateRequest(
                _requestId,
                msg.sender,
                Constants.CHAIN_SELECTOR
            );
        }
    }
}
