// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {IWERC20} from "@chainlink/contracts/src/v0.8/shared/interfaces/IWERC20.sol";
import {IERC20} from "@chainlink/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@chainlink/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/utils/SafeERC20.sol";
import {IRouterClient} from "@chainlink/contract-ccip/contracts/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contract-ccip/contracts/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/contract-ccip/contracts/applications/CCIPReceiver.sol";
import {Validitions} from "./libraries/Validitions.sol";
import {CCIPMessageSent, CCIPMessageExecuted, CollateralDeposited} from "./libraries/Events.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "./libraries/Errors.sol";
import "../utils/constants/Constant.sol";

contract SpokeContract is CCIPReceiver, Ownable {
    using SafeERC20 for IERC20;

    address public constant NATIVE_TOKEN = address(1);
    address immutable i_hub;
    uint64 immutable i_chainSelector;
    IWERC20 immutable i_weth;
    LinkTokenInterface immutable i_link;

    mapping(address => bool) public s_isTokenSupported;
    mapping(address => address) public s_tokenToHubTokens;
    mapping(bytes32 => bool) public s_isMessageExecuted;
    mapping(address => TokenType) public s_tokenToType;
    mapping(address => mapping(address => uint256)) s_userCollateralBalances;

    enum TokenType {
        NOT_REGISTERED,
        CHAIN_SPECIFIC,
        INTEROPORABLE
    }

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
        LIQUIDATE,
        CLOSE_REQUEST,
        DEPOSIT_COLLATERAL_NOT_INTERPROABLE,
        WITHDRAW_COLLATERAL_NOT_INTERPOLABLE,
        CLOSE_LISTING
    }

    constructor(
        address _hub,
        uint64 _chainSelector,
        address _link,
        address _router,
        address _weth
    ) CCIPReceiver(_router) Ownable(msg.sender) {
        i_hub = _hub;
        i_chainSelector = _chainSelector;
        i_link = LinkTokenInterface(_link);
        i_weth = IWERC20(_weth);

        i_link.approve(address(_router), type(uint256).max);
        IERC20(_weth).approve(address(_router), type(uint256).max);
    }

    /**
     * @notice Deposit tokens into the pool
     * @param tokenAddress The address of the token to deposit
     * @param amountToDeposit The amount of tokens to deposit
     */
    function deposit(
        address tokenAddress,
        uint256 amountToDeposit
    ) external payable {
        if (!s_isTokenSupported[tokenAddress]) {
            revert Spoke__TokenNotSupported();
        }

        Validitions.validateTokenParams(tokenAddress, amountToDeposit);

        Client.EVMTokenAmount[]
            memory tokensToSendDetails = new Client.EVMTokenAmount[](1);
        tokensToSendDetails[0] = Client.EVMTokenAmount({
            token: tokenAddress == NATIVE_TOKEN
                ? address(i_weth)
                : tokenAddress,
            amount: amountToDeposit
        });

        bytes memory messageData = abi.encode(
            CCIPMessageType.DEPOSIT,
            abi.encode(
                tokenAddress == NATIVE_TOKEN,
                amountToDeposit,
                msg.sender
            )
        );

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(i_hub),
            data: messageData,
            tokenAmounts: tokensToSendDetails,
            extraArgs: Client._argsToBytes(
                Client.GenericExtraArgsV2({
                    gasLimit: 400_000,
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
            tokenAddress == NATIVE_TOKEN && msg.value < (fee + amountToDeposit)
        ) {
            revert Spoke__InsufficientNativeCollateral();
        } else {
            if (msg.value < fee) {
                revert Spoke__InsufficientFee();
            }
        }

        if (tokenAddress == NATIVE_TOKEN) {
            i_weth.deposit{value: amountToDeposit}();
            IERC20(address(i_weth)).approve(
                address(i_ccipRouter),
                amountToDeposit
            );
        } else {
            IERC20(tokenAddress).safeTransferFrom(
                msg.sender,
                address(this),
                amountToDeposit
            );
            IERC20(tokenAddress).approve(
                address(i_ccipRouter),
                amountToDeposit
            );
        }

        bytes32 messageId = IRouterClient(i_ccipRouter).ccipSend{value: fee}(
            i_chainSelector,
            message
        );

        emit CCIPMessageSent(
            messageId,
            i_chainSelector,
            msg.sender,
            tokensToSendDetails
        );
    }

    /**
     * @notice Withdraw tokens from the pool
     * @param tokenAddress The address of the token to withdraw
     * @param amountToWithdrawn The amount of tokens to withdraw
     */
    function withdraw(
        address tokenAddress,
        uint256 amountToWithdrawn
    ) external payable {
        //TODO: // Currently Working on the Todo

        if (!s_isTokenSupported[tokenAddress]) {
            revert Spoke__TokenNotSupported();
        }

        if (amountToWithdrawn == 0) {
            revert Spoke__ZeroAmount();
        }

        Client.EVMTokenAmount[]
            memory tokensToSendDetails = new Client.EVMTokenAmount[](0);

        bytes memory messageData = abi.encode(
            CCIPMessageType.WITHDRAW,
            abi.encode(
                s_tokenToHubTokens[tokenAddress],
                amountToWithdrawn,
                msg.sender
            )
        );

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(i_hub),
            data: messageData,
            tokenAmounts: tokensToSendDetails,
            extraArgs: Client._argsToBytes(
                Client.GenericExtraArgsV2({
                    gasLimit: 300_000,
                    allowOutOfOrderExecution: true
                })
            ),
            feeToken: address(0)
        });

        uint256 fee = IRouterClient(i_ccipRouter).getFee(
            i_chainSelector,
            message
        );

        if (msg.value < fee) {
            revert Spoke__InsufficientFee();
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
     * @notice Borrow tokens from the pool
     * @param tokenAddress The address of the token to borrow
     * @param amountToBorrow The amount of tokens to borrow
     */
    function borrowFromPool(
        address tokenAddress,
        uint256 amountToBorrow
    ) external payable {
        if (!s_isTokenSupported[tokenAddress]) {
            revert Spoke__TokenNotSupported();
        }

        if (amountToBorrow == 0) {
            revert Spoke__ZeroAmount();
        }

        Client.EVMTokenAmount[]
            memory tokensToSendDetails = new Client.EVMTokenAmount[](0);

        bytes memory messageData = abi.encode(
            CCIPMessageType.BORROW,
            abi.encode(
                s_tokenToHubTokens[tokenAddress],
                amountToBorrow,
                msg.sender
            )
        );

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(i_hub),
            data: messageData,
            tokenAmounts: tokensToSendDetails,
            extraArgs: Client._argsToBytes(
                Client.GenericExtraArgsV2({
                    gasLimit: 600_000,
                    allowOutOfOrderExecution: true
                })
            ),
            feeToken: address(0)
        });

        uint256 fee = IRouterClient(i_ccipRouter).getFee(
            i_chainSelector,
            message
        );

        if (msg.value < fee) {
            revert Spoke__InsufficientFee();
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
     * @notice Repay tokens to the pool
     * @param tokenAddress The address of the token to repay
     * @param amountToRepay The amount of tokens to repay
     */
    function repay(
        address tokenAddress,
        uint256 amountToRepay
    ) external payable {
        if (!s_isTokenSupported[tokenAddress]) {
            revert Spoke__TokenNotSupported();
        }

        if (amountToRepay == 0) {
            revert Spoke__ZeroAmount();
        }

        Validitions.validateTokenParams(tokenAddress, amountToRepay);

        Client.EVMTokenAmount[]
            memory tokensToSendDetails = new Client.EVMTokenAmount[](1);
        tokensToSendDetails[0] = Client.EVMTokenAmount({
            token: tokenAddress == NATIVE_TOKEN
                ? address(i_weth)
                : tokenAddress,
            amount: amountToRepay
        });

        bytes memory messageData = abi.encode(
            CCIPMessageType.REPAY,
            abi.encode(
                tokenAddress == NATIVE_TOKEN,
                tokenAddress,
                msg.sender,
                amountToRepay
            )
        );

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(i_hub),
            data: messageData,
            tokenAmounts: tokensToSendDetails,
            extraArgs: Client._argsToBytes(
                Client.GenericExtraArgsV2({
                    gasLimit: 600_000,
                    allowOutOfOrderExecution: true
                })
            ),
            feeToken: address(0)
        });

        uint256 fee = IRouterClient(i_ccipRouter).getFee(
            i_chainSelector,
            message
        );

        if (tokenAddress == NATIVE_TOKEN && msg.value < (fee + amountToRepay)) {
            revert Spoke__InsufficientNativeCollateral();
        } else {
            if (msg.value < fee) {
                revert Spoke__InsufficientFee();
            }
        }

        if (tokenAddress == NATIVE_TOKEN) {
            i_weth.deposit{value: amountToRepay}();
            IERC20(address(i_weth)).approve(
                address(i_ccipRouter),
                amountToRepay
            );
        } else {
            IERC20(tokenAddress).safeTransferFrom(
                msg.sender,
                address(this),
                amountToRepay
            );
            IERC20(tokenAddress).approve(address(i_ccipRouter), amountToRepay);
        }

        bytes32 messageId = IRouterClient(i_ccipRouter).ccipSend{value: fee}(
            i_chainSelector,
            message
        );

        emit CCIPMessageSent(
            messageId,
            i_chainSelector,
            msg.sender,
            tokensToSendDetails
        );
    }

    /**
     * @notice Create a lending request
     * @param _amount The amount of tokens to lend
     * @param _interest The interest rate
     * @param _returnDate The date the loan is due
     * @param _loanCurrency The currency of the loan
     */
    function createLendingRequest(
        uint256 _amount,
        uint16 _interest,
        uint256 _returnDate,
        address _loanCurrency
    ) external payable returns (bytes32) {
        if (!s_isTokenSupported[_loanCurrency]) {
            revert Spoke__TokenNotSupported();
        }

        if (_amount == 0) revert Spoke__InvalidAmount();
        if (_interest == 0) revert Spoke__InvalidInterest();

        if (_returnDate < block.timestamp + 1 days) {
            revert Spoke__DateMustBeInFuture();
        }

        bytes memory messageData = abi.encode(
            CCIPMessageType.CREATE_REQUEST,
            abi.encode(
                _amount,
                _interest,
                _returnDate,
                s_tokenToHubTokens[_loanCurrency],
                msg.sender
            )
        );

        Client.EVMTokenAmount[]
            memory tokensToSendDetails = new Client.EVMTokenAmount[](0);

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(i_hub),
            data: messageData,
            tokenAmounts: tokensToSendDetails,
            extraArgs: Client._argsToBytes(
                Client.GenericExtraArgsV2({
                    gasLimit: 600_000,
                    allowOutOfOrderExecution: true
                })
            ),
            feeToken: address(0)
        });

        uint256 fee = IRouterClient(i_ccipRouter).getFee(
            i_chainSelector,
            message
        );

        if (msg.value < fee) {
            revert Spoke__InsufficientFee();
        }

        bytes32 messageId = IRouterClient(i_ccipRouter).ccipSend{value: fee}(
            i_chainSelector,
            message
        );

        emit CCIPMessageSent(
            messageId,
            i_chainSelector,
            msg.sender,
            tokensToSendDetails
        );

        return messageId;
    }

    /**
     * @notice Service a lending request
     * @param _requestId The ID of the request
     * @param _tokenAddress The address of the token to service
     */
    function serviceRequest(
        uint96 _requestId,
        address _tokenAddress,
        uint256 _amount
    ) external payable returns (bytes32) {
        if (!s_isTokenSupported[_tokenAddress]) {
            revert Spoke__TokenNotSupported();
        }

        Validitions.validateTokenParams(_tokenAddress, _amount);

        if (_requestId == 0) revert Spoke__InvalidRequest();

        bytes memory messageData = abi.encode(
            CCIPMessageType.SERVICE_REQUEST,
            abi.encode(_requestId, _tokenAddress == NATIVE_TOKEN, msg.sender)
        );

        Client.EVMTokenAmount[]
            memory tokensToSendDetails = new Client.EVMTokenAmount[](1);
        tokensToSendDetails[0] = Client.EVMTokenAmount({
            token: _tokenAddress == NATIVE_TOKEN
                ? address(i_weth)
                : _tokenAddress,
            amount: _amount
        });

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(i_hub),
            data: messageData,
            tokenAmounts: tokensToSendDetails,
            extraArgs: Client._argsToBytes(
                Client.GenericExtraArgsV2({
                    gasLimit: 500_000,
                    allowOutOfOrderExecution: true
                })
            ),
            feeToken: address(0)
        });

        uint256 fee = IRouterClient(i_ccipRouter).getFee(
            i_chainSelector,
            message
        );

        if (_tokenAddress == NATIVE_TOKEN && msg.value < (fee + _amount)) {
            revert Spoke__InsufficientNativeCollateral();
        } else {
            if (msg.value < fee) {
                revert Spoke__InsufficientFee();
            }
        }

        if (_tokenAddress == NATIVE_TOKEN) {
            i_weth.deposit{value: _amount}();
            IERC20(address(i_weth)).approve(address(i_ccipRouter), _amount);
        } else {
            IERC20(_tokenAddress).safeTransferFrom(
                msg.sender,
                address(this),
                _amount
            );
            IERC20(_tokenAddress).approve(address(i_ccipRouter), _amount);
        }

        bytes32 messageId = IRouterClient(i_ccipRouter).ccipSend{value: fee}(
            i_chainSelector,
            message
        );

        emit CCIPMessageSent(
            messageId,
            i_chainSelector,
            msg.sender,
            tokensToSendDetails
        );

        return messageId;
    }

    /**
     * @notice Close a listing ad
     * @param _listingId The ID of the listing
     */
    function closeListingAd(
        uint96 _listingId
    ) external payable returns (bytes32) {
        //TODO: // Currently Working on the Todo
        Client.EVMTokenAmount[]
            memory tokensToSendDetails = new Client.EVMTokenAmount[](0);

        bytes memory messageData = abi.encode(
            CCIPMessageType.CLOSE_LISTING,
            abi.encode(_listingId, msg.sender)
        );

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(i_hub),
            data: messageData,
            tokenAmounts: tokensToSendDetails,
            extraArgs: Client._argsToBytes(
                Client.GenericExtraArgsV2({
                    gasLimit: 300_000,
                    allowOutOfOrderExecution: true
                })
            ),
            feeToken: address(0)
        });

        uint256 fee = IRouterClient(i_ccipRouter).getFee(
            i_chainSelector,
            message
        );

        if (msg.value < fee) {
            revert Spoke__InsufficientFee();
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

        return messageId;
    }

    /**
     * @notice Close a lending request
     * @param _requestId The ID of the request
     */
    function closeRequest(
        uint96 _requestId
    ) external payable returns (bytes32) {
        Client.EVMTokenAmount[]
            memory tokensToSendDetails = new Client.EVMTokenAmount[](0);

        bytes memory messageData = abi.encode(
            CCIPMessageType.CLOSE_REQUEST,
            abi.encode(_requestId, msg.sender)
        );

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(i_hub),
            data: messageData,
            tokenAmounts: tokensToSendDetails,
            extraArgs: Client._argsToBytes(
                Client.GenericExtraArgsV2({
                    gasLimit: 300_000,
                    allowOutOfOrderExecution: true
                })
            ),
            feeToken: address(0)
        });

        uint256 fee = IRouterClient(i_ccipRouter).getFee(
            i_chainSelector,
            message
        );

        if (msg.value < fee) {
            revert Spoke__InsufficientFee();
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

        return messageId;
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
    ) external payable returns (bytes32) {
        if (!s_isTokenSupported[_loanCurrency]) {
            revert Spoke__TokenNotSupported();
        }

        if (
            _loanCurrency != NATIVE_TOKEN &&
            IERC20(_loanCurrency).balanceOf(msg.sender) < _amount
        ) {
            revert Spoke__InsufficientCollateral();
        }

        Client.EVMTokenAmount[]
            memory tokensToSendDetails = new Client.EVMTokenAmount[](1);
        tokensToSendDetails[0] = Client.EVMTokenAmount({
            token: _loanCurrency == NATIVE_TOKEN
                ? address(i_weth)
                : _loanCurrency,
            amount: _amount
        });

        bytes memory messageData = abi.encode(
            CCIPMessageType.CREATE_LISTING,
            abi.encode(
                msg.sender,
                s_tokenToHubTokens[_loanCurrency],
                _amount,
                _min_amount,
                _max_amount,
                _interest,
                _returnDate,
                _whitelist
            )
        );

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(i_hub),
            data: messageData,
            tokenAmounts: tokensToSendDetails,
            extraArgs: Client._argsToBytes(
                Client.GenericExtraArgsV2({
                    gasLimit: 300_000,
                    allowOutOfOrderExecution: true
                })
            ),
            feeToken: address(0)
        });

        uint256 fee = IRouterClient(i_ccipRouter).getFee(
            i_chainSelector,
            message
        );

        if (_loanCurrency == NATIVE_TOKEN && msg.value < (fee + _amount)) {
            revert Spoke__InsufficientNativeCollateral();
        } else {
            if (msg.value < fee) {
                revert Spoke__InsufficientFee();
            }
        }

        if (_loanCurrency == NATIVE_TOKEN) {
            i_weth.deposit{value: _amount}();
            IERC20(address(i_weth)).approve(address(i_ccipRouter), _amount);
        } else {
            IERC20(_loanCurrency).safeTransferFrom(
                msg.sender,
                address(this),
                _amount
            );
            IERC20(_loanCurrency).approve(address(i_ccipRouter), _amount);
        }

        bytes32 messageId = IRouterClient(i_ccipRouter).ccipSend{value: fee}(
            i_chainSelector,
            message
        );

        emit CCIPMessageSent(
            messageId,
            i_chainSelector,
            msg.sender,
            tokensToSendDetails
        );

        return messageId;
    }

    /**
     * @notice Request a loan from a listing
     * @param _listingId The ID of the listing
     * @param _amount The amount of tokens to request
     */
    function requestLoanFromListing(
        uint96 _listingId,
        uint256 _amount
    ) external payable returns (bytes32) {
        Client.EVMTokenAmount[]
            memory tokensToSendDetails = new Client.EVMTokenAmount[](0);

        bytes memory messageData = abi.encode(
            CCIPMessageType.BORROW_FROM_LISTING,
            abi.encode(msg.sender, _listingId, _amount)
        );

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(i_hub),
            data: messageData,
            tokenAmounts: tokensToSendDetails,
            extraArgs: Client._argsToBytes(
                Client.GenericExtraArgsV2({
                    gasLimit: 1_000_000,
                    allowOutOfOrderExecution: true
                })
            ),
            feeToken: address(0)
        });

        uint256 fee = IRouterClient(i_ccipRouter).getFee(
            i_chainSelector,
            message
        );

        bytes32 messageId = IRouterClient(i_ccipRouter).ccipSend{value: fee}(
            i_chainSelector,
            message
        );

        emit CCIPMessageSent(
            messageId,
            i_chainSelector,
            msg.sender,
            tokensToSendDetails
        );

        return messageId;
    }

    /**
     * @notice Repay a loan
     * @param _requestId The ID of the request
     * @param _amount The amount of tokens to repay
     */
    function repayLoan(
        uint96 _requestId,
        address _token,
        uint256 _amount
    ) external payable returns (bytes32) {
        //TODO: // Currently Working on the Todo
        if (!s_isTokenSupported[_token]) {
            revert Spoke__TokenNotSupported();
        }

        Validitions.validateTokenParams(_token, _amount);

        Client.EVMTokenAmount[]
            memory tokensToSendDetails = new Client.EVMTokenAmount[](1);
        tokensToSendDetails[0] = Client.EVMTokenAmount({
            token: _token == NATIVE_TOKEN ? address(i_weth) : _token,
            amount: _amount
        });

        bytes memory messageData = abi.encode(
            CCIPMessageType.REPAY_LOAN,
            abi.encode(_requestId, _amount, msg.sender)
        );

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(i_hub),
            data: messageData,
            tokenAmounts: tokensToSendDetails,
            extraArgs: Client._argsToBytes(
                Client.GenericExtraArgsV2({
                    gasLimit: 300_000,
                    allowOutOfOrderExecution: true
                })
            ),
            feeToken: address(0)
        });

        uint256 fee = IRouterClient(i_ccipRouter).getFee(
            i_chainSelector,
            message
        );

        if (_token == NATIVE_TOKEN && msg.value < (fee + _amount)) {
            revert Spoke__InsufficientNativeCollateral();
        } else {
            if (msg.value < fee) {
                revert Spoke__InsufficientFee();
            }
        }

        if (_token == NATIVE_TOKEN) {
            i_weth.deposit{value: _amount}();
            IERC20(address(i_weth)).approve(address(i_ccipRouter), _amount);
        } else {
            IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
            IERC20(_token).approve(address(i_ccipRouter), _amount);
        }

        bytes32 messageId = IRouterClient(i_ccipRouter).ccipSend{value: fee}(
            i_chainSelector,
            message
        );

        emit CCIPMessageSent(
            messageId,
            i_chainSelector,
            msg.sender,
            tokensToSendDetails
        );

        return messageId;
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
    ) external payable returns (bytes32) {
        if (
            s_tokenToType[_tokenCollateralAddress] == TokenType.CHAIN_SPECIFIC
        ) {
            return
                depositCollateralThatNotInterpro(
                    _tokenCollateralAddress,
                    _amountOfCollateral,
                    msg.sender
                );
        }

        if (!s_isTokenSupported[_tokenCollateralAddress]) {
            revert Spoke__TokenNotSupported();
        }

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
            IERC20(address(i_weth)).approve(
                address(i_ccipRouter),
                _amountOfCollateral
            );
        } else {
            IERC20(_tokenCollateralAddress).safeTransferFrom(
                msg.sender,
                address(this),
                _amountOfCollateral
            );
            IERC20(_tokenCollateralAddress).approve(
                address(i_ccipRouter),
                _amountOfCollateral
            );
        }

        bytes32 messageId = IRouterClient(i_ccipRouter).ccipSend{value: fee}(
            i_chainSelector,
            message
        );

        emit CCIPMessageSent(
            messageId,
            i_chainSelector,
            msg.sender,
            tokensToSendDetails
        );
        return messageId;
    }

    /**
     * @notice Withdraw collateral
     * @param _tokenCollateralAddress The address of the collateral token
     * @param _amountOfCollateral The amount of collateral to withdraw
     */
    function withdrawCollateral(
        address _tokenCollateralAddress,
        uint256 _amountOfCollateral
    ) external payable returns (bytes32) {
        if (_amountOfCollateral < 1) {
            revert Spoke__CollateralAmountTooLow();
        }
        if (_tokenCollateralAddress == address(0)) {
            revert Spoke__InvalidCollateralToken();
        }

        if (!s_isTokenSupported[_tokenCollateralAddress]) {
            revert Spoke__TokenNotSupported();
        }

        bytes memory messageData = "";

        if (
            s_tokenToType[_tokenCollateralAddress] == TokenType.CHAIN_SPECIFIC
        ) {
            if (
                s_userCollateralBalances[_tokenCollateralAddress][msg.sender] <
                _amountOfCollateral
            ) {
                revert Spoke__InsufficientCollateral();
            }

            messageData = abi.encode(
                CCIPMessageType.WITHDRAW_COLLATERAL_NOT_INTERPOLABLE,
                abi.encode(
                    msg.sender,
                    s_tokenToHubTokens[_tokenCollateralAddress],
                    _amountOfCollateral,
                    _tokenCollateralAddress == NATIVE_TOKEN
                )
            );
        } else {
            messageData = abi.encode(
                CCIPMessageType.WITHDRAW_COLLATERAL,
                abi.encode(
                    s_tokenToHubTokens[_tokenCollateralAddress],
                    _amountOfCollateral,
                    msg.sender
                )
            );
        }

        Client.EVMTokenAmount[]
            memory tokensToSendDetails = new Client.EVMTokenAmount[](0);

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(i_hub),
            data: messageData,
            tokenAmounts: tokensToSendDetails,
            extraArgs: Client._argsToBytes(
                Client.GenericExtraArgsV2({
                    gasLimit: 400_000,
                    allowOutOfOrderExecution: true
                })
            ),
            feeToken: address(0)
        });

        uint256 fee = IRouterClient(i_ccipRouter).getFee(
            i_chainSelector,
            message
        );

        if (msg.value < fee) {
            revert Spoke__InsufficientFee();
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

        return messageId;
    }

    function addToken(
        address _token,
        address _hubToken,
        TokenType _tokenType
    ) external {
        s_isTokenSupported[_token] = true;
        s_tokenToHubTokens[_token] = _hubToken;
        s_tokenToType[_token] = _tokenType;
    }

    receive() external payable {}

    //////////////////
    ///// GETTERS ////
    //////////////////
    function getFees(
        Client.EVM2AnyMessage memory message
    ) external view returns (uint256) {
        return IRouterClient(i_ccipRouter).getFee(i_chainSelector, message);
    }

    function getHubTokenAddress(
        address _token
    ) external view returns (address) {
        return s_tokenToHubTokens[_token];
    }

    //////////////////
    /// INTERNALS ///
    ////////////////

    function _ccipReceive(
        Client.Any2EVMMessage memory message
    ) internal override {
        address _sender = abi.decode(message.sender, (address));
        if (
            _sender != i_hub || message.sourceChainSelector != i_chainSelector
        ) {
            revert Spoke__NotHub();
        }
        if (s_isMessageExecuted[message.messageId]) {
            revert Spoke__AlreadyConsumed();
        }

        (
            address _receiver,
            bool _isNative,
            Client.EVMTokenAmount[] memory _tokens,
            bool _isRelease
        ) = abi.decode(
                message.data,
                (address, bool, Client.EVMTokenAmount[], bool)
            );

        if (_isRelease) {
            if (_isNative) {
                uint256 userBalance = s_userCollateralBalances[NATIVE_TOKEN][
                    _receiver
                ];
                if (userBalance < _tokens[0].amount) {
                    revert Spoke__InsufficientCollateral();
                }
                (bool success, ) = _receiver.call{value: _tokens[0].amount}("");

                if (!success) {
                    revert Spoke__TransferFailed();
                }
            } else {
                uint256 userBalance = s_userCollateralBalances[
                    _tokens[0].token
                ][_receiver];
                if (userBalance < _tokens[0].amount) {
                    revert Spoke__InsufficientCollateral();
                }
                IERC20(_tokens[0].token).safeTransfer(
                    _receiver,
                    _tokens[0].amount
                );
            }
        } else {
            Client.EVMTokenAmount[] memory _destTokenAmounts = message
                .destTokenAmounts;

            if (_isNative) {
                i_weth.withdraw(_destTokenAmounts[0].amount);
                (bool success, ) = _receiver.call{
                    value: _destTokenAmounts[0].amount
                }("");

                if (!success) {
                    revert Spoke__TransferFailed();
                }
            } else {
                IERC20(_destTokenAmounts[0].token).safeTransfer(
                    _receiver,
                    _destTokenAmounts[0].amount
                );
            }
        }

        s_isMessageExecuted[message.messageId] = true;
        emit CCIPMessageExecuted(
            message.messageId,
            i_chainSelector,
            _receiver,
            _isRelease ? _tokens : message.destTokenAmounts
        );
    }

    /**
     * @notice Deposits collateral that remains on this spoke chain (not bridged)
     * @param _token The address of the token to deposit as collateral
     * @param _amount The amount of collateral to deposit
     * @return messageId The CCIP message ID for tracking the state update
     */
    function depositCollateralThatNotInterpro(
        address _token,
        uint256 _amount,
        address _user
    ) internal returns (bytes32 messageId) {
        Validitions.validateTokenParams(_token, _amount);

        if (_token != NATIVE_TOKEN) {
            IERC20(_token).safeTransferFrom(_user, address(this), _amount);
        }

        s_userCollateralBalances[_token][msg.sender] += _amount;

        messageId = _notifyHubOnCollateralOperation(
            msg.sender,
            _token,
            _amount,
            CCIPMessageType.DEPOSIT_COLLATERAL_NOT_INTERPROABLE
        );
    }

    /**
     * @notice Notifies the hub about a collateral deposit via CCIP message
     * @param _user The user who deposited collateral
     * @param _token The token address deposited
     * @param _amount The amount deposited
     * @return messageId The CCIP message ID
     */
    function _notifyHubOnCollateralOperation(
        address _user,
        address _token,
        uint256 _amount,
        CCIPMessageType ccipMessage
    ) internal returns (bytes32 messageId) {
        Client.EVMTokenAmount[]
            memory emptyTokenAmounts = new Client.EVMTokenAmount[](0);

        bytes memory messageData = abi.encode(
            ccipMessage,
            abi.encode(_user, s_tokenToHubTokens[_token], _amount)
        );

        // Prepare CCIP message
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(i_hub),
            data: messageData,
            tokenAmounts: emptyTokenAmounts,
            extraArgs: Client._argsToBytes(
                Client.GenericExtraArgsV2({
                    gasLimit: 200_000,
                    allowOutOfOrderExecution: true
                })
            ),
            feeToken: address(0) // Pay fees in native token
        });

        // Calculate and validate fee
        uint256 fee = IRouterClient(i_ccipRouter).getFee(
            i_chainSelector,
            message
        );
        if (msg.value < fee) {
            revert Spoke__InsufficientFee();
        }

        // Send CCIP message
        messageId = IRouterClient(i_ccipRouter).ccipSend{value: fee}(
            i_chainSelector,
            message
        );

        // Emit event (no tokens sent via CCIP, just notification)
        emit CCIPMessageSent(
            messageId,
            i_chainSelector,
            msg.sender,
            emptyTokenAmounts
        );

        return messageId;
    }

    function getContractBalance(
        address _token
    ) external view returns (uint256) {
        return IERC20(_token).balanceOf(address(this));
    }

    /**
     * @notice Get user's collateral balance for a specific token
     * @param _user The user address
     * @return uint256 The collateral balance
     */
    function getUserCollateralBalance(
        address _user,
        address _token
    ) external view returns (uint256) {
        return s_userCollateralBalances[_token][_user];
    }
}
