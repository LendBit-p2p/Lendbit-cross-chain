// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.9;

import "../model/Protocol.sol";

/**
 * @title LibInterestRateModel
 * @dev Library for calculating interest rates and utilization in a lending protocol
 */
library LibInterestRateModel {
    /**
     * @notice Calculates the interest rate based on utilization
     * @param pool The protocol pool configuration
     * @param utilization The current utilization rate (0-10000)
     * @return The interest rate in basis points (1-10000)
     */
    function calculateInterestRate(ProtocolPool memory pool, uint256 utilization) internal pure returns (uint256) {
        if (utilization <= pool.optimalUtilization) {
            // Correct formula: baseRate + (slopeRate * utilization / optimalUtilization)
            return pool.baseRate + ((pool.slopeRate * utilization) / pool.optimalUtilization);
        } else {
            // For high utilization (above optimal):
            // baseRate + slopeRate + (slopeRate * 2 * excessUtilization / maxExcessUtilization)
            uint256 excessUtilization = utilization - pool.optimalUtilization;
            uint256 maxExcessUtilization = 10000 - pool.optimalUtilization;
            uint256 slopeComponent = (pool.slopeRate * 2 * excessUtilization) / maxExcessUtilization;

            return pool.baseRate + pool.slopeRate + slopeComponent;
        }
    }

    /**
     * @notice Calculates the current utilization rate
     * @param totalBorrows Total borrowed from the pool
     * @param poolLiquidity Total available liquidity
     * @return The utilization rate in basis points (1-10000)
     */
    function calculateUtilization(uint256 totalBorrows, uint256 poolLiquidity) internal pure returns (uint256) {
        if (poolLiquidity + totalBorrows == 0) return 0;

        return (totalBorrows * 10000) / (poolLiquidity + totalBorrows);
    }
}
