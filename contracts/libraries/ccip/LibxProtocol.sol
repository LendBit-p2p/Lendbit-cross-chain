// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IWERC20} from "@chainlink/contracts/src/v0.8/shared/interfaces/IWERC20.sol";
import {Client} from "@chainlink/contract-ccip/contracts/libraries/Client.sol";
import {LibCCIP} from "./LibCCIP.sol";

import {LibGettersImpl} from "../LibGetters.sol";
import {LibAppStorage} from "../LibAppStorage.sol";
import {Utils} from "../../utils/functions/Utils.sol";
import "../../model/Protocol.sol";
import "../../model/Event.sol";
import "../../utils/validators/Error.sol";
import "../../utils/validators/Validator.sol";
import "../../utils/constants/Constant.sol";

import {LibProtocol} from "../LibProtocol.sol";

library LibxProtocol {
    using SafeERC20 for IERC20;

    function _serviceLendingRequest(
        LibAppStorage.Layout storage _appStorage,
        uint96 _requestId,
        address _tokenAddress,
        uint256 _amount,
        bool _isNative,
        address _user
    ) internal {
        //TODO: Check where the money goes when a revert happens
        // Load the request from storage
        Request storage _foundRequest = _appStorage.request[_requestId];

        // Ensure the request status is open and has not expired
        if (_foundRequest.status != Status.OPEN) {
            revert Protocol__RequestNotOpen();
        }
        if (_foundRequest.loanRequestAddr != _tokenAddress && _foundRequest.loanRequestAddr != Constants.NATIVE_TOKEN) {
            revert Protocol__InvalidToken();
        }
        if (_foundRequest.author == _user) {
            revert Protocol__CantFundSelf();
        }
        if (_foundRequest.returnDate <= block.timestamp) {
            revert Protocol__RequestExpired();
        }

        _foundRequest.lender = _user;
        _foundRequest.status = Status.SERVICED;
        uint256 amountToLend = _foundRequest.amount;

        // Get token's decimal value and calculate the loan's USD equivalent
        uint8 _decimalToken = LibGettersImpl._getTokenDecimal(_tokenAddress);
        uint256 _loanUsdValue = LibGettersImpl._getUsdValue(_appStorage, _tokenAddress, amountToLend, _decimalToken);

        // Calculate the total repayment amount including interest
        uint256 _totalRepayment =
            Utils.calculateLoanInterest(_foundRequest.returnDate, _foundRequest.amount, _foundRequest.interest);
        _foundRequest.totalRepayment = _totalRepayment;

        // Update total loan collected in USD for the borrower
        _appStorage.addressToUser[_foundRequest.author].totalLoanCollected +=
            LibGettersImpl._getUsdValue(_appStorage, _tokenAddress, _totalRepayment, _decimalToken);

        // Validate borrower's collateral health factor after loan
        if (LibGettersImpl._healthFactor(_appStorage, _foundRequest.author, _loanUsdValue) < 1) {
            revert Protocol__InsufficientCollateral();
        }

        if (_amount < amountToLend) {
            revert Protocol__InsufficientAmount();
        }

        if (_foundRequest.sourceChain == Constants.CHAIN_SELECTOR) {
            if (_isNative) {
                IWERC20(_tokenAddress).withdraw(_amount);
                (bool success,) = address(_foundRequest.author).call{value: _amount}("");
                if (!success) {
                    revert Protocol__TransferFailed();
                }
            } else {
                IERC20(_tokenAddress).safeTransfer(address(_foundRequest.author), _amount);
            }
        } else {
            IERC20(_tokenAddress).approve(address(Constants.CCIP_ROUTER), amountToLend);

            Client.EVMTokenAmount[] memory _destTokenAmounts = new Client.EVMTokenAmount[](1);
            _destTokenAmounts[0] = Client.EVMTokenAmount({token: _tokenAddress, amount: _amount});

            LibCCIP._sendTokenCrosschain(
                _appStorage.s_senderSupported[_foundRequest.sourceChain],
                _isNative,
                _destTokenAmounts,
                _foundRequest.sourceChain,
                address(_foundRequest.author)
            );
        }
    }

    function _createLoanListing(
        LibAppStorage.Layout storage _appStorage,
        address _author,
        address _loanCurrency,
        uint256 _amount,
        uint256 _min_amount,
        uint256 _max_amount,
        uint16 _interest,
        uint256 _returnDate,
        address[] memory _whitelist,
        uint64 _chainSelector // payable
    ) internal {
        // Validate that the amount is greater than zero and that a value has been sent if using native token
        Validator._valueMoreThanZero(_amount, _loanCurrency, _amount);
        Validator._moreThanZero(_amount);

        // Ensure the specified loan currency is a loanable token
        if (!_appStorage.s_isLoanable[_loanCurrency]) {
            revert Protocol__TokenNotLoanable();
        }

        // Increment the listing ID to create a new loan listing
        _appStorage.listingId = _appStorage.listingId + 1;
        LoanListing storage _newListing = _appStorage.loanListings[_appStorage.listingId];

        // Populate the loan listing struct with the provided details
        _newListing.listingId = _appStorage.listingId;
        _newListing.author = _author;
        _newListing.amount = _amount;
        _newListing.min_amount = _min_amount;
        _newListing.max_amount = _max_amount;
        _newListing.interest = _interest;
        _newListing.returnDate = _returnDate;
        _newListing.tokenAddress = _loanCurrency;
        _newListing.listingStatus = ListingStatus.OPEN;
        _newListing.whitelist = _whitelist;

        // Emit an event to notify that a new loan listing has been created
        emit LoanListingCreated(_appStorage.listingId, _author, _loanCurrency, _amount, _chainSelector);
    }

    function _requestLoanFromListing(
        LibAppStorage.Layout storage _appStorage,
        address _borrower,
        uint96 _listingId,
        uint256 _amount,
        uint64 _chainSelector
    ) internal {
        Validator._moreThanZero(_amount);

        LoanListing storage _listing = _appStorage.loanListings[_listingId];

        // Validate that the address is whitelisted if the listing has a whitelist
        Validator._addressIsWhitelisted(_listing, _borrower);

        // Check if the listing is open and the borrower is not the listing creator
        if (_listing.listingStatus != ListingStatus.OPEN) {
            revert Protocol__ListingNotOpen();
        }
        if (_listing.author == _borrower) {
            revert Protocol__OwnerCreatedListing();
        }

        // Validate that the requested amount is within the listing's constraints
        if ((_amount < _listing.min_amount) || (_amount > _listing.max_amount)) {
            revert Protocol__InvalidAmount();
        }
        if (_amount > _listing.amount) revert Protocol__InvalidAmount();

        // Fetch token decimal and calculate USD value of the loan amount
        uint8 _decimalToken = LibGettersImpl._getTokenDecimal(_listing.tokenAddress);
        uint256 _loanUsdValue = LibGettersImpl._getUsdValue(_appStorage, _listing.tokenAddress, _amount, _decimalToken);

        // Ensure borrower meets the health factor threshold for collateralization
        if (LibGettersImpl._healthFactor(_appStorage, _borrower, _loanUsdValue) < 1) {
            revert Protocol__InsufficientCollateral();
        }

        // Calculate max loanable amount based on collateral value
        uint256 collateralValueInLoanCurrency = LibGettersImpl._getAccountCollateralValue(_appStorage, _borrower);
        uint256 maxLoanableAmount = Utils.maxLoanableAmount(collateralValueInLoanCurrency);

        // Update the listing's available amount, adjusting min/max amounts as necessary
        _listing.amount = _listing.amount - _amount;
        if (_listing.amount <= _listing.max_amount) {
            _listing.max_amount = _listing.amount;
        }
        if (_listing.amount <= _listing.min_amount) _listing.min_amount = 0;
        if (_listing.amount == 0) _listing.listingStatus = ListingStatus.CLOSED;

        // Retrieve the borrower's collateral tokens for collateralization
        address[] memory _collateralTokens = LibGettersImpl._getUserCollateralTokens(_appStorage, _borrower);

        // Create a new loan request with a unique ID
        _appStorage.requestId = _appStorage.requestId + 1;
        Request storage _newRequest = _appStorage.request[_appStorage.requestId];
        _newRequest.requestId = _appStorage.requestId;
        _newRequest.author = _borrower;
        _newRequest.lender = _listing.author;
        _newRequest.amount = _amount;
        _newRequest.interest = _listing.interest;
        _newRequest.returnDate = _listing.returnDate;
        _newRequest.totalRepayment = Utils.calculateLoanInterest(_listing.returnDate, _amount, _listing.interest);
        _newRequest.loanRequestAddr = _listing.tokenAddress;
        _newRequest.collateralTokens = _collateralTokens;
        _newRequest.status = Status.SERVICED;
        _newRequest.sourceChain = _chainSelector;

        // Calculate collateral to lock for each token, proportional to its USD value
        uint256 collateralToLock = Utils.calculateColateralToLock(_loanUsdValue, maxLoanableAmount);
        for (uint256 i = 0; i < _collateralTokens.length; i++) {
            address token = _collateralTokens[i];
            uint8 decimal = LibGettersImpl._getTokenDecimal(token);
            uint256 userBalance = _appStorage.s_addressToCollateralDeposited[_borrower][token];

            uint256 amountToLockUSD =
                (LibGettersImpl._getUsdValue(_appStorage, token, userBalance, decimal) * collateralToLock) / 100;

            uint256 amountToLock = (
                (((amountToLockUSD) * 10) / LibGettersImpl._getUsdValue(_appStorage, token, 10, 0))
                    * (10 ** _decimalToken)
            ) / (Constants.PRECISION);

            _appStorage.s_idToCollateralTokenAmount[_appStorage.requestId][token] = amountToLock;
            _appStorage.s_addressToAvailableBalance[_borrower][token] -= amountToLock;
        }

        // Update borrower's total loan collected in USD
        _appStorage.addressToUser[_borrower].totalLoanCollected +=
            LibGettersImpl._getUsdValue(_appStorage, _listing.tokenAddress, _newRequest.totalRepayment, _decimalToken);

        Client.EVMTokenAmount[] memory tokensToSendDetails = new Client.EVMTokenAmount[](1);
        tokensToSendDetails[0] = Client.EVMTokenAmount({
            token: _listing.tokenAddress == Constants.NATIVE_TOKEN ? Constants.WETH : _listing.tokenAddress,
            amount: _amount
        });

        // Handle movement for native token vs ERC20 tokens
        if (_listing.tokenAddress == Constants.NATIVE_TOKEN) {
            // Transfer native token to the user
            IWERC20(Constants.WETH).deposit{value: _amount}();
            IERC20(Constants.WETH).approve(Constants.CCIP_ROUTER, _amount);
        } else {
            IERC20(_listing.tokenAddress).approve(Constants.CCIP_ROUTER, _amount);
        }

        //Handle Sending Of Token Crosschain.
        bytes32 messageId = LibCCIP._sendTokenCrosschain(
            _appStorage.s_senderSupported[_chainSelector],
            _listing.tokenAddress == Constants.NATIVE_TOKEN,
            tokensToSendDetails,
            _chainSelector,
            _borrower
        );

        emit CCIPMessageSent(messageId, _chainSelector, abi.encode(_borrower), tokensToSendDetails);

        // Emit events to notify the loan request creation and servicing
        emit RequestCreated(_borrower, _appStorage.requestId, _amount, _listing.interest, _chainSelector);
        emit RequestServiced(_newRequest.requestId, _newRequest.lender, _newRequest.author, _amount, _chainSelector);
    }

    function _repayLoan(
        LibAppStorage.Layout storage _appStorage,
        address _user,
        uint96 _requestId,
        uint256 _amount,
        uint64 _chainSelector // payable
    ) internal {
        Validator._moreThanZero(_amount);

        Request storage _request = _appStorage.request[_requestId];

        // Ensure that the loan request is currently serviced and the caller is the original borrower
        if (_request.status != Status.SERVICED) {
            revert Protocol__RequestNotServiced();
        }
        if (_user != _request.author) revert Protocol__NotOwner();

        // If full repayment is made, close the request and release the collateral
        if (_amount >= _request.totalRepayment) {
            _amount = _request.totalRepayment;
            _request.totalRepayment = 0;
            _request.status = Status.CLOSED;

            for (uint256 i = 0; i < _request.collateralTokens.length; i++) {
                address collateralToken = _request.collateralTokens[i];
                _appStorage.s_addressToAvailableBalance[_request.author][collateralToken] +=
                    _appStorage.s_idToCollateralTokenAmount[_requestId][collateralToken];

                delete _appStorage.s_idToCollateralTokenAmount[_requestId][collateralToken];
            }
        } else {
            // Reduce the outstanding repayment amount for partial payments
            _request.totalRepayment -= _amount;
        }

        (, uint256 _amountAfterFees) = LibProtocol._settleFees(_appStorage, _request.loanRequestAddr, _amount);

        // Update borrower’s loan collected metrics in USD
        uint8 decimal = LibGettersImpl._getTokenDecimal(_request.loanRequestAddr);
        uint256 _loanUsdValue =
            LibGettersImpl._getUsdValue(_appStorage, _request.loanRequestAddr, _amountAfterFees, decimal);
        uint256 loanCollected = LibGettersImpl._getLoanCollectedInUsd(_appStorage, _user);

        // Deposit the repayment amount to the lender's available balance
        _appStorage.s_addressToCollateralDeposited[_request.lender][_request.loanRequestAddr] += _amountAfterFees;
        _appStorage.s_addressToAvailableBalance[_request.lender][_request.loanRequestAddr] += _amountAfterFees;

        // Adjust the borrower's total loan collected
        if (loanCollected > _loanUsdValue) {
            _appStorage.addressToUser[_user].totalLoanCollected = loanCollected - _loanUsdValue;
        } else {
            _appStorage.addressToUser[_user].totalLoanCollected = 0;
        }

        // Emit event to notify of loan repayment
        emit LoanRepayment(_user, _requestId, _amount, _chainSelector);
    }

    function _closeRequest(LibAppStorage.Layout storage _appStorage, address _user, uint96 _requestId) internal {
        // Retrieve the lending request associated with the given request ID
        Request storage _foundRequest = _appStorage.request[_requestId];

        // Check if the request is OPEN; revert if it's not
        if (_foundRequest.status != Status.OPEN) {
            revert Protocol__RequestNotOpen();
        }

        // Ensure that the caller is the author of the request; revert if not
        if (_foundRequest.author != _user) revert Protocol__NotOwner();

        // Update the request status to CLOSED
        _foundRequest.status = Status.CLOSED;

        // Emit an event to notify that the request has been closed
        emit RequestClosed(_requestId, _user, _foundRequest.sourceChain);
    }

    function _closeListingAd(LibAppStorage.Layout storage _appStorage, address _user, uint96 _listingId) internal {
        // Retrieve the loan listing associated with the given listing ID
        LoanListing storage _listing = _appStorage.loanListings[_listingId];

        // Check if the listing is OPEN; revert if it's not
        if (_listing.listingStatus != ListingStatus.OPEN) {
            revert Protocol__OrderNotOpen();
        }

        // Ensure that the caller is the author of the listing; revert if not
        if (_listing.author != _user) {
            revert Protocol__OwnerCreatedOrder();
        }

        // Ensure the amount is greater than zero; revert if it is zero
        if (_listing.amount == 0) revert Protocol__MustBeMoreThanZero();

        // Store the amount to be transferred and reset the listing amount to zero
        uint256 _amount = _listing.amount;
        _listing.amount = 0; // Prevent re-entrancy by setting amount to zero
        _listing.listingStatus = ListingStatus.CLOSED; // Update listing status to CLOSED

        _appStorage.s_addressToAvailableBalance[_listing.author][_listing.tokenAddress] += _amount;
        _appStorage.s_addressToCollateralDeposited[_listing.author][_listing.tokenAddress] += _amount;

        emit LoanListingClosed(_listing.listingId, _listing.author, _listing.tokenAddress, _amount);
    }
}
