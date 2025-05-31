// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AppStorage} from "./AppStorage.sol";
import {LibGettersImpl} from "../../libraries/LibGetters.sol";
import "../../model/Protocol.sol";

/**
 * @title Getters
 * @author LendBit Finance
 *
 * Public read-only functions that allow transparency into the state of LendBit
 */
contract Getters is AppStorage {
    /**
     * @notice This gets the USD value of amount of the token passsed.
     *
     * @param _token a collateral token address that is allowed in our Smart Contract
     * @param _amount the amount of that token you want to get the USD equivalent of.
     *
     * @return _value returns the equivalent amount in USD.
     */
    function getUsdValue(address _token, uint256 _amount, uint8 _decimal) external view returns (uint256 _value) {
        _value = LibGettersImpl._getUsdValue(_appStorage, _token, _amount, _decimal);
    }

    /**
     * @notice Calculates The value of converting one token to another using current market price e.g ETH -> USDC
     *
     * @param _from the address of the token you are trying to convert.
     * @param _to the address of the token you are converting to.
     * @param _amount the amount of `_from` tokens you are trying to convert.
     *
     * @return _value the amount of `_to` tokens you are expected to get.
     */
    function getConvertValue(address _from, address _to, uint256 _amount) external view returns (uint256 _value) {
        _value = LibGettersImpl._getConvertValue(_appStorage, _from, _to, _amount);
    }

    /**
     * @notice This gets the amount of collateral a user has deposited in USD.
     *
     * @param _user the address of the user you want to get their collateral value.
     *
     * @return _totalCollateralValueInUsd returns the value of the user deposited collateral in USD.
     */
    function getAccountCollateralValue(address _user) external view returns (uint256 _totalCollateralValueInUsd) {
        _totalCollateralValueInUsd = LibGettersImpl._getAccountCollateralValue(_appStorage, _user);
    }

    /**
     * @notice This gets the amount of available balance a user has in USD
     *
     * @param _user the address of the user you want to get their available balance value
     *
     * @return _totalAvailableValueInUsd returns the value of the user available balance in USD
     */
    function getAccountAvailableValue(address _user) external view returns (uint256 _totalAvailableValueInUsd) {
        _totalAvailableValueInUsd = LibGettersImpl._getAccountAvailableValue(_appStorage, _user);
    }

    /**
     * @notice Retrieves the details of a specific loan listing by its ID
     *
     * @param _listingId The ID of the listing to retrieve
     *
     * @return _listing The `LoanListing` struct containing details of the specified listing
     */
    function getLoanListing(uint96 _listingId) external view returns (LoanListing memory _listing) {
        _listing = LibGettersImpl._getLoanListing(_appStorage, _listingId);
    }

    /**
     * @notice Retrieves the details of a specific request by its ID
     *
     * @param _requestId The ID of the request to retrieve
     *
     * @return _request The `Request` struct containing details of the specified request
     */
    function getRequest(uint96 _requestId) external view returns (Request memory _request) {
        _request = LibGettersImpl._getRequest(_appStorage, _requestId);
    }

    /**
     * @notice Checks the health Factor which is a way to check if the user has enough collateral
     *
     * @param _user a parameter for the address to check
     *
     * @return _value the health factor which is supoose to be >= 1
     */
    function getHealthFactor(address _user) external view returns (uint256 _value) {
        _value = LibGettersImpl._healthFactor(_appStorage, _user, 0);
    }

    /**
     * @notice Gets the collection of all collateral token
     *
     * @return _tokens the collection of collateral addresses
     */
    function getAllCollateralToken() external view returns (address[] memory _tokens) {
        _tokens = _appStorage.s_collateralToken;
    }

    /**
     * @notice Gets the amount of collateral token a user has deposited
     *
     * @param _sender the user who has the collateral
     * @param _tokenAddr the user who has the collateral
     *
     * @return _value the amount of token deposited.
     */
    function getAddressToCollateralDeposited(address _sender, address _tokenAddr)
        external
        view
        returns (uint256 _value)
    {
        _value = _appStorage.s_addressToCollateralDeposited[_sender][_tokenAddr];
    }

    /**
     * @notice Gets the amount of token balance available to the user
     *
     * @param _sender the user who has the balance
     * @param _tokenAddr the user who has the balance
     *
     * @return _value the amount of token available
     */
    function getAddressToAvailableBalance(address _sender, address _tokenAddr) external view returns (uint256 _value) {
        _value = _appStorage.s_addressToAvailableBalance[_sender][_tokenAddr];
    }

    /**
     * @notice This gets the amount of a token that has been used to back a serviced request
     *
     * @param _requestId The Id of the serviced request.
     * @param _token The token in which was used to back the request
     *
     * @return _value The amount that as been used to back the loan
     */
    function getRequestToCollateral(uint96 _requestId, address _token) external view returns (uint256 _value) {
        _value = _appStorage.s_idToCollateralTokenAmount[_requestId][_token];
    }

    /**
     * @notice For getting all the assets that are loanable
     *
     * @return _assets An array of all loanable assets
     */
    function getLoanableAssets() external view returns (address[] memory _assets) {
        _assets = _appStorage.s_loanableToken;
    }

    /**
     * @notice Gets a request from a user
     *
     * @param _user the addresss of the user
     * @param _requestId the id of the request that was created by the user
     *
     * @return _request The request of the user
     */
    function getUserRequest(address _user, uint96 _requestId) external view returns (Request memory _request) {
        _request = LibGettersImpl._getUserRequest(_appStorage, _user, _requestId);
    }

    /**
     * @notice Gets all the active requests a user have
     *
     * @param _user the user you want to get their active requests
     *
     * @return _requests An array of active requests
     */
    function getUserActiveRequests(address _user) public view returns (Request[] memory _requests) {
        _requests = LibGettersImpl._getUserActiveRequests(_appStorage, _user);
    }

    /**
     * @notice Gets all requests that has been serviced by a particular lender
     *
     * @param _lender The lender that services the request.
     *
     * @return _requests An array of all request serviced by the lender
     */
    function getServicedRequestByLender(address _lender) public view returns (Request[] memory _requests) {
        _requests = LibGettersImpl._getServicedRequestByLender(_appStorage, _lender);
    }

    /**
     * @notice Get USD value of the total loan a user as collected.
     *
     * @param _user The user loan value you want to get.
     *
     * @return _value the total amount of collateral in USD.
     */
    function getLoanCollectedInUsd(address _user) public view returns (uint256 _value) {
        _value = LibGettersImpl._getLoanCollectedInUsd(_appStorage, _user);
    }

    /**
     * @notice Gets all the tokens a user has collateral in.
     *
     * @param _user The user you want to check for.
     *
     * @return _collaterals An array of address for the collateral tokens.
     */
    function getUserCollateralTokens(address _user) public view returns (address[] memory _collaterals) {
        _collaterals = LibGettersImpl._getUserCollateralTokens(_appStorage, _user);
    }

    /**
     * @notice Retrieves all the requests stored in the system
     *
     * @dev Returns an array of all requests
     *
     * @return _requests An array of `Request` structs representing all stored requests
     */
    function getAllRequest() external view returns (Request[] memory _requests) {
        _requests = LibGettersImpl._getAllRequest(_appStorage);
    }

    function getFeesAccrued(address _token) external view returns (uint256 _feesAccrued) {
        _feesAccrued = LibGettersImpl._getFeesAccrued(_appStorage, _token);
    }

    function getFeesRateBps() external view returns (uint16 _feeRate) {
        _feeRate = _appStorage.feeRateBps;
    }
}
