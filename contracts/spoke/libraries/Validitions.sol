// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from
    "@chainlink/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import "./Errors.sol";

library Validitions {
    address public constant NATIVE_TOKEN = address(1);

    function validateTokenParams(address _tokenCollateralAddress, uint256 _amountOfCollateral) internal view {
        if (_amountOfCollateral < 1) {
            revert Spoke__CollateralAmountTooLow();
        }

        if (_tokenCollateralAddress == NATIVE_TOKEN) {
            if (msg.value < _amountOfCollateral) {
                revert Spoke__InsufficientCollateral();
            }
        }

        if (_tokenCollateralAddress == address(0)) {
            revert Spoke__InvalidCollateralToken();
        }

        if (
            _tokenCollateralAddress != NATIVE_TOKEN
                && IERC20(_tokenCollateralAddress).balanceOf(msg.sender) < _amountOfCollateral
        ) {
            revert Spoke__InsufficientCollateral();
        }
    }
}
