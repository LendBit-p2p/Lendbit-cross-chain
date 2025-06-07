// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LibDiamond} from "../libraries/LibDiamond.sol";
import {IERC173} from "../interfaces/IERC173.sol";
import {AppStorage} from "../utils/functions/AppStorage.sol";
import {ProtocolPool, TokenData, UserBorrowData} from "../model/Protocol.sol";
import {Constants} from "../utils/constants/Constant.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../utils/validators/Error.sol";
import "../model/Event.sol";

contract OwnershipFacet is AppStorage, IERC173 {
    using SafeERC20 for IERC20;

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
        require(reserveFactor <= Constants.MAX_RESERVE_FACTOR, "Reserve factor too high");
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

    /**
     * @notice Withdraws fees from the protocol
     * @dev Only callable by contract owner
     * @param _token The address of the token to withdraw
     * @param _to The address to send the fees to
     * @param amount The amount of fees to withdraw
     */
    function withdrawFees(address _token, address _to, uint256 amount) external {
        LibDiamond.enforceIsContractOwner();
        require(_to != address(0), "invalid address");

        uint256 _feesAccrued = _appStorage.s_feesAccrued[_token];
        require(_feesAccrued >= amount, "insufficient fees");
        _appStorage.s_feesAccrued[_token] = _feesAccrued - amount;
        if (_token == Constants.NATIVE_TOKEN) {
            (bool sent,) = payable(_to).call{value: amount}("");
            require(sent, "failed to send Ether");
        } else {
            IERC20(_token).safeTransfer(_to, amount);
        }
        emit FeesWithdrawn(_to, _token, amount);
    }

    /**
     * @dev Adds new collateral tokens along with their respective price feeds to the protocol.
     * @param _tokens An array of token addresses to add as collateral.
     * @param _priceFeeds An array of corresponding price feed addresses for the tokens.
     *
     * Requirements:
     * - Only the contract owner can call this function.
     * - The `_tokens` and `_priceFeeds` arrays must have the same length.
     *
     * Emits an `UpdatedCollateralTokens` event with the total number of collateral tokens added.
     */
    function addCollateralTokens(address[] memory _tokens, address[] memory _priceFeeds) external {
        // Ensure only the contract owner can add collateral tokens
        LibDiamond.enforceIsContractOwner();

        // Validate that the tokens and price feeds arrays have the same length
        if (_tokens.length != _priceFeeds.length) {
            revert Protocol__tokensAndPriceFeedsArrayMustBeSameLength();
        }

        // Loop through each token to set its price feed and add it to the collateral list
        for (uint8 i = 0; i < _tokens.length; i++) {
            _appStorage.s_priceFeeds[_tokens[i]] = _priceFeeds[i]; // Map token to price feed
            _appStorage.s_collateralToken.push(_tokens[i]); // Add token to collateral array
        }

        // Emit an event indicating the updated number of collateral tokens
        emit UpdatedCollateralTokens(msg.sender, uint8(_appStorage.s_collateralToken.length));
    }

    /**
     * @dev Removes specified collateral tokens and their associated price feeds from the protocol.
     * @param _tokens An array of token addresses to be removed as collateral.
     *
     * Requirements:
     * - Only the contract owner can call this function.
     *
     * Emits an `UpdatedCollateralTokens` event with the updated total number of collateral tokens.
     */
    function removeCollateralTokens(address[] memory _tokens) external {
        // Ensure only the contract owner can remove collateral tokens
        LibDiamond.enforceIsContractOwner();

        // Loop through each token to remove it from collateral and reset its price feed
        for (uint8 i = 0; i < _tokens.length; i++) {
            _appStorage.s_priceFeeds[_tokens[i]] = address(0); // Remove the price feed for the token

            // Search for the token in the collateral array
            for (uint8 j = 0; j < _appStorage.s_collateralToken.length; j++) {
                if (_appStorage.s_collateralToken[j] == _tokens[i]) {
                    // Replace the token to be removed with the last token in the array
                    _appStorage.s_collateralToken[j] =
                        _appStorage.s_collateralToken[_appStorage.s_collateralToken.length - 1];

                    // Remove the last token from the array
                    _appStorage.s_collateralToken.pop();
                    break; // Stop searching once the token is found and removed
                }
            }
        }

        // Emit an event indicating the updated count of collateral tokens
        emit UpdatedCollateralTokens(msg.sender, uint8(_appStorage.s_collateralToken.length));
    }

    /**
     * @dev Adds a new token as a loanable token and associates it with a price feed.
     * @param _token The address of the token to be added as loanable.
     * @param _priceFeed The address of the price feed for the loanable token.
     *
     * Requirements:
     * - Only the contract owner can call this function.
     *
     * Emits an `UpdateLoanableToken` event indicating the new loanable token and its price feed.
     */
    function addLoanableToken(address _token, address _priceFeed) external {
        // Ensure only the contract owner can add loanable tokens
        LibDiamond.enforceIsContractOwner();

        // Mark the token as loanable
        _appStorage.s_isLoanable[_token] = true;

        // Associate the token with its price feed
        _appStorage.s_priceFeeds[_token] = _priceFeed;

        // Add the loanable token to the list of loanable tokens
        _appStorage.s_loanableToken.push(_token);

        // Emit an event to notify that a loanable token has been added
        emit UpdateLoanableToken(_token, _priceFeed, msg.sender);
    }
}
