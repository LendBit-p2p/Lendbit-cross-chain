// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {IERC20} from "@chainlink/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@chainlink/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/utils/SafeERC20.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/contracts/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/contracts/libraries/Client.sol";

contract SpokeContract {
    address public constant NATIVE_TOKEN = address(1);
    address immutable i_hub;
    uint64 immutable i_chainSelector;
    LinkTokenInterface immutable i_link;
    IRouterClient immutable i_router;

    constructor(
        address _hub,
        uint64 _chainSelector,
        address _link,
        address _router
    ) {
        i_hub = _hub;
        i_chainSelector = _chainSelector;
        i_link = LinkTokenInterface(_link);
        i_router = IRouterClient(_router);

        i_link.approve(address(i_router), type(uint256).max);
    }

    // lp

    /**
     * @notice Deposit tokens into the pool
     * @param token The address of the token to deposit
     * @param amount The amount of tokens to deposit
     * @return shares The amount of shares received
     */
    function deposit(
        address token,
        uint256 amount
    ) external payable returns (uint256 shares) {
        //TODO: // Currently Working on the Todo
        return 0;
    }

    /**
     * @notice Withdraw tokens from the pool
     * @param token The address of the token to withdraw
     * @param amount The amount of tokens to withdraw
     * @return amountWithdrawn The amount of tokens withdrawn
     */
    function withdraw(
        address token,
        uint256 amount
    ) external returns (uint256 amountWithdrawn) {
        //TODO: // Currently Working on the Todo
        return 0;
    }

    /**
     * @notice Borrow tokens from the pool
     * @param token The address of the token to borrow
     * @param amount The amount of tokens to borrow
     */
    function borrowFromPool(address token, uint256 amount) external {
        //TODO: // Currently Working on the Todo
    }

    /**
     * @notice Repay tokens to the pool
     * @param token The address of the token to repay
     * @param amount The amount of tokens to repay
     * @return amountRepaid The amount of tokens repaid
     */
    function repay(
        address token,
        uint256 amount
    ) external payable returns (uint256 amountRepaid) {
        //TODO: // Currently Working on the Todo
        return 0;
    }

    // P2P
    /**
     * @notice Create a lending request
     * @param _amount The amount of tokens to lend
     * @param _interest The interest rate
     * @param _returnDate The date the loan is due
     * @param _loanCurrency The currency of the loan
     */
    function createLendingRequest(
        uint128 _amount,
        uint16 _interest,
        uint256 _returnDate,
        address _loanCurrency
    ) external {
        //TODO: // Currently Working on the Todo
    }

    /**
     * @notice Service a lending request
     * @param _requestId The ID of the request
     * @param _tokenAddress The address of the token to service
     */
    function serviceRequest(
        uint96 _requestId,
        address _tokenAddress
    ) external payable {
        //TODO: // Currently Working on the Todo
    }

    /**
     * @notice Close a listing ad
     * @param _listingId The ID of the listing
     */
    function closeListingAd(uint96 _listingId) external {
        //TODO: // Currently Working on the Todo
    }

    /**
     * @notice Close a lending request
     * @param _requestId The ID of the request
     */
    function closeRequest(uint96 _requestId) external {
        //TODO: // Currently Working on the Todo
    }

    /**
     * @notice Create a loan listing
     * @param _amount The amount of tokens to lend
     * @param _min_amount The minimum amount of tokens to lend
     * @param _max_amount The maximum amount of tokens to lend
     * @param _returnDate The date the loan is due
     * @param _interest The interest rate
     * @param _loanCurrency The currency of the loan
     * @param _whitelist The addresses of the whitelisted tokens
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
        //TODO: // Currently Working on the Todo
    }

    /**
     * @notice Request a loan from a listing
     * @param _listingId The ID of the listing
     * @param _amount The amount of tokens to request
     */
    function requestLoanFromListing(uint96 _listingId, uint256 _amount) public {
        //TODO: // Currently Working on the Todo
    }

    /**
     * @notice Repay a loan
     * @param _requestId The ID of the request
     * @param _amount The amount of tokens to repay
     */
    function repayLoan(uint96 _requestId, uint256 _amount) external payable {
        //TODO: // Currently Working on the Todo
    }

    // Shared
    /**
     * @notice Deposit collateral
     * @param _tokenCollateralAddress The address of the collateral token
     * @param _amountOfCollateral The amount of collateral to deposit
     */
    function depositCollateral(
        address _tokenCollateralAddress,
        uint256 _amountOfCollateral
    ) external payable {
        //TODO: // Currently Working on the Todo
    }

    /**
     * @notice Withdraw collateral
     * @param _tokenCollateralAddress The address of the collateral token
     * @param _amountOfCollateral The amount of collateral to withdraw
     */
    function withdrawCollateral(
        address _tokenCollateralAddress,
        uint256 _amountOfCollateral
    ) external {
        //TODO: // Currently Working on the Todo
    }
}
