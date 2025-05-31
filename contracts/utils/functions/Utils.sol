// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Constants} from "../constants/Constant.sol";
import {TokenData} from "../../model/Protocol.sol";
import "../validators/Error.sol";

library Utils {
    /**
     * @dev Calculates a percentage of a given number.
     * @param _number The base number from which to calculate the percentage.
     * @param _percentage The percentage to calculate, expressed as a basis point (1% = 100).
     * @return The calculated percentage amount of `_number`.
     */
    function calculatePercentage(uint256 _number, uint16 _percentage) internal pure returns (uint256) {
        // Multiplies the number by the percentage and divides by 10000 to support basis points
        return (_number * _percentage) / 10000;
    }

    /**
     * @dev Calculates the maximum loanable amount based on the collateral's value in loan currency.
     * @param _collateralValueInLoanCurrency The total collateral value in the requested loan currency.
     * @return _value The maximum amount that can be loaned out based on collateral value.
     */
    function maxLoanableAmount(uint256 _collateralValueInLoanCurrency) internal pure returns (uint256 _value) {
        // Calculates maximum loanable amount by applying a collateralization ratio to the collateral value
        _value = (_collateralValueInLoanCurrency * Constants.COLLATERALIZATION_RATIO) / 100;
    }

    /**
     * @dev Calculates the total repayment amount including interest for a loan.
     * @param _returnDate The expected return date of the loan.
     * @param _amount The principal loan amount.
     * @param _interest The interest rate as a basis point (1% = 100).
     * @return _totalRepayment The total amount to be repaid (principal + interest).
     *
     * Requirements:
     * - `_returnDate` must be in the future relative to the current block timestamp.
     */
    function calculateLoanInterest(uint256 _returnDate, uint256 _amount, uint16 _interest)
        internal
        view
        returns (uint256 _totalRepayment)
    {
        // Ensure the return date is in the future
        if (_returnDate < block.timestamp) {
            revert Protocol__DateMustBeInFuture();
        }

        // Calculate total repayment amount as principal plus calculated interest
        _totalRepayment = _amount + calculatePercentage(_amount, _interest);
        return _totalRepayment;
    }

    /**
     * @dev Calculates the amount of collateral to lock based on the loan's USD value and max loanable amount.
     * @param _loanUsdValue The value of the loan in USD.
     * @param _maxLoanableAmount The maximum loanable amount based on the collateral.
     * @return _value The amount of collateral to lock, adjusted for precision.
     */
    function calculateColateralToLock(uint256 _loanUsdValue, uint256 _maxLoanableAmount)
        internal
        pure
        returns (uint256 _value)
    {
        // Calculate collateral lock amount as a proportion of loan USD value to max loanable amount
        _value = (_loanUsdValue * 100 * Constants.PRECISION) / _maxLoanableAmount;
    }

    function convertToShares(TokenData memory _token, uint256 _amount) internal pure returns (uint256 _shares) {
        // Calculate shares based on the amount deposited and the total supply of the token
        if (_token.totalSupply == 0) {
            _shares = _amount;
        } else {
            _shares = (_amount * _token.totalSupply) / _token.poolLiquidity;
        }
    }

    function convertToAmount(TokenData memory _token, uint256 _shares) internal pure returns (uint256 _amount) {
        // Calculate amount based on shares and the total supply of the token
        if (_token.totalSupply == 0) {
            _amount = _shares;
        } else {
            _amount = (_shares * _token.poolLiquidity) / _token.totalSupply;
        }
    }

    function pricePerShare(TokenData memory _token) internal pure returns (uint256 _price) {
        // Calculate price per share based on the total supply and pool liquidity
        if (_token.totalSupply == 0) {
            _price = 0;
        } else {
            _price = _token.poolLiquidity / _token.totalSupply;
        }
    }

    function calculateCollateralUnlockPercentage(uint256 repayUsdValue, uint256 totalCollateralUsd)
        internal
        pure
        returns (uint256)
    {
        if (totalCollateralUsd == 0) return 0;
        return (repayUsdValue * 100) / totalCollateralUsd;
    }
}
