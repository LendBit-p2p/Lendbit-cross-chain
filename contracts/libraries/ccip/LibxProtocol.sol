// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {LibGettersImpl} from "../LibGetters.sol";
import {LibAppStorage} from "../LibAppStorage.sol";
import {Utils} from "../../utils/functions/Utils.sol";
import "../../model/Protocol.sol";
import "../../model/Event.sol";
import "../../utils/validators/Error.sol";
import "../../utils/validators/Validator.sol";
import "../../utils/constants/Constant.sol";
import "../LibAppStorage.sol";
import {IWERC20} from "@chainlink/contracts/src/v0.8/shared/interfaces/IWERC20.sol";
import {LibCCIP} from "./LibCCIP.sol";

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
        if (
            _foundRequest.loanRequestAddr != _tokenAddress &&
            _foundRequest.loanRequestAddr != Constants.NATIVE_TOKEN
        ) {
            revert Protocol__InvalidToken();
        }
        if (_foundRequest.author == _user) {
            revert Protocol__CantFundSelf();
        }
        if (_foundRequest.returnDate <= block.timestamp) {
            revert Protocol__RequestExpired();
        }

        _foundRequest.lender = msg.sender;
        _foundRequest.status = Status.SERVICED;
        uint256 amountToLend = _foundRequest.amount;

        if (_amount < amountToLend) {
            revert Protocol__InsufficientAmount();
        }

        if (_foundRequest.sourceChain == Constants.CHAIN_SELECTOR) {
            if (_isNative) {
                IWERC20(_tokenAddress).withdraw(_amount);
                (bool success, ) = address(_foundRequest.author).call{
                    value: _amount
                }("");
                if (!success) {
                    revert Protocol__TransferFailed();
                }
            } else {
                IERC20(_tokenAddress).safeTransfer(
                    address(_foundRequest.author),
                    _amount
                );
            }
        } else {
            Client.EVMTokenAmount[]
                memory _destTokenAmounts = new Client.EVMTokenAmount[](1);
            _destTokenAmounts[0] = Client.EVMTokenAmount({
                token: _tokenAddress,
                amount: _amount
            });
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
        // if (!_appStorage.s_isLoanable[_loanCurrency]) {
        //     revert Protocol__TokenNotLoanable();
        // }

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
}
