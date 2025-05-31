// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {LibAppStorage} from "./LibAppStorage.sol";
import {Constants} from "../utils/constants/Constant.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../model/Protocol.sol";
import "../utils/validators/Error.sol";

library LibGettersImpl {
    /**
     * @dev Converts a specified token amount to its USD-equivalent value based on
     *      the latest price from the token's price feed.
     *
     * @param _appStorage The application storage layout containing the price feed data.
     * @param _token The address of the token to be converted.
     * @param _amount The amount of the token to convert to USD.
     * @param _decimal The decimal precision of the token.
     *
     * @return The USD-equivalent value of the specified token amount, adjusted to a standard precision.
     *
     * The function retrieves the latest price for `_token` from its price feed, scales it
     * to a common precision using `Constants.NEW_PRECISION`, and returns the USD-equivalent
     * value by factoring in the token's decimal precision.
     */
    function _getUsdValue(LibAppStorage.Layout storage _appStorage, address _token, uint256 _amount, uint8 _decimal)
        internal
        view
        returns (uint256)
    {
        AggregatorV3Interface _priceFeed = AggregatorV3Interface(_appStorage.s_priceFeeds[_token]);
        (, int256 _price,,,) = _priceFeed.latestRoundData();
        return ((uint256(_price) * Constants.NEW_PRECISION) * (_amount)) / ((10 ** _decimal));
    }

    /**
     * @dev Converts an amount of one token (`_from`) to its equivalent amount in another token (`_to`),
     *      based on their USD values and decimal precision.
     *
     * @param _appStorage The application storage layout containing price feed and token data.
     * @param _from The address of the token being converted from.
     * @param _to The address of the token being converted to.
     * @param _amount The amount of the `_from` token to convert.
     *
     * @return value The equivalent amount of the `_to` token.
     *
     * The function first retrieves the decimal precision of both tokens, then calculates
     * the USD value of `_amount` in `_from` tokens. It converts this USD value to the
     * equivalent `_to` token amount, adjusting for decimal precision, and returns the result.
     */
    function _getConvertValue(LibAppStorage.Layout storage _appStorage, address _from, address _to, uint256 _amount)
        internal
        view
        returns (uint256 value)
    {
        uint8 fromDecimal = _getTokenDecimal(_from);
        uint8 toDecimal = _getTokenDecimal(_to);
        uint256 fromUsd = _getUsdValue(_appStorage, _from, _amount, fromDecimal);
        value = (((fromUsd * 10) / _getUsdValue(_appStorage, _to, 10, 0)) * (10 ** toDecimal));
    }

    /**
     * @dev This uses Chainlink pricefeed and ERC20 Standard in getting the Token/USD price and Token decimals.
     *
     * @param _appStorage The storage Layout of the contract.
     * @param _user The address of the user you want to get their collateral value.
     *
     * @return _totalCollateralValueInUsd returns the value of the user deposited collateral in USD.
     */
    function _getAccountCollateralValue(LibAppStorage.Layout storage _appStorage, address _user)
        internal
        view
        returns (uint256 _totalCollateralValueInUsd)
    {
        for (uint256 index = 0; index < _appStorage.s_collateralToken.length; index++) {
            address _token = _appStorage.s_collateralToken[index];
            uint256 _amount = _appStorage.s_addressToCollateralDeposited[_user][_token];
            uint8 _tokenDecimal = _getTokenDecimal(_token);
            _totalCollateralValueInUsd += _getUsdValue(_appStorage, _token, _amount, _tokenDecimal);
        }
    }

    /**
     * @dev This uses Chainlink pricefeed and ERC20 Standard in getting the Token/USD price and Token decimals.
     *
     * @param _appStorage The storage Layout of the contract.
     * @param _user the address of the user you want to get their available balance value
     *
     * @return _totalAvailableValueInUsd returns the value of the user available balance in USD
     */
    function _getAccountAvailableValue(LibAppStorage.Layout storage _appStorage, address _user)
        internal
        view
        returns (uint256 _totalAvailableValueInUsd)
    {
        for (uint256 index = 0; index < _appStorage.s_collateralToken.length; index++) {
            address _token = _appStorage.s_collateralToken[index];
            uint256 _amount = _appStorage.s_addressToAvailableBalance[_user][_token];
            uint8 _tokenDecimal = _getTokenDecimal(_token);
            _totalAvailableValueInUsd += _getUsdValue(_appStorage, _token, _amount, _tokenDecimal);
        }
    }

    /**
     * @dev Returns the listing if it exists, otherwise reverts if the listing's author is the zero address
     *
     * @param _appStorage The storage Layout of the contract.
     * @param _listingId The ID of the listing to retrieve
     *
     * @return The `LoanListing` struct containing details of the specified listing
     */
    function _getLoanListing(LibAppStorage.Layout storage _appStorage, uint96 _listingId)
        internal
        view
        returns (LoanListing memory)
    {
        LoanListing memory _listing = _appStorage.loanListings[_listingId];
        if (_listing.author == address(0)) revert Protocol__IdNotExist();
        return _listing;
    }

    /**
     * @dev Returns the request if it exists, otherwise reverts if the request's author is the zero address
     *
     * @param _appStorage The storage Layout of the contract.
     * @param _requestId The ID of the request to retrieve
     *
     * @return _request The `Request` struct containing details of the specified request
     */
    function _getRequest(LibAppStorage.Layout storage _appStorage, uint96 _requestId)
        internal
        view
        returns (Request memory)
    {
        Request memory _request = _appStorage.request[_requestId];
        if (_request.author == address(0)) revert Protocol__NotOwner();
        return _request;
    }

    /**
     * @dev This gets the account info of any account.
     *
     * @param _appStorage The storage Layout of the contract.
     * @param _user a parameter for the user account info you want to get.
     *
     * @return _totalBurrowInUsd returns the total amount of SC the  user has minted.
     * @return _collateralValueInUsd returns the total collateral the user has deposited in USD.
     */
    function _getAccountInfo(LibAppStorage.Layout storage _appStorage, address _user)
        internal
        view
        returns (uint256 _totalBurrowInUsd, uint256 _collateralValueInUsd)
    {
        _totalBurrowInUsd = _getLoanCollectedInUsd(_appStorage, _user);
        _collateralValueInUsd = _getAccountCollateralValue(_appStorage, _user);
    }

    /**
     * @dev Checks the health Factor which is a way to check if the user has enough collateral to mint
     *
     * @param _appStorage The storage Layout of the contract.
     * @param _user a parameter for the address to check
     * @param _borrowValue amount the user wants to borrow in usd
     *
     * @return uint256 returns the health factor which is supoose to be >= 1
     */
    function _healthFactor(LibAppStorage.Layout storage _appStorage, address _user, uint256 _borrowValue)
        internal
        view
        returns (uint256)
    {
        (uint256 _totalBurrowInUsd, uint256 _collateralValueInUsd) = _getAccountInfo(_appStorage, _user);
        uint256 _collateralAdjustedForThreshold = (_collateralValueInUsd * Constants.LIQUIDATION_THRESHOLD) / 100;

        if ((_totalBurrowInUsd == 0) && (_borrowValue == 0)) {
            return (_collateralAdjustedForThreshold * Constants.PRECISION);
        }

        return (_collateralAdjustedForThreshold * Constants.PRECISION) / (_totalBurrowInUsd + _borrowValue);
    }

    /**
     * @dev This uses the openZeppelin ERC20 standard to get the decimals of token, but if the token is the blockchain native token(ETH) it returns 18.
     *
     * @param _token The token address.
     *
     * @return _decimal The token decimal.
     */
    function _getTokenDecimal(address _token) internal view returns (uint8 _decimal) {
        if (_token == Constants.NATIVE_TOKEN) {
            _decimal = 18;
        } else {
            _decimal = ERC20(_token).decimals();
        }
    }

    /**
     * @dev Returns the request if it exists, otherwise reverts if the request's author is the zero address
     *
     * @param _appStorage The storage Layout of the contract.
     * @param _user the addresss of the user
     * @param _requestId the id of the request that was created by the user
     *
     * @return _request The request of the user
     */
    function _getUserRequest(LibAppStorage.Layout storage _appStorage, address _user, uint96 _requestId)
        internal
        view
        returns (Request memory)
    {
        Request memory _request = _appStorage.request[_requestId];
        if (_request.author != _user) revert Protocol__NotOwner();
        return _request;
    }

    /**
     * @dev Retrieves all active requests created by a specific user with `Status.SERVICED`.
     *      This function uses a single loop to count matching requests, allocates an exact-sized
     *      array for efficiency, and then populates it with the matching requests.
     *
     * @param _appStorage The storage Layout of the contract.
     * @param _user the user you want to get their active requests
     *
     * @return _requests An array of active requests
     */
    function _getUserActiveRequests(LibAppStorage.Layout storage _appStorage, address _user)
        internal
        view
        returns (Request[] memory _requests)
    {
        uint96 requestId = _appStorage.requestId;
        uint64 count;

        for (uint96 i = 1; i <= requestId; i++) {
            Request memory request = _appStorage.request[i];

            if (request.author == _user && request.status == Status.SERVICED) {
                count++;
            }
        }

        _requests = new Request[](count);
        uint64 requestLength;

        for (uint96 i = 1; i <= requestId; i++) {
            Request memory request = _appStorage.request[i];

            if (request.author == _user && request.status == Status.SERVICED) {
                _requests[requestLength] = request;
                requestLength++;
            }
        }
    }

    /**
     * @dev Retrieves all requests serviced by a specific user with `Request.lender == user`.
     *      This function uses a single loop to count matching requests, allocates an exact-sized
     *      array for efficiency, and then populates it with the matching requests.
     *
     * @param _appStorage The storage Layout of the contract.
     * @param _lender The lender that services the request.
     *
     * @return _requests An array of all request serviced by the lender
     */
    function _getServicedRequestByLender(LibAppStorage.Layout storage _appStorage, address _lender)
        internal
        view
        returns (Request[] memory _requests)
    {
        uint96 requestId = _appStorage.requestId;
        uint64 count;

        for (uint96 i = 1; i <= requestId; i++) {
            Request memory request = _appStorage.request[i];

            if (request.lender == _lender) {
                count++;
            }
        }

        _requests = new Request[](count);
        uint64 requestLength;

        for (uint96 i = 1; i <= requestId; i++) {
            Request memory request = _appStorage.request[i];

            if (request.lender == _lender) {
                _requests[requestLength] = request;
                requestLength++;
            }
        }
    }

    /**
     * @dev Calculates the total loan amount collected by a user in USD by summing up
     *      the USD-equivalent values of all active loan requests created by the user.
     *
     * @param _appStorage The application storage layout containing request and token data.
     * @param _user The address of the user whose loan collections are being calculated.
     *
     * @return _value The total value of the user's active loan requests, converted to USD.
     *
     * The function first retrieves all active requests for `_user` via `_getUserActiveRequests`.
     * It then iterates over each request, calculates its USD-equivalent value based on its
     * `loanRequestAddr` and `totalRepayment`, and accumulates the total into `_value`.
     */
    function _getLoanCollectedInUsd(LibAppStorage.Layout storage _appStorage, address _user)
        internal
        view
        returns (uint256 _value)
    {
        Request[] memory userActiveRequest = _getUserActiveRequests(_appStorage, _user);
        uint256 loans = 0;
        for (uint256 i = 0; i < userActiveRequest.length; i++) {
            uint8 tokenDecimal = _getTokenDecimal(userActiveRequest[i].loanRequestAddr);
            loans += _getUsdValue(
                _appStorage, userActiveRequest[i].loanRequestAddr, userActiveRequest[i].totalRepayment, tokenDecimal
            );
        }
        _value = loans;
    }

    /**
     * @dev Retrieves a list of collateral token addresses for a specific user.
     *      Only tokens with a positive available balance or collateral deposited
     *      by the user are included in the returned array.
     *
     * @param _appStorage The application storage layout containing collateral and balance data.
     * @param _user The address of the user whose collateral tokens are being retrieved.
     *
     * @return _collaterals An array of addresses representing the collateral tokens held by `_user`.
     *
     * The function first iterates through all collateral tokens to count the tokens
     * with a positive balance for `_user`, then initializes an array of exact size.
     * It populates this array in a second loop, storing tokens where the user has
     * a positive collateral deposit.
     */
    function _getUserCollateralTokens(LibAppStorage.Layout storage _appStorage, address _user)
        internal
        view
        returns (address[] memory _collaterals)
    {
        address[] memory tokens = _appStorage.s_collateralToken;
        uint8 userLength = 0;

        for (uint256 i = 0; i < tokens.length; i++) {
            if (_appStorage.s_addressToAvailableBalance[_user][tokens[i]] > 0) {
                userLength++;
            }
        }

        address[] memory userTokens = new address[](userLength);

        for (uint256 i = 0; i < tokens.length; i++) {
            if (_appStorage.s_addressToCollateralDeposited[_user][tokens[i]] > 0) {
                userTokens[userLength - 1] = tokens[i];
                userLength--;
            }
        }

        return userTokens;
    }

    function _getAllRequest(LibAppStorage.Layout storage _appStorage)
        internal
        view
        returns (Request[] memory _requests)
    {
        uint96 requestId = _appStorage.requestId;
        _requests = new Request[](requestId);

        for (uint96 i = 1; i <= requestId; i++) {
            _requests[i - 1] = _appStorage.request[i];
        }
    }

    function _getFeesAccrued(LibAppStorage.Layout storage _appStorage, address _token)
        internal
        view
        returns (uint256)
    {
        return _appStorage.s_feesAccrued[_token];
    }
}
