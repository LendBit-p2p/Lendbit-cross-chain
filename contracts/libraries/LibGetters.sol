// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {LibAppStorage} from "./LibAppStorage.sol";
import {Constants} from "../utils/constants/Constant.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../model/Protocol.sol";
import "../utils/validators/Error.sol";
import {Utils} from "../utils/functions/Utils.sol";
import {LibInterestRateModel} from "./LibInterestRateModel.sol";
import {LibInterestAccure} from "./LibInterestAccure.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LibLiquidityPool} from "./LibLiquidityPool.sol";

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

    /**
     * @notice Calculates the current debt for a specific user including accrued interest
     * @param userBorrowData The user's borrow data from storage
     * @param tokenData The token's data from storage
     * @param protocolPool The protocol pool data from storage
     * @return debt The current debt amount including interest
     */
    function calculateUserDebt(
        UserBorrowData memory userBorrowData,
        TokenData memory tokenData,
        ProtocolPool memory protocolPool
    ) internal view returns (uint256 debt) {
        if (!userBorrowData.isActive || userBorrowData.borrowedAmount == 0) return 0;

        if (block.timestamp == tokenData.lastUpdateTimestamp || tokenData.totalBorrows == 0) {
            return userBorrowData.borrowedAmount;
        }

        if (userBorrowData.borrowIndex == 0) return userBorrowData.borrowedAmount;

        uint256 timeElapsed = block.timestamp - tokenData.lastUpdateTimestamp;
        uint256 utilization = LibInterestRateModel.calculateUtilization(tokenData.totalBorrows, tokenData.poolLiquidity);
        uint256 interestRate = LibInterestRateModel.calculateInterestRate(protocolPool, utilization);
        uint256 factor = ((interestRate * timeElapsed) * 1e18) / (10000 * 31536000);
        uint256 currentBorrowIndex = tokenData.borrowIndex + ((tokenData.borrowIndex * factor) / 1e18);
        debt = (userBorrowData.borrowedAmount * currentBorrowIndex) / userBorrowData.borrowIndex;

        return debt;
    }

    /**
     * @notice Get vault info for a specific token
     * @param token The token address
     * @return exists Whether vault exists
     * @return vaultAddress The vault address
     * @return totalDeposits Total deposits in the vault
     */
    function _getVaultInfo(LibAppStorage.Layout storage _appStorage, address token)
        internal
        view
        returns (bool exists, address vaultAddress, uint256 totalDeposits)
    {
        vaultAddress = _appStorage.s_vaults[token];
        exists = vaultAddress != address(0);
        totalDeposits = _appStorage.s_vaultDeposits[token];
    }

    /**
     * @notice Get user's vault token balance
     * @param user The user address
     * @param token The underlying token address
     * @return balance User's vault token balance
     */
    function _getUserVaultBalance(LibAppStorage.Layout storage _appStorage, address user, address token)
        internal
        view
        returns (uint256 balance)
    {
        address vaultAddress = _appStorage.s_vaults[token];
        if (vaultAddress == address(0)) return 0;

        return IERC20(vaultAddress).balanceOf(user);
    }

    /**
     * @notice Gets the borrow data for a specific user and token
     * @param _user The address of the user
     * @param _token The address of the tok en
     * @return borrowedAmount The amount borrowed by the user
     * @return borrowIndex The borrow index for the user
     * @return lastUpdateTimestamp The last update timestamp for the user's borrow data
     * @return isActive Whether the user's borrow is active
     */
    function _getUserBorrowData(LibAppStorage.Layout storage _appStorage, address _user, address _token)
        internal
        view
        returns (uint256 borrowedAmount, uint256 borrowIndex, uint256 lastUpdateTimestamp, bool isActive)
    {
        borrowedAmount = LibLiquidityPool._calculateUserDebt(
            _appStorage.s_tokenData[_token], _appStorage.s_userBorrows[_user][_token]
        );

        return (
            borrowedAmount,
            _appStorage.s_userBorrows[_user][_token].borrowIndex,
            _appStorage.s_userBorrows[_user][_token].lastUpdateTimestamp,
            _appStorage.s_userBorrows[_user][_token].isActive
        );
    }

    /**
     * @notice Gets the configuration of the protocol pool
     * @return token The token address used in the pool
     * @return totalSupply The total supply of tokens in the pool
     * @return totalBorrows The total amount borrowed from the pool
     * @return reserveFactor The reserve factor of the pool
     * @return optimalUtilization The optimal utilization rate
     * @return baseRate The base interest rate
     * @return slopeRate The slope rate for interest calculation
     * @return isActive Whether the pool is active
     * @return initialize Whether the pool is initialized
     */
    function _getProtocolPoolConfig(LibAppStorage.Layout storage _appStorage, address _token)
        internal
        view
        returns (
            address token,
            uint256 totalSupply,
            uint256 totalBorrows,
            uint256 reserveFactor,
            uint256 optimalUtilization,
            uint256 baseRate,
            uint256 slopeRate,
            bool isActive,
            bool initialize
        )
    {
        return (
            _appStorage.s_protocolPool[_token].token,
            _appStorage.s_protocolPool[_token].totalSupply,
            _appStorage.s_protocolPool[_token].totalBorrows,
            _appStorage.s_protocolPool[_token].reserveFactor,
            _appStorage.s_protocolPool[_token].optimalUtilization,
            _appStorage.s_protocolPool[_token].baseRate,
            _appStorage.s_protocolPool[_token].slopeRate,
            _appStorage.s_protocolPool[_token].isActive,
            _appStorage.s_protocolPool[_token].initialize
        );
    }

    /**
     * @notice Gets the user's pool deposit amount
     * @param user The address of the user
     * @param token The address of the token
     * @return The maximum redeemable amount for the user
     */
    function _getUserPoolDeposit(LibAppStorage.Layout storage _appStorage,address user,  address token)
        internal
        view
        returns (uint256)
    {
        return maxRedeemable(_appStorage, user, token);
    }

    /**
     * @notice Calculates the maximum redeemable amount for a user based on their shares
     * @param user The address of the user
     * @param token The address of the token
     * @return maxRedeemableAmount The maximum redeemable amount for the user
     */
    function maxRedeemable(LibAppStorage.Layout storage _appStorage, address user, address token)
        internal
        view
        returns (uint256)
    {
        // Check if the user has any shares in the pool
        uint256 _shares = _appStorage.s_addressToUserPoolShare[user][token];
        if (_shares == 0) return 0;

        TokenData memory _token = _appStorage.s_tokenData[token];
        // Calculate the maximum redeemable amount based on shares and pool liquidity
        uint256 _maxRedeemableAmount = Utils.convertToAmount(_token, _shares);

        return _maxRedeemableAmount;
    }

    /**
     * @notice gets token data for a specific token
     * @param token The address of the token
     * @return totalSupply The total supply of the token
     * @return poolLiquidity The total liquidity in the pool for the token
     * @return totalBorrows The total amount borrowed from the pool for the token
     * @return lastUpdateTimestamp The last time the token data was updated
     */
    function _getPoolTokenData(LibAppStorage.Layout storage _appStorage, address token)
        internal
        view
        returns (uint256 totalSupply, uint256 poolLiquidity, uint256 totalBorrows, uint256 lastUpdateTimestamp)
    {
        return (
            _appStorage.s_tokenData[token].totalSupply,
            _appStorage.s_tokenData[token].poolLiquidity,
            _appStorage.s_tokenData[token].totalBorrows,
            _appStorage.s_tokenData[token].lastUpdateTimestamp
        );
    }

    /**
     * @notice Calculates the current debt for a specific user including accrued interest
     * @param user The address of the user
     * @param token The address of the token
     * @return debt The current debt amount including interest
     */
    function _getUserDebt(LibAppStorage.Layout storage _appStorage, address user, address token)
        internal
        view
        returns (uint256 debt)
    {
        UserBorrowData memory userBorrowData = _appStorage.s_userBorrows[user][token];
        TokenData memory tokenData = _appStorage.s_tokenData[token];
        ProtocolPool memory protocolPool = _appStorage.s_protocolPool[token];

        debt = LibGettersImpl.calculateUserDebt(userBorrowData, tokenData, protocolPool);
    }
}
