// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @dev Holds all the constant for our protocol
library Constants {
    uint256 constant NEW_PRECISION = 1e10;
    uint256 constant PRECISION = 1e18;
    uint256 constant LIQUIDATION_THRESHOLD = 80;
    uint256 constant MIN_HEALTH_FACTOR = 1;
    uint256 constant COLLATERALIZATION_RATIO = 80;
    address constant NATIVE_TOKEN = address(1);
    address constant WETH = 0x4200000000000000000000000000000000000006;
    uint256 constant MAX_LIQUIDATION_BONUS = 10000; // 100%
    uint256 constant LIQUIDATION_DISCOUNT = 1000; // 10%
    uint256 constant MAX_RESERVE_FACTOR = 5000; // 50%

    // Constants to avoid magic numbers
    uint256 constant BASIS_POINTS_SCALE = 1e4; // 100% = 10000 basis points
    uint256 constant PRECISION_SCALE = 1e18; // High precision for calculations
    uint256 constant MAX_APR_BASIS_POINTS = 1e6; // Maximum 10000% APR
    uint256 constant DEFAULT_COMPOUNDING_PERIODS = 12; // Monthly compounding
}
