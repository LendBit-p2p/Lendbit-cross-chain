// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LibDiamond} from "../libraries/LibDiamond.sol";
import {IERC173} from "../interfaces/IERC173.sol";
import {AppStorage} from "../utils/functions/AppStorage.sol";
import {ProtocolPool, TokenData, UserBorrowData} from "../model/Protocol.sol";
import {Constants} from "../utils/constants/Constant.sol";
import "../utils/validators/Error.sol";
import "../model/Event.sol";

contract OwnershipFacet is IERC173, AppStorage {
    function transferOwnership(address _newOwner) external override {
        LibDiamond.enforceIsContractOwner();
        LibDiamond.setContractOwner(_newOwner);
    }

    function owner() external view override returns (address owner_) {
        owner_ = LibDiamond.contractOwner();
    }

    /**
     * @notice Initializes the protocol pool with the given parameters
     * @dev Only callable by contract owner
     * @param _token The address of the token to be used in the protocol pool
     * @param reserveFactor The reserve factor for the protocol pool (percentage of interest that goes to reserves)
     * @param optimalUtilization The optimal utilization rate for the protocol pool (in basis points, 10000 = 100%)
     * @param baseRate The base interest rate for the protocol pool (in basis points)
     * @param slopeRate The slope rate for the protocol pool (determines how quickly interest rates increase)
     */
    function initializeProtocolPool(
        address _token,
        uint256 reserveFactor,
        uint256 optimalUtilization,
        uint256 baseRate,
        uint256 slopeRate // uint256 initialSupply
    ) external {
        // Check caller is contract owner
        LibDiamond.enforceIsContractOwner();

        // Validate protocol state
        if (_appStorage.s_protocolPool[_token].isActive) {
            revert ProtocolPool__IsNotActive();
        }
        if (_appStorage.s_protocolPool[_token].initialize) {
            revert ProtocolPool__AlreadyInitialized();
        }
        if (!_appStorage.s_isLoanable[_token]) {
            revert ProtocolPool__TokenNotSupported();
        }

        // Validate parameters
        require(
            reserveFactor <= Constants.MAX_RESERVE_FACTOR,
            "Reserve factor too high"
        );
        require(optimalUtilization <= 9000, "Optimal utilization too high");
        require(baseRate <= 1000, "Base rate too high");

        ProtocolPool storage _protocolPool = _appStorage.s_protocolPool[_token];

        // Set protocol pool parameters
        _protocolPool.token = _token;
        _protocolPool.reserveFactor = reserveFactor;
        _protocolPool.optimalUtilization = optimalUtilization;
        _protocolPool.baseRate = baseRate;
        _protocolPool.slopeRate = slopeRate;
        _protocolPool.isActive = true;
        _protocolPool.initialize = true;

        // Initialize token data
        _appStorage.s_tokenData[_token].lastUpdateTimestamp = block.timestamp;
        _appStorage.s_tokenData[_token].borrowIndex = 1e18; // Initialize with 1.0 in 18 decimals

        emit ProtocolPoolInitialized(_token, reserveFactor);
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

    /**
     * @notice Sets the protocol fee recipient
     * @param _feeRecipient The address of the fee recipient
     */
    function setProtocolFeeRecipient(address _feeRecipient) external {
        LibDiamond.enforceIsContractOwner();
        _appStorage.s_protocolFeeRecipient = _feeRecipient;
        emit ProtocolFeeRecipientSet(_feeRecipient);
    }

    /**
     * @notice Sets the protocol fee rate
     * @param _rateBps The new fee rate
     */
    function setFeeRate(uint16 _rateBps) external {
        LibDiamond.enforceIsContractOwner();
        require(_rateBps <= 1000, "rate cannot exceed 10%");

        _appStorage.feeRateBps = _rateBps;
    }
}
