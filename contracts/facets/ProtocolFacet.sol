// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.9;

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
    function createLendingRequest(
        uint128 _amount,
        uint16 _interest,
        uint256 _returnDate,
        address _loanCurrency
    ) external {
        _appStorage._createLendingRequest(
            _amount,
            _interest,
            _returnDate,
            _loanCurrency,
            Constants.CHAIN_SELECTOR
        );
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
    function serviceRequest(
        uint96 _requestId,
        address _tokenAddress
    ) external payable {
        // Validate the request and service it
        _appStorage._serviceRequest(
            _requestId,
            _tokenAddress,
            Constants.CHAIN_SELECTOR
        );
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
        _appStorage._requestLoanFromListing(
            _listingId,
            _amount,
            Constants.CHAIN_SELECTOR
        );
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
}
