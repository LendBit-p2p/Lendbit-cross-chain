// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.9;

import "../model/Protocol.sol";
import {LibInterestRateModel} from "../libraries/LibInterestRateModel.sol";
import {Constants} from "../utils/constants/Constant.sol";
import "../utils/validators/Error.sol";
/**
 * @title LibRateCalculations
 * @dev Library for calculating interest rates, APR and APY for lending protocols
 */
library LibRateCalculations {
  

    /**
     * @notice Calculates the Annual Percentage Rate (APR) using direct parameters
     * @param baseRate The base interest rate in basis points
     * @param slopeRate The slope of the interest rate curve in basis points
     * @param optimalUtilization The optimal utilization rate in basis points
     * @param totalBorrows Total borrowed amount
     * @param poolLiquidity Total available liquidity
     * @return apr The calculated APR in basis points
     */
    function calculateAPR(
        uint256 baseRate,
        uint256 slopeRate,
        uint256 optimalUtilization,
        uint256 totalBorrows,
        uint256 poolLiquidity
    ) internal pure returns (uint256 apr) {
        // Validate input parameters
        if (baseRate > Constants.MAX_APR_BASIS_POINTS) {
            revert Protocol__AprTooHigh();
        }

        if (slopeRate > Constants.MAX_APR_BASIS_POINTS) {
            revert Protocol__AprTooHigh();
        }

        if (optimalUtilization > Constants.BASIS_POINTS_SCALE) {
            revert Protocol__AprTooHigh();
        }

        if (poolLiquidity == 0) {
            revert Protocol__ZeroLiquidity();
        }

        if (totalBorrows > poolLiquidity) {
            revert Protocol__InvalidBorrows();
        }

        // Calculate utilization
        uint256 utilization = (totalBorrows * Constants.BASIS_POINTS_SCALE) / poolLiquidity;

        // Construct pool for interest rate calculation
        ProtocolPool memory pool = ProtocolPool({
            token: address(0),
            initialize: true,
            totalSupply: 0,
            totalBorrows: totalBorrows,
            reserveFactor: 0,
            optimalUtilization: optimalUtilization,
            baseRate: baseRate,
            slopeRate: slopeRate,
            isActive: true
        });

        // Calculate interest rate
        return LibInterestRateModel.calculateInterestRate(pool, utilization);
    }


    /**
     * @notice Calculates the Annual Percentage Yield (APY) from APR
     * @dev Uses compounding formula: APY = (1 + APR/n)^n - 1
     * @param apr The APR in basis points
     * @param compoundingPeriods Number of compounding periods per year
     * @return apy The calculated APY in basis points
     */
    function calculateAPY(uint256 apr, uint256 compoundingPeriods) internal pure returns (uint256 apy) {
        // Validate parameters
        if (apr > Constants.MAX_APR_BASIS_POINTS) {
            revert Protocol__AprTooHigh();
        }

        if (compoundingPeriods == 0) {
            revert Protocol__InvalidCompoundingPeriods();
        }

        // Convert APR from basis points to a fixed-point representation scaled by PRECISION_SCALE
        uint256 aprScaled = (apr * Constants.PRECISION_SCALE) / Constants.BASIS_POINTS_SCALE;

        // Calculate (1 + APR/n)
        uint256 compoundFactor = Constants.PRECISION_SCALE + (aprScaled / compoundingPeriods);

        // Approximate (1 + APR/n)^n using iteration
        uint256 result = Constants.PRECISION_SCALE;
        for (uint256 i = 0; i < compoundingPeriods; i++) {
            result = (result * compoundFactor) / Constants.PRECISION_SCALE;
        }

        // Convert back to basis points: APY = ((result - 1) * 10000)
        apy = ((result - Constants.PRECISION_SCALE) * Constants.BASIS_POINTS_SCALE) / Constants.PRECISION_SCALE;
    }

   
}
