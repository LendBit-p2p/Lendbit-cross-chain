// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {IWERC20} from "@chainlink/contracts/src/v0.8/shared/interfaces/IWERC20.sol";
import {IERC20} from "@chainlink/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@chainlink/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/utils/SafeERC20.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/contracts/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/contracts/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/contracts/applications/CCIPReceiver.sol";
import {Validitions} from "./libraries/Validitions.sol";
import {CCIPMessageSent} from "./libraries/Events.sol";
import "./libraries/Errors.sol";

contract SpokeContract is CCIPReceiver {
    using SafeERC20 for IERC20;

    address public constant NATIVE_TOKEN = address(1);
    address immutable i_hub;
    uint64 immutable i_chainSelector;
    LinkTokenInterface immutable i_link;
    IWERC20 immutable i_weth;

    //enum for the CCIP message type
    enum CCIPMessageType {
        DEPOSIT,
        DEPOSIT_COLLATERAL,
        WITHDRAW,
        WITHDRAW_COLLATERAL,
        BORROW,
        CREATE_REQUEST,
        SERVICE_REQUEST,
        CREATE_LISTING,
        BORROW_FROM_LISTING,
        REPAY,
        REPAY_LOAN,
        LIQUIDATE
    }

    constructor(
        address _hub,
        uint64 _chainSelector,
        address _link,
        address _router,
        address _weth
    ) CCIPReceiver(_router) {
        i_hub = _hub;
        i_chainSelector = _chainSelector;
        i_link = LinkTokenInterface(_link);
        i_weth = IWERC20(_weth);

        i_link.approve(address(_router), type(uint256).max);
        IERC20(_weth).approve(address(_router), type(uint256).max);
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
        Validitions.validateTokenParams(
            _tokenCollateralAddress,
            _amountOfCollateral
        );

        Client.EVMTokenAmount[]
            memory tokensToSendDetails = new Client.EVMTokenAmount[](1);
        tokensToSendDetails[0] = Client.EVMTokenAmount({
            token: _tokenCollateralAddress == NATIVE_TOKEN
                ? address(i_weth)
                : _tokenCollateralAddress,
            amount: _amountOfCollateral
        });

        bytes memory messageData = abi.encode(
            CCIPMessageType.DEPOSIT_COLLATERAL,
            abi.encode(_tokenCollateralAddress == NATIVE_TOKEN, msg.sender)
        );

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(i_hub),
            data: messageData,
            tokenAmounts: tokensToSendDetails,
            extraArgs: Client._argsToBytes(
                Client.GenericExtraArgsV2({
                    gasLimit: 200_000,
                    allowOutOfOrderExecution: true
                })
            ),
            feeToken: address(0)
        });

        uint256 fee = IRouterClient(i_ccipRouter).getFee(
            i_chainSelector,
            message
        );

        if (
            _tokenCollateralAddress == NATIVE_TOKEN &&
            msg.value < (fee + _amountOfCollateral)
        ) {
            revert Spoke__InsufficientNativeCollateral();
        } else {
            if (msg.value < fee) {
                revert Spoke__InsufficientFee();
            }
        }

        if (_tokenCollateralAddress == NATIVE_TOKEN) {
            i_weth.deposit{value: _amountOfCollateral}();
        } else {
            IERC20(_tokenCollateralAddress).safeTransferFrom(
                msg.sender,
                address(this),
                _amountOfCollateral
            );
        }

        bytes32 messageId = IRouterClient(i_ccipRouter).ccipSend{
            value: msg.value
        }(i_chainSelector, message);

        emit CCIPMessageSent(
            messageId,
            i_chainSelector,
            msg.sender,
            tokensToSendDetails
        );
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

    //////////////////
    ///// GETTERS ////
    //////////////////
    function getFees(
        Client.EVM2AnyMessage memory message
    ) external view returns (uint256) {
        return IRouterClient(i_ccipRouter).getFee(i_chainSelector, message);
    }

    //////////////////
    /// INTERNALS ///
    ////////////////
    function _ccipReceive(
        Client.Any2EVMMessage memory message
    ) internal override {
        (CCIPMessageType messageType, bytes memory data) = abi.decode(
            message.data,
            (CCIPMessageType, bytes)
        );

        if (messageType == CCIPMessageType.DEPOSIT_COLLATERAL) {
            (
                address tokenCollateralAddress,
                uint256 amountOfCollateral,
                address sender
            ) = abi.decode(data, (address, uint256, address));
        }
    }
}
