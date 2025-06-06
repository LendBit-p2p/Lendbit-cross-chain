// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.9;

import {LibGettersImpl} from "../libraries/LibGetters.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {LibProtocol} from "../libraries/LibProtocol.sol";
import {Validator} from "../utils/validators/Validator.sol";
import {Constants} from "../utils/constants/Constant.sol";
import {Utils} from "../utils/functions/Utils.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IUniswapV2Router02.sol";
import "../utils/functions/AppStorage.sol";
import "../model/Protocol.sol";
import "../model/Event.sol";
import "../utils/validators/Error.sol";

/**
 * @title ProtocolFacet
 * @author Lendbit Finance
 *
 * @dev Core contract of the Lending protocol that integrates operations and data access functions.
 * This contract combines essential functionalities from `Operations` and `Getters`, enabling
 * interactions with the protocol’s core features, such as loan requests and user information retrieval.
 *
 * This contract acts as a primary interface for protocol interactions, while `Operations`
 * contains core operational functions, and `Getters` allows querying data from the protocol.
 */
contract ProtocolFacet is AppStorage {
    using SafeERC20 for IERC20;
    using LibProtocol for LibAppStorage.Layout;

    /**
     * @dev Creates a new lending request by validating input parameters, calculating loanable amounts,
     *      and locking collateral proportional to the loan request.
     *
     * @param _amount The amount of loan requested by the borrower.
     * @param _interest The interest rate for the loan.
     * @param _returnDate The expected return date for the loan.
     * @param _loanCurrency The token address for the currency in which the loan is requested.
     *
     * Requirements:
     * - `_amount` must be greater than zero.
     * - `_loanCurrency` must be an approved loanable token.
     * - `_returnDate` must be at least 1 day in the future.
     * - The calculated USD value of `_amount` should meet the minimum loan amount requirement.
     * - Borrower must have sufficient collateral based on their collateral value and `_loanUsdValue`.
     *
     * The function locks collateral based on the proportional USD value of each token in the borrower’s
     * collateral, calculates the total repayment including interest, and stores loan request data.
     * Emits a `RequestCreated` event on successful request creation.
     */
    function createLendingRequest(uint128 _amount, uint16 _interest, uint256 _returnDate, address _loanCurrency)
        external
    {
        _appStorage._createLendingRequest(_amount, _interest, _returnDate, _loanCurrency, Constants.CHAIN_SELECTOR);
    }

    /**
     * @dev Services a lending request by transferring funds from the lender to the borrower and updating request status.
     * @param _requestId The ID of the lending request to service.
     * @param _tokenAddress The address of the token to be used for funding.
     *
     * Requirements:
     * - `_tokenAddress` must be the native token or the lender must have approved sufficient balance of the specified token.
     * - Request must be open, not expired, and authored by someone other than the lender.
     * - Lender must have sufficient balance and allowance for ERC20 tokens, or sufficient msg.value for native tokens.
     * - The borrower's collateral must have a healthy factor after the loan is funded.
     *
     * Emits a `RequestServiced` event upon successful funding.
     */
    function serviceRequest(uint96 _requestId, address _tokenAddress) external payable {
        // Validate the request and service it
        _appStorage._serviceRequest(_requestId, _tokenAddress, Constants.CHAIN_SELECTOR);
    }

    /**
     * @dev Closes a listing advertisement and transfers the remaining amount to the author.
     * @param _listingId The ID of the listing advertisement to be closed.
     *
     * Requirements:
     * - The listing must be in an OPEN status.
     * - Only the author of the listing can close it.
     * - The amount of the listing must be greater than zero.
     *
     * Emits a `withdrawnAdsToken` event indicating the author, listing ID, status, and amount withdrawn.
     */
    function closeListingAd(uint96 _listingId) external {
        _appStorage._closeListingAd(_listingId, Constants.CHAIN_SELECTOR);
    }

    /**
     * @dev Closes a lending request, updating its status to CLOSED.
     * @param _requestId The ID of the request to be closed.
     *
     * Requirements:
     * - The request must be in an OPEN status.
     * - Only the author of the request can close it.
     *
     * Emits a `RequestClosed` event indicating the request ID and the author of the request.
     */
    function closeRequest(uint96 _requestId) external {
        _appStorage._closeRequest(_requestId, Constants.CHAIN_SELECTOR);
    }

    /**
     * @dev Creates a loan listing for lenders to fund.
     * @param _amount The total amount being loaned.
     * @param _min_amount The minimum amount a lender can fund.
     * @param _max_amount The maximum amount a lender can fund.
     * @param _returnDate The date by which the loan should be repaid.
     * @param _interest The interest rate to be applied on the loan.
     * @param _loanCurrency The currency in which the loan is issued (token address).
     *
     * Requirements:
     * - The loan amount must be greater than zero.
     * - The currency must be a loanable token.
     * - If using a token, the sender must have sufficient balance and allowance.
     * - If using the native token, the amount must be sent as part of the transaction.
     *
     * Emits a `LoanListingCreated` event indicating the listing ID, author, and loan currency.
     */
    function createLoanListing(
        uint256 _amount,
        uint256 _min_amount,
        uint256 _max_amount,
        uint256 _returnDate,
        uint16 _interest,
        address _loanCurrency,
        address[] memory _whitelist
    ) external payable {
        _appStorage._createLoanListing(
            _amount,
            _min_amount,
            _max_amount,
            _returnDate,
            _interest,
            _loanCurrency,
            _whitelist,
            Constants.CHAIN_SELECTOR
        );
    }

    /**
     * @dev Allows a borrower to request a loan from an open listing.
     * @param _listingId The unique identifier of the loan listing.
     * @param _amount The requested loan amount.
     *
     * Requirements:
     * - `_amount` must be greater than zero.
     * - The listing must be open, not created by the borrower, and within min/max constraints.
     * - The borrower must have sufficient collateral to meet the health factor.
     *
     * Emits:
     * - `RequestCreated` when a loan request is successfully created.
     * - `RequestServiced` when the loan request is successfully serviced.
     */
    function requestLoanFromListing(uint96 _listingId, uint256 _amount) public {
        _appStorage._requestLoanFromListing(_listingId, _amount, Constants.CHAIN_SELECTOR);
    }

    /**
     * @dev Allows a borrower to repay a loan in part or in full.
     * @param _requestId The unique identifier of the loan request.
     * @param _amount The repayment amount.
     *
     * Requirements:
     * - `_amount` must be greater than zero.
     * - The loan request must be in the SERVICED status.
     * - The caller must be the borrower who created the loan request.
     * - If repaying in a token, the borrower must have sufficient balance and allowance.
     *
     * Emits:
     * - `LoanRepayment` upon successful repayment.
     */
    function repayLoan(uint96 _requestId, uint256 _amount) external payable {
        _appStorage._repayLoan(_requestId, _amount, Constants.CHAIN_SELECTOR);
    }

    // TODO: check the usefulness of this function and move to the appropriate facet
    // /**
    //  * @notice Liquidates an undercollateralized P2P loan and transfers assets
    //  * @dev This function performs the following actions:
    //  *      1. Verifies the loan is active and eligible for liquidation
    //  *      2. Calculates health factor based on collateral value vs loan value
    //  *      3. Repays the loan amount to the lender on behalf of the borrower
    //  *      4. Transfers collateral to the liquidator with a discount
    //  *      5. Sends liquidation fee to the protocol
    //  * @param requestId The unique identifier of the loan request to liquidate
    //  */
    function liquidateUserRequest(uint96 requestId) external payable {
        //     // Get the loan request from storage
        //     Request storage request = _appStorage.request[requestId];

        //     // Verify loan is in active state
        //     if (request.status != Status.SERVICED) {
        //         revert Protocol__RequestNotServiced();
        //     }

        //     if (request.author == msg.sender) {
        //         revert Protocol__OwnerCantLiquidateRequest();
        //     }

        //     // Store key loan details for easier reference and gas optimization
        //     address borrower = request.author;
        //     address lender = request.lender;
        //     address loanToken = request.loanRequestAddr;
        //     uint256 totalDebt = request.totalRepayment;

        //     // Calculate loan value in USD
        //     uint8 loanTokenDecimal = LibGettersImpl._getTokenDecimal(loanToken);
        //     uint256 loanUsdValue = LibGettersImpl._getUsdValue(_appStorage, loanToken, totalDebt, loanTokenDecimal);

        //     // Calculate total value of collateral in USD
        //     uint256 totalCollateralValue = 0;
        //     for (uint256 i = 0; i < request.collateralTokens.length; i++) {
        //         address collateralToken = request.collateralTokens[i];
        //         uint256 collateralAmount = _appStorage.s_idToCollateralTokenAmount[requestId][collateralToken];

        //         if (collateralAmount > 0) {
        //             uint8 collateralDecimal = LibGettersImpl._getTokenDecimal(collateralToken);
        //             totalCollateralValue +=
        //                 LibGettersImpl._getUsdValue(_appStorage, collateralToken, collateralAmount, collateralDecimal);
        //         }
        //     }

        //     // Check if loan is past due date (liquidation only allowed for overdue loans)
        //     bool isPastDue = block.timestamp > request.returnDate;
        //     // Verify loan is undercollateralized (health factor check)
        //     // Health factor broken when loan value exceeds collateral value
        //     bool isUnhealthy = loanUsdValue > totalCollateralValue;
        //     if (!isPastDue || !isUnhealthy) revert Protocol__NotLiquidatable();

        //     // Update request status to prevent re-entrancy and multiple liquidations
        //     request.status = Status.LIQUIDATED;

        //     // Handle debt repayment from liquidator to lender
        //     if (loanToken == Constants.NATIVE_TOKEN) {
        //         // For native token (ETH), ensure sufficient ETH was sent
        //         if (msg.value < totalDebt) revert Protocol__InsufficientETH();

        //         // Refund excess ETH to liquidator
        //         uint256 excess = msg.value - totalDebt;
        //         if (excess > 0) {
        //             (bool refundSent,) = payable(msg.sender).call{value: excess}("");
        //             if (!refundSent) revert Protocol__RefundFailed();
        //         }

        //         // Transfer the debt amount to the lender
        //         (bool lenderSent,) = payable(lender).call{value: totalDebt}("");
        //         if (!lenderSent) revert Protocol__ETHTransferFailed();
        //     } else {
        //         // For ERC20 tokens, transfer from liquidator to lender
        //         IERC20(loanToken).safeTransferFrom(msg.sender, lender, totalDebt);
        //     }

        //     // Process each collateral token and transfer to liquidator with discount
        //     for (uint256 i = 0; i < request.collateralTokens.length; i++) {
        //         address collateralToken = request.collateralTokens[i];
        //         uint256 collateralAmount = _appStorage.s_idToCollateralTokenAmount[requestId][collateralToken];

        //         if (collateralAmount > 0) {
        //             // Calculate discounted amount (apply liquidation discount)
        //             uint256 discountedAmount = (collateralAmount * (10000 - Constants.LIQUIDATION_DISCOUNT)) / 10000;

        //             // Transfer discounted amount to liquidator
        //             if (collateralToken == Constants.NATIVE_TOKEN) {
        //                 (bool sent,) = payable(msg.sender).call{value: discountedAmount}("");
        //                 if (!sent) revert Protocol__ETHTransferFailed();
        //             } else {
        //                 IERC20(collateralToken).safeTransfer(msg.sender, discountedAmount);
        //             }

        //             // The difference between original collateral and discounted amount goes to protocol as fee
        //             uint256 protocolAmount = collateralAmount - discountedAmount;
        //             if (protocolAmount > 0 && _appStorage.s_protocolFeeRecipient != address(0)) {
        //                 if (collateralToken == Constants.NATIVE_TOKEN) {
        //                     (bool sent,) = payable(_appStorage.s_protocolFeeRecipient).call{value: protocolAmount}("");
        //                     if (!sent) revert Protocol__ETHFeeTransferFailed();
        //                 } else {
        //                     IERC20(collateralToken).safeTransfer(_appStorage.s_protocolFeeRecipient, protocolAmount);
        //                 }
        //             }

        //             // Reset collateral tracking to prevent double-spending
        //             _appStorage.s_idToCollateralTokenAmount[requestId][collateralToken] = 0;
        //         }
        //     }

        //     // Update liquidator's activity metrics for potential rewards
        //     User storage liquidator = _appStorage.addressToUser[msg.sender];
        //     liquidator.totalLiquidationAmount += totalCollateralValue;

        //     // Emit event for off-chain tracking and transparency
        //     emit RequestLiquidated(requestId, msg.sender, borrower, lender, totalCollateralValue);
    }
}
