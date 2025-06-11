// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {LibGettersImpl} from "../LibGetters.sol";
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

        _foundRequest.lender = _user;
        _foundRequest.status = Status.SERVICED;
        uint256 amountToLend = _foundRequest.amount;

        // Get token's decimal value and calculate the loan's USD equivalent
        uint8 _decimalToken = LibGettersImpl._getTokenDecimal(_tokenAddress);
        uint256 _loanUsdValue = LibGettersImpl._getUsdValue(
            _appStorage,
            _tokenAddress,
            amountToLend,
            _decimalToken
        );

        // Calculate the total repayment amount including interest
        uint256 _totalRepayment = Utils.calculateLoanInterest(
            _foundRequest.returnDate,
            _foundRequest.amount,
            _foundRequest.interest
        );
        _foundRequest.totalRepayment = _totalRepayment;

        // Update total loan collected in USD for the borrower
        _appStorage
            .addressToUser[_foundRequest.author]
            .totalLoanCollected += LibGettersImpl._getUsdValue(
            _appStorage,
            _tokenAddress,
            _totalRepayment,
            _decimalToken
        );

        // Validate borrower's collateral health factor after loan
        if (
            LibGettersImpl._healthFactor(
                _appStorage,
                _foundRequest.author,
                _loanUsdValue
            ) < 1
        ) {
            revert Protocol__InsufficientCollateral();
        }

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
            IERC20(_tokenAddress).approve(
                address(Constants.CCIP_ROUTER),
                amountToLend
            );

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
}
