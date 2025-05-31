// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.9;

import {LibInterestRateModel} from "./LibInterestRateModel.sol";
import "../model/Protocol.sol";

/**
 * @title LibInterestAccure
 * @dev Library for calculating interest accrual in a lending protocol
 */
library LibInterestAccure {
    /**
     * @notice Updates the borrow index based on elapsed time and interest rate
     * @param tokenData The token data to update
     * @param pool The protocol pool configuration
     */
    function updateBorrowIndex(TokenData storage tokenData, ProtocolPool memory pool) internal {
        uint256 lastUpdateTimestamp = tokenData.lastUpdateTimestamp;
        // If no time has passed or no borrows, nothing to update
        if (block.timestamp == lastUpdateTimestamp || tokenData.totalBorrows == 0) {
            return;
        }
        // Initialize the borrow index if it's not set yet
        if (tokenData.borrowIndex == 0) {
            tokenData.borrowIndex = 1e18; // Initialize with 1.0
        }
        // Calculate time elapsed since last update
        uint256 timeElapsed = block.timestamp - lastUpdateTimestamp;
        // tells how much of the pool is being used
        uint256 utilization = LibInterestRateModel.calculateUtilization(tokenData.totalBorrows, tokenData.poolLiquidity);
        // Calculate the interest rate based on utilization ( tells how much of the pool is being used)
        uint256 interestRate = LibInterestRateModel.calculateInterestRate(pool, utilization);

        // Calculate accumulated interest (annual rate * time fraction)
        // interestRate is in basis points (1/100 of a percent)
        // 10000 basis points = 100%
        // 365 days * 24 hours * 60 minutes * 60 seconds = 31536000 seconds in a year
        uint256 interestAccumulated = (tokenData.totalBorrows * interestRate * timeElapsed) / (10000 * 31536000);

        // Calculate portion that goes to reserves
        uint256 reservePortion = (interestAccumulated * pool.reserveFactor) / 10000;

        // Update total borrows and reserves
        tokenData.totalBorrows += interestAccumulated;
        tokenData.totalReserves += reservePortion;

        // Update the borrow index
        // borrows * (1 + (rate * time) / 365 days)
        uint256 factor = ((interestRate * timeElapsed) * 1e18) / (10000 * 31536000);
        tokenData.borrowIndex = tokenData.borrowIndex + ((tokenData.borrowIndex * factor) / 1e18);

        // Update timestamp
        tokenData.lastUpdateTimestamp = block.timestamp;
    }
}
