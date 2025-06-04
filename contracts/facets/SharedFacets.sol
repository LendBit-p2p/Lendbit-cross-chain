// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../libraries/LibShared.sol";
import "../libraries/LibAppStorage.sol";
import "../utils/functions/AppStorage.sol";

/**

 */
contract SharedFacet is AppStorage {
    using LibShared for LibAppStorage.Layout;

    function depositCollateral(
        address _tokenCollateralAddress,
        uint256 _amountOfCollateral
    ) external payable {
        _appStorage._depositCollateral(
            _tokenCollateralAddress,
            _amountOfCollateral,
            msg.sender
        );
    }

    function withdrawCollateral(
        address _tokenCollateralAddress,
        uint256 _amountOfCollateral
    ) external {
        _appStorage._withdrawCollateral(
            _tokenCollateralAddress,
            _amountOfCollateral,
            msg.sender
        );
    }
}
