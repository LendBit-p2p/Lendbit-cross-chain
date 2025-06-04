// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LibDiamond} from "../libraries/LibDiamond.sol";
import {IERC173} from "../interfaces/IERC173.sol";
import {AppStorage} from "../utils/functions/AppStorage.sol";

contract OwnershipFacet is IERC173, AppStorage {
    function transferOwnership(address _newOwner) external override {
        LibDiamond.enforceIsContractOwner();
        LibDiamond.setContractOwner(_newOwner);
    }

    function owner() external view override returns (address owner_) {
        owner_ = LibDiamond.contractOwner();
    }

    /**
     * @notice Sets the active status of a protocol pool
     * @param token The address of the token
     * @param isActive The new active status
     */
    function setPoolActive(address token, bool isActive) external {
        LibDiamond.enforceIsContractOwner();
        _appStorage.s_protocolPool[token].isActive = isActive;
    }
}
