// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
// TODO: to keep or to remove completely

// import {AppStorage} from "./AppStorage.sol";
// import {LibGettersImpl} from "../../libraries/LibGetters.sol";
// import {LibDiamond} from "../../libraries/LibDiamond.sol";
// import {Validator} from "../validators/Validator.sol";
// import {Constants} from "../constants/Constant.sol";
// import {Utils} from "./Utils.sol";
// import "../../interfaces/IUniswapV2Router02.sol";
// import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "../../model/Protocol.sol";
// import "../../model/Event.sol";
// import "../validators/Error.sol";

// /**
//  * @title Operations
//  * @author LendBit Finance
//  *
//  * Public write-only functions that allows writing into the state of LendBit
//  */
// contract Operations is AppStorage {
//     using SafeERC20 for IERC20;

//     /**
//      * @dev Creates a new lending request by validating input parameters, calculating loanable amounts,
//      *      and locking collateral proportional to the loan request.
//      *
//      * @param _amount The amount of loan requested by the borrower.
//      * @param _interest The interest rate for the loan.
//      * @param _returnDate The expected return date for the loan.
//      * @param _loanCurrency The token address for the currency in which the loan is requested.
//      *
//      * Requirements:
//      * - `_amount` must be greater than zero.
//      * - `_loanCurrency` must be an approved loanable token.
//      * - `_returnDate` must be at least 1 day in the future.
//      * - The calculated USD value of `_amount` should meet the minimum loan amount requirement.
//      * - Borrower must have sufficient collateral based on their collateral value and `_loanUsdValue`.
//      *
//      * The function locks collateral based on the proportional USD value of each token in the borrower’s
//      * collateral, calculates the total repayment including interest, and stores loan request data.
//      * Emits a `RequestCreated` event on successful request creation.
//      */
//     function createLendingRequest(uint128 _amount, uint16 _interest, uint256 _returnDate, address _loanCurrency)
//         external
//     {
//         // Validate that the loan amount is greater than zero
//         Validator._moreThanZero(_amount);

//         // Check if the loan currency is allowed by validating it against allowed loanable tokens
//         if (!_appStorage.s_isLoanable[_loanCurrency]) {
//             revert Protocol__TokenNotLoanable();
//         }

//         // Ensure the return date is at least 1 day in the future
//         if ((_returnDate - block.timestamp) < 1 days) {
//             revert Protocol__DateMustBeInFuture();
//         }

//         // Retrieve the loan currency's decimal precision
//         uint8 decimal = LibGettersImpl._getTokenDecimal(_loanCurrency);

//         // Calculate the USD equivalent of the loan amount
//         uint256 _loanUsdValue = LibGettersImpl._getUsdValue(_appStorage, _loanCurrency, _amount, decimal);

//         // Ensure that the USD value of the loan is valid and meets minimum requirements
//         if (_loanUsdValue < 1) revert Protocol__InvalidAmount();

//         // Get the total USD collateral value for the borrower
//         uint256 collateralValueInLoanCurrency = LibGettersImpl._getAccountCollateralValue(_appStorage, msg.sender);

//         // Calculate the maximum loanable amount based on available collateral
//         uint256 maxLoanableAmount = Utils.maxLoanableAmount(collateralValueInLoanCurrency);

//         // Check if the loan exceeds the user's collateral allowance
//         if (_appStorage.addressToUser[msg.sender].totalLoanCollected + _loanUsdValue >= maxLoanableAmount) {
//             revert Protocol__InsufficientCollateral();
//         }

//         // Retrieve collateral tokens associated with the borrower
//         address[] memory _collateralTokens = LibGettersImpl._getUserCollateralTokens(_appStorage, msg.sender);

//         // Increment the request ID and initialize the new loan request
//         _appStorage.requestId = _appStorage.requestId + 1;
//         Request storage _newRequest = _appStorage.request[_appStorage.requestId];
//         _newRequest.requestId = _appStorage.requestId;
//         _newRequest.author = msg.sender;
//         _newRequest.amount = _amount;
//         _newRequest.interest = _interest;
//         _newRequest.returnDate = _returnDate;
//         _newRequest.totalRepayment = Utils.calculateLoanInterest(_returnDate, _amount, _interest);
//         _newRequest.loanRequestAddr = _loanCurrency;
//         _newRequest.collateralTokens = _collateralTokens;
//         _newRequest.status = Status.OPEN;

//         // Calculate the amount of collateral to lock based on the loan value
//         uint256 collateralToLock = Utils.calculateColateralToLock(_loanUsdValue, maxLoanableAmount);

//         // For each collateral token, lock an appropriate amount based on its USD value
//         for (uint256 i = 0; i < _collateralTokens.length; i++) {
//             address token = _collateralTokens[i];
//             uint8 _decimalToken = LibGettersImpl._getTokenDecimal(token);
//             uint256 userBalance = _appStorage.s_addressToCollateralDeposited[msg.sender][token];

//             // Calculate the amount to lock in USD for each token based on the proportional collateral
//             uint256 amountToLockUSD =
//                 (LibGettersImpl._getUsdValue(_appStorage, token, userBalance, _decimalToken) * collateralToLock) / 100;

//             // Convert USD amount to token amount and apply the correct decimal scaling
//             uint256 amountToLock = (
//                 (((amountToLockUSD) * 10) / LibGettersImpl._getUsdValue(_appStorage, token, 10, 0))
//                     * (10 ** _decimalToken)
//             ) / (Constants.PRECISION);

//             // Store the locked amount for each collateral token
//             _appStorage.s_idToCollateralTokenAmount[_appStorage.requestId][token] = amountToLock;
//         }

//         // Emit an event for the created loan request
//         emit RequestCreated(msg.sender, _appStorage.requestId, _amount, _interest, Constants.CHAIN_SELECTOR);
//     }

//     /**
//      * @dev Services a lending request by transferring funds from the lender to the borrower and updating request status.
//      * @param _requestId The ID of the lending request to service.
//      * @param _tokenAddress The address of the token to be used for funding.
//      *
//      * Requirements:
//      * - `_tokenAddress` must be the native token or the lender must have approved sufficient balance of the specified token.
//      * - Request must be open, not expired, and authored by someone other than the lender.
//      * - Lender must have sufficient balance and allowance for ERC20 tokens, or sufficient msg.value for native tokens.
//      * - The borrower's collateral must have a healthy factor after the loan is funded.
//      *
//      * Emits a `RequestServiced` event upon successful funding.
//      */
//     function serviceRequest(uint96 _requestId, address _tokenAddress) external payable {
//         // Validate if native token is being used and msg.value is non-zero
//         Validator._nativeMoreThanZero(_tokenAddress, msg.value);

//         // Load the request from storage
//         Request storage _foundRequest = _appStorage.request[_requestId];

//         // Ensure the request status is open and has not expired
//         if (_foundRequest.status != Status.OPEN) {
//             revert Protocol__RequestNotOpen();
//         }
//         if (_foundRequest.loanRequestAddr != _tokenAddress) {
//             revert Protocol__InvalidToken();
//         }
//         if (_foundRequest.author == msg.sender) {
//             revert Protocol__CantFundSelf();
//         }
//         if (_foundRequest.returnDate <= block.timestamp) {
//             revert Protocol__RequestExpired();
//         }

//         // Update lender and request status to indicate servicing
//         _foundRequest.lender = msg.sender;
//         _foundRequest.status = Status.SERVICED;
//         uint256 amountToLend = _foundRequest.amount;

//         // Validate lender's balance and allowance if using ERC20 token, or msg.value if using native token
//         if (_tokenAddress == Constants.NATIVE_TOKEN) {
//             if (msg.value < amountToLend) {
//                 revert Protocol__InsufficientAmount();
//             }
//         } else {
//             if (IERC20(_tokenAddress).balanceOf(msg.sender) < amountToLend) {
//                 revert Protocol__InsufficientBalance();
//             }
//             if (IERC20(_tokenAddress).allowance(msg.sender, address(this)) < amountToLend) {
//                 revert Protocol__InsufficientAllowance();
//             }
//         }

//         // Get token's decimal value and calculate the loan's USD equivalent
//         uint8 _decimalToken = LibGettersImpl._getTokenDecimal(_tokenAddress);
//         uint256 _loanUsdValue = LibGettersImpl._getUsdValue(_appStorage, _tokenAddress, amountToLend, _decimalToken);

//         // Calculate the total repayment amount including interest
//         uint256 _totalRepayment =
//             Utils.calculateLoanInterest(_foundRequest.returnDate, _foundRequest.amount, _foundRequest.interest);
//         _foundRequest.totalRepayment = _totalRepayment;

//         // Update total loan collected in USD for the borrower
//         _appStorage.addressToUser[_foundRequest.author].totalLoanCollected +=
//             LibGettersImpl._getUsdValue(_appStorage, _tokenAddress, _totalRepayment, _decimalToken);

//         // Validate borrower's collateral health factor after loan
//         if (LibGettersImpl._healthFactor(_appStorage, _foundRequest.author, _loanUsdValue) < 1) {
//             revert Protocol__InsufficientCollateral();
//         }

//         // Lock collateral amounts in the specified tokens for the request
//         for (uint256 i = 0; i < _foundRequest.collateralTokens.length; i++) {
//             _appStorage.s_addressToAvailableBalance[_foundRequest.author][_foundRequest.collateralTokens[i]] -=
//                 _appStorage.s_idToCollateralTokenAmount[_requestId][_foundRequest.collateralTokens[i]];
//         }

//         // Transfer loan amount to borrower based on token type
//         if (_tokenAddress != Constants.NATIVE_TOKEN) {
//             IERC20(_tokenAddress).safeTransferFrom(msg.sender, _foundRequest.author, amountToLend);
//         } else {
//             (bool sent,) = payable(_foundRequest.author).call{value: amountToLend}("");

//             if (!sent) revert Protocol__TransferFailed();
//         }

//         // Emit an event indicating successful servicing of the request
//         emit RequestServiced(_requestId, msg.sender, _foundRequest.author, amountToLend);
//     }

//     /**
//      * @dev Closes a listing advertisement and transfers the remaining amount to the author.
//      * @param _listingId The ID of the listing advertisement to be closed.
//      *
//      * Requirements:
//      * - The listing must be in an OPEN status.
//      * - Only the author of the listing can close it.
//      * - The amount of the listing must be greater than zero.
//      *
//      * Emits a `withdrawnAdsToken` event indicating the author, listing ID, status, and amount withdrawn.
//      */
//     function closeListingAd(uint96 _listingId) external {
//         // Retrieve the loan listing associated with the given listing ID
//         LoanListing storage _newListing = _appStorage.loanListings[_listingId];

//         // Check if the listing is OPEN; revert if it's not
//         if (_newListing.listingStatus != ListingStatus.OPEN) {
//             revert Protocol__OrderNotOpen();
//         }

//         // Ensure that the caller is the author of the listing; revert if not
//         if (_newListing.author != msg.sender) {
//             revert Protocol__OwnerCreatedOrder();
//         }

//         // Ensure the amount is greater than zero; revert if it is zero
//         if (_newListing.amount == 0) revert Protocol__MustBeMoreThanZero();

//         // Store the amount to be transferred and reset the listing amount to zero
//         uint256 _amount = _newListing.amount;
//         _newListing.amount = 0; // Prevent re-entrancy by setting amount to zero
//         _newListing.listingStatus = ListingStatus.CLOSED; // Update listing status to CLOSED

//         // Handle the transfer of funds based on whether the token is native or ERC20
//         if (_newListing.tokenAddress == Constants.NATIVE_TOKEN) {
//             // Transfer native tokens (ETH) to the author
//             (bool sent,) = payable(msg.sender).call{value: _amount}("");
//             if (!sent) revert Protocol__TransferFailed(); // Revert if the transfer fails
//         } else {
//             // Transfer ERC20 tokens to the author
//             IERC20(_newListing.tokenAddress).safeTransfer(msg.sender, _amount);
//         }

//         // Emit an event to notify that the listing has been closed and tokens have been withdrawn
//         emit withdrawnAdsToken(msg.sender, _listingId, uint8(_newListing.listingStatus), _amount);
//     }

//     /**
//      * @dev Closes a lending request, updating its status to CLOSED.
//      * @param _requestId The ID of the request to be closed.
//      *
//      * Requirements:
//      * - The request must be in an OPEN status.
//      * - Only the author of the request can close it.
//      *
//      * Emits a `RequestClosed` event indicating the request ID and the author of the request.
//      */
//     function closeRequest(uint96 _requestId) external {
//         // Retrieve the lending request associated with the given request ID
//         Request storage _foundRequest = _appStorage.request[_requestId];

//         // Check if the request is OPEN; revert if it's not
//         if (_foundRequest.status != Status.OPEN) {
//             revert Protocol__RequestNotOpen();
//         }

//         // Ensure that the caller is the author of the request; revert if not
//         if (_foundRequest.author != msg.sender) revert Protocol__NotOwner();

//         // Update the request status to CLOSED
//         _foundRequest.status = Status.CLOSED;

//         // Emit an event to notify that the request has been closed
//         emit RequestClosed(_requestId, msg.sender);
//     }

//     /**
//      * @dev Creates a loan listing for lenders to fund.
//      * @param _amount The total amount being loaned.
//      * @param _min_amount The minimum amount a lender can fund.
//      * @param _max_amount The maximum amount a lender can fund.
//      * @param _returnDate The date by which the loan should be repaid.
//      * @param _interest The interest rate to be applied on the loan.
//      * @param _loanCurrency The currency in which the loan is issued (token address).
//      *
//      * Requirements:
//      * - The loan amount must be greater than zero.
//      * - The currency must be a loanable token.
//      * - If using a token, the sender must have sufficient balance and allowance.
//      * - If using the native token, the amount must be sent as part of the transaction.
//      *
//      * Emits a `LoanListingCreated` event indicating the listing ID, author, and loan currency.
//      */
//     function createLoanListing(
//         uint256 _amount,
//         uint256 _min_amount,
//         uint256 _max_amount,
//         uint256 _returnDate,
//         uint16 _interest,
//         address _loanCurrency,
//         address[] memory _whitelist
//     ) external payable {
//         // Validate that the amount is greater than zero and that a value has been sent if using native token
//         Validator._valueMoreThanZero(_amount, _loanCurrency, msg.value);
//         Validator._moreThanZero(_amount);

//         // Ensure the specified loan currency is a loanable token
//         if (!_appStorage.s_isLoanable[_loanCurrency]) {
//             revert Protocol__TokenNotLoanable();
//         }

//         // Check for sufficient balance and allowance if using a token other than native
//         if (_loanCurrency != Constants.NATIVE_TOKEN) {
//             if (IERC20(_loanCurrency).balanceOf(msg.sender) < _amount) {
//                 revert Protocol__InsufficientBalance();
//             }

//             if (IERC20(_loanCurrency).allowance(msg.sender, address(this)) < _amount) {
//                 revert Protocol__InsufficientAllowance();
//             }
//         }

//         // If using the native token, set the amount to the value sent with the transaction
//         if (_loanCurrency == Constants.NATIVE_TOKEN) {
//             _amount = msg.value;
//         }

//         // Transfer the specified amount from the user to the contract if using a token
//         if (_loanCurrency != Constants.NATIVE_TOKEN) {
//             IERC20(_loanCurrency).safeTransferFrom(msg.sender, address(this), _amount);
//         }

//         // Increment the listing ID to create a new loan listing
//         _appStorage.listingId = _appStorage.listingId + 1;
//         LoanListing storage _newListing = _appStorage.loanListings[_appStorage.listingId];

//         // Populate the loan listing struct with the provided details
//         _newListing.listingId = _appStorage.listingId;
//         _newListing.author = msg.sender;
//         _newListing.amount = _amount;
//         _newListing.min_amount = _min_amount;
//         _newListing.max_amount = _max_amount;
//         _newListing.interest = _interest;
//         _newListing.returnDate = _returnDate;
//         _newListing.tokenAddress = _loanCurrency;
//         _newListing.listingStatus = ListingStatus.OPEN;
//         _newListing.whitelist = _whitelist;

//         // Emit an event to notify that a new loan listing has been created
//         emit LoanListingCreated(_appStorage.listingId, msg.sender, _loanCurrency, _amount);
//     }

//     /**
//      * @dev Allows a borrower to request a loan from an open listing.
//      * @param _listingId The unique identifier of the loan listing.
//      * @param _amount The requested loan amount.
//      *
//      * Requirements:
//      * - `_amount` must be greater than zero.
//      * - The listing must be open, not created by the borrower, and within min/max constraints.
//      * - The borrower must have sufficient collateral to meet the health factor.
//      *
//      * Emits:
//      * - `RequestCreated` when a loan request is successfully created.
//      * - `RequestServiced` when the loan request is successfully serviced.
//      */
//     function requestLoanFromListing(uint96 _listingId, uint256 _amount) public {
//         Validator._moreThanZero(_amount);

//         LoanListing storage _listing = _appStorage.loanListings[_listingId];

//         // Validate that the address is whitelisted if the listing has a whitelist
//         Validator._addressIsWhitelisted(_listing);

//         // Check if the listing is open and the borrower is not the listing creator
//         if (_listing.listingStatus != ListingStatus.OPEN) {
//             revert Protocol__ListingNotOpen();
//         }
//         if (_listing.author == msg.sender) {
//             revert Protocol__OwnerCreatedListing();
//         }

//         // Validate that the requested amount is within the listing's constraints
//         if ((_amount < _listing.min_amount) || (_amount > _listing.max_amount)) {
//             revert Protocol__InvalidAmount();
//         }
//         if (_amount > _listing.amount) revert Protocol__InvalidAmount();

//         // Fetch token decimal and calculate USD value of the loan amount
//         uint8 _decimalToken = LibGettersImpl._getTokenDecimal(_listing.tokenAddress);
//         uint256 _loanUsdValue = LibGettersImpl._getUsdValue(_appStorage, _listing.tokenAddress, _amount, _decimalToken);

//         // Ensure borrower meets the health factor threshold for collateralization
//         if (LibGettersImpl._healthFactor(_appStorage, msg.sender, _loanUsdValue) < 1) {
//             revert Protocol__InsufficientCollateral();
//         }

//         // Calculate max loanable amount based on collateral value
//         uint256 collateralValueInLoanCurrency = LibGettersImpl._getAccountCollateralValue(_appStorage, msg.sender);
//         uint256 maxLoanableAmount = Utils.maxLoanableAmount(collateralValueInLoanCurrency);

//         // Update the listing's available amount, adjusting min/max amounts as necessary
//         _listing.amount = _listing.amount - _amount;
//         if (_listing.amount <= _listing.max_amount) {
//             _listing.max_amount = _listing.amount;
//         }
//         if (_listing.amount <= _listing.min_amount) _listing.min_amount = 0;
//         if (_listing.amount == 0) _listing.listingStatus = ListingStatus.CLOSED;

//         // Retrieve the borrower's collateral tokens for collateralization
//         address[] memory _collateralTokens = LibGettersImpl._getUserCollateralTokens(_appStorage, msg.sender);

//         // Create a new loan request with a unique ID
//         _appStorage.requestId = _appStorage.requestId + 1;
//         Request storage _newRequest = _appStorage.request[_appStorage.requestId];
//         _newRequest.requestId = _appStorage.requestId;
//         _newRequest.author = msg.sender;
//         _newRequest.lender = _listing.author;
//         _newRequest.amount = _amount;
//         _newRequest.interest = _listing.interest;
//         _newRequest.returnDate = _listing.returnDate;
//         _newRequest.totalRepayment = Utils.calculateLoanInterest(_listing.returnDate, _amount, _listing.interest);
//         _newRequest.loanRequestAddr = _listing.tokenAddress;
//         _newRequest.collateralTokens = _collateralTokens;
//         _newRequest.status = Status.SERVICED;

//         // Calculate collateral to lock for each token, proportional to its USD value
//         uint256 collateralToLock = Utils.calculateColateralToLock(_loanUsdValue, maxLoanableAmount);
//         for (uint256 i = 0; i < _collateralTokens.length; i++) {
//             address token = _collateralTokens[i];
//             uint8 decimal = LibGettersImpl._getTokenDecimal(token);
//             uint256 userBalance = _appStorage.s_addressToCollateralDeposited[msg.sender][token];

//             uint256 amountToLockUSD =
//                 (LibGettersImpl._getUsdValue(_appStorage, token, userBalance, decimal) * collateralToLock) / 100;

//             uint256 amountToLock = (
//                 (((amountToLockUSD) * 10) / LibGettersImpl._getUsdValue(_appStorage, token, 10, 0))
//                     * (10 ** _decimalToken)
//             ) / (Constants.PRECISION);

//             _appStorage.s_idToCollateralTokenAmount[_appStorage.requestId][token] = amountToLock;
//             _appStorage.s_addressToAvailableBalance[msg.sender][token] -= amountToLock;
//         }

//         // Update borrower's total loan collected in USD
//         _appStorage.addressToUser[msg.sender].totalLoanCollected +=
//             LibGettersImpl._getUsdValue(_appStorage, _listing.tokenAddress, _newRequest.totalRepayment, _decimalToken);

//         // Transfer the loan amount to the borrower
//         if (_listing.tokenAddress == Constants.NATIVE_TOKEN) {
//             (bool sent,) = payable(msg.sender).call{value: _amount}("");
//             if (!sent) revert Protocol__TransferFailed();
//         } else {
//             IERC20(_listing.tokenAddress).safeTransfer(msg.sender, _amount);
//         }

//         // Emit events to notify the loan request creation and servicing
//         emit RequestCreated(msg.sender, _appStorage.requestId, _amount, _listing.interest);
//         emit RequestServiced(_newRequest.requestId, _newRequest.lender, _newRequest.author, _amount);
//     }

//     /**
//      * @dev Allows a borrower to repay a loan in part or in full.
//      * @param _requestId The unique identifier of the loan request.
//      * @param _amount The repayment amount.
//      *
//      * Requirements:
//      * - `_amount` must be greater than zero.
//      * - The loan request must be in the SERVICED status.
//      * - The caller must be the borrower who created the loan request.
//      * - If repaying in a token, the borrower must have sufficient balance and allowance.
//      *
//      * Emits:
//      * - `LoanRepayment` upon successful repayment.
//      */
//     function repayLoan(uint96 _requestId, uint256 _amount) external payable {
//         Validator._moreThanZero(_amount);

//         Request storage _request = _appStorage.request[_requestId];

//         // Ensure that the loan request is currently serviced and the caller is the original borrower
//         if (_request.status != Status.SERVICED) {
//             revert Protocol__RequestNotServiced();
//         }
//         if (msg.sender != _request.author) revert Protocol__NotOwner();

//         // Process repayment amount based on the token type
//         if (_request.loanRequestAddr == Constants.NATIVE_TOKEN) {
//             _amount = msg.value;
//         } else {
//             IERC20 _token = IERC20(_request.loanRequestAddr);
//             if (_token.balanceOf(msg.sender) < _amount) {
//                 revert Protocol__InsufficientBalance();
//             }
//             if (_token.allowance(msg.sender, address(this)) < _amount) {
//                 revert Protocol__InsufficientAllowance();
//             }

//             _token.safeTransferFrom(msg.sender, address(this), _amount);
//         }

//         // If full repayment is made, close the request and release the collateral
//         if (_amount >= _request.totalRepayment) {
//             _amount = _request.totalRepayment;
//             _request.totalRepayment = 0;
//             _request.status = Status.CLOSED;

//             for (uint256 i = 0; i < _request.collateralTokens.length; i++) {
//                 address collateralToken = _request.collateralTokens[i];
//                 _appStorage.s_addressToAvailableBalance[_request.author][collateralToken] +=
//                     _appStorage.s_idToCollateralTokenAmount[_requestId][collateralToken];
//             }
//         } else {
//             // Reduce the outstanding repayment amount for partial payments
//             _request.totalRepayment -= _amount;
//         }

//         (, uint256 _amountAfterFees) = _settleFees(_request.loanRequestAddr, _amount);

//         // Update borrower’s loan collected metrics in USD
//         uint8 decimal = LibGettersImpl._getTokenDecimal(_request.loanRequestAddr);
//         uint256 _loanUsdValue =
//             LibGettersImpl._getUsdValue(_appStorage, _request.loanRequestAddr, _amountAfterFees, decimal);
//         uint256 loanCollected = LibGettersImpl._getLoanCollectedInUsd(_appStorage, msg.sender);

//         // Deposit the repayment amount to the lender's available balance
//         _appStorage.s_addressToCollateralDeposited[_request.lender][_request.loanRequestAddr] += _amountAfterFees;
//         _appStorage.s_addressToAvailableBalance[_request.lender][_request.loanRequestAddr] += _amountAfterFees;

//         // Adjust the borrower's total loan collected
//         if (loanCollected > _loanUsdValue) {
//             _appStorage.addressToUser[msg.sender].totalLoanCollected = loanCollected - _loanUsdValue;
//         } else {
//             _appStorage.addressToUser[msg.sender].totalLoanCollected = 0;
//         }

//         // Emit event to notify of loan repayment
//         emit LoanRepayment(msg.sender, _requestId, _amount);
//     }

//     /**
//      * @notice Liquidates an undercollateralized P2P loan and transfers assets
//      * @dev This function performs the following actions:
//      *      1. Verifies the loan is active and eligible for liquidation
//      *      2. Calculates health factor based on collateral value vs loan value
//      *      3. Repays the loan amount to the lender on behalf of the borrower
//      *      4. Transfers collateral to the liquidator with a discount
//      *      5. Sends liquidation fee to the protocol
//      * @param requestId The unique identifier of the loan request to liquidate
//      */
//     function liquidateUserRequest(uint96 requestId) external payable {
//         // Get the loan request from storage
//         Request storage request = _appStorage.request[requestId];

//         // Verify loan is in active state
//         if (request.status != Status.SERVICED) {
//             revert Protocol__RequestNotServiced();
//         }

//         if (request.author == msg.sender) {
//             revert Protocol__OwnerCantLiquidateRequest();
//         }

//         // Store key loan details for easier reference and gas optimization
//         address borrower = request.author;
//         address lender = request.lender;
//         address loanToken = request.loanRequestAddr;
//         uint256 totalDebt = request.totalRepayment;

//         // Calculate loan value in USD
//         uint8 loanTokenDecimal = LibGettersImpl._getTokenDecimal(loanToken);
//         uint256 loanUsdValue = LibGettersImpl._getUsdValue(_appStorage, loanToken, totalDebt, loanTokenDecimal);

//         // Calculate total value of collateral in USD
//         uint256 totalCollateralValue = 0;
//         for (uint256 i = 0; i < request.collateralTokens.length; i++) {
//             address collateralToken = request.collateralTokens[i];
//             uint256 collateralAmount = _appStorage.s_idToCollateralTokenAmount[requestId][collateralToken];

//             if (collateralAmount > 0) {
//                 uint8 collateralDecimal = LibGettersImpl._getTokenDecimal(collateralToken);
//                 totalCollateralValue +=
//                     LibGettersImpl._getUsdValue(_appStorage, collateralToken, collateralAmount, collateralDecimal);
//             }
//         }

//         // Check if loan is past due date (liquidation only allowed for overdue loans)
//         bool isPastDue = block.timestamp > request.returnDate;
//         // Verify loan is undercollateralized (health factor check)
//         // Health factor broken when loan value exceeds collateral value
//         bool isUnhealthy = loanUsdValue > totalCollateralValue;
//         if (!isPastDue || !isUnhealthy) revert Protocol__NotLiquidatable();

//         // Update request status to prevent re-entrancy and multiple liquidations
//         request.status = Status.LIQUIDATED;

//         // Handle debt repayment from liquidator to lender
//         if (loanToken == Constants.NATIVE_TOKEN) {
//             // For native token (ETH), ensure sufficient ETH was sent
//             if (msg.value < totalDebt) revert Protocol__InsufficientETH();

//             // Refund excess ETH to liquidator
//             uint256 excess = msg.value - totalDebt;
//             if (excess > 0) {
//                 (bool refundSent,) = payable(msg.sender).call{value: excess}("");
//                 if (!refundSent) revert Protocol__RefundFailed();
//             }

//             // Transfer the debt amount to the lender
//             (bool lenderSent,) = payable(lender).call{value: totalDebt}("");
//             if (!lenderSent) revert Protocol__ETHTransferFailed();
//         } else {
//             // For ERC20 tokens, transfer from liquidator to lender
//             IERC20(loanToken).safeTransferFrom(msg.sender, lender, totalDebt);
//         }

//         // Process each collateral token and transfer to liquidator with discount
//         for (uint256 i = 0; i < request.collateralTokens.length; i++) {
//             address collateralToken = request.collateralTokens[i];
//             uint256 collateralAmount = _appStorage.s_idToCollateralTokenAmount[requestId][collateralToken];

//             if (collateralAmount > 0) {
//                 // Calculate discounted amount (apply liquidation discount)
//                 uint256 discountedAmount = (collateralAmount * (10000 - Constants.LIQUIDATION_DISCOUNT)) / 10000;

//                 // Transfer discounted amount to liquidator
//                 if (collateralToken == Constants.NATIVE_TOKEN) {
//                     (bool sent,) = payable(msg.sender).call{value: discountedAmount}("");
//                     if (!sent) revert Protocol__ETHTransferFailed();
//                 } else {
//                     IERC20(collateralToken).safeTransfer(msg.sender, discountedAmount);
//                 }

//                 // The difference between original collateral and discounted amount goes to protocol as fee
//                 uint256 protocolAmount = collateralAmount - discountedAmount;
//                 if (protocolAmount > 0 && _appStorage.s_protocolFeeRecipient != address(0)) {
//                     if (collateralToken == Constants.NATIVE_TOKEN) {
//                         (bool sent,) = payable(_appStorage.s_protocolFeeRecipient).call{value: protocolAmount}("");
//                         if (!sent) revert Protocol__ETHFeeTransferFailed();
//                     } else {
//                         IERC20(collateralToken).safeTransfer(_appStorage.s_protocolFeeRecipient, protocolAmount);
//                     }
//                 }

//                 // Reset collateral tracking to prevent double-spending
//                 _appStorage.s_idToCollateralTokenAmount[requestId][collateralToken] = 0;
//             }
//         }

//         // Update liquidator's activity metrics for potential rewards
//         User storage liquidator = _appStorage.addressToUser[msg.sender];
//         liquidator.totalLiquidationAmount += totalCollateralValue;

//         // Emit event for off-chain tracking and transparency
//         emit RequestLiquidated(requestId, msg.sender, borrower, lender, totalCollateralValue);
//     }

//     function _settleFees(address _token, uint256 _amount) internal returns (uint256, uint256) {
//         uint16 _feeRate = _appStorage.feeRateBps;

//         uint256 _fee = Utils.calculatePercentage(_amount, _feeRate);

//         _appStorage.s_feesAccrued[_token] = _appStorage.s_feesAccrued[_token] + _fee;

//         return (_amount, (_amount - _fee));
//     }
// }
