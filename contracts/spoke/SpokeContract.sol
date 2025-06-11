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
import {CCIPMessageSent, CCIPMessageExecuted} from "./libraries/Events.sol";
import "./libraries/Errors.sol";

contract SpokeContract is CCIPReceiver {
    using SafeERC20 for IERC20;

    address public constant NATIVE_TOKEN = address(1);
    address immutable i_hub;
    uint64 immutable i_chainSelector;
    LinkTokenInterface immutable i_link;
    IWERC20 immutable i_weth;

    mapping(address => bool) public s_isTokenSupported;
    mapping(address => address) public s_tokenToHubTokens;
    mapping(bytes32 => bool) public s_isMessageExecuted;

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
     * @param tokenAddress The address of the token to deposit
     * @param amountToDeposit The amount of tokens to deposit

     */
    function deposit(
        address tokenAddress,
        uint256 amountToDeposit
    ) external payable  {
        //TODO: // Currently Working on the Todo

        if (!s_isTokenSupported[tokenAddress]) {
            revert Spoke__TokenNotSupported();
        }

        Validitions.validateTokenParams(
            tokenAddress,
            amountToDeposit
        );

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
            abi.encode(tokenAddress == NATIVE_TOKEN, amountToDeposit, msg.sender)
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
            tokenAddress == NATIVE_TOKEN &&
            msg.value < (fee + amountToDeposit)
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
    ) external  payable{
        //TODO: // Currently Working on the Todo

        if (!s_isTokenSupported[tokenAddress]) {
            revert Spoke__TokenNotSupported();
        }

        if(amountToWithdrawn == 0) {
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
    function borrowFromPool(address tokenAddress, uint256 amountToBorrow) external payable{
        //TODO: // Currently Working on the Todo

        if (!s_isTokenSupported[tokenAddress]) {
            revert Spoke__TokenNotSupported();
        }

     // ADD THIS CHECK

        if(amountToBorrow == 0) {
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
     * @notice Repay tokens to the pool
     * @param tokenAddress The address of the token to repay
     * @param amountToRepay The amount of tokens to repay
     */
    function repay(
        address tokenAddress,
        uint256 amountToRepay
    ) external payable  {
        //TODO: // Currently Working on the Todo


        if (!s_isTokenSupported[tokenAddress]) {
            revert Spoke__TokenNotSupported();
        }

        if(amountToRepay == 0) {
            revert Spoke__ZeroAmount();
        }

        Validitions.validateTokenParams(
            tokenAddress,
            amountToRepay
        );

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
            abi.encode(tokenAddress == NATIVE_TOKEN, msg.sender)
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
            tokenAddress == NATIVE_TOKEN &&
            msg.value < (fee + amountToRepay)
        ) {
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
            IERC20(tokenAddress).approve(
                address(i_ccipRouter),
                amountToRepay
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
    ) external payable returns (bytes32) {
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
    ) external payable {
        if (!s_isTokenSupported[_tokenCollateralAddress]) {
            revert Spoke__TokenNotSupported();
        }

        Client.EVMTokenAmount[]
            memory tokensToSendDetails = new Client.EVMTokenAmount[](0);

        bytes memory messageData = abi.encode(
            CCIPMessageType.WITHDRAW_COLLATERAL,
            abi.encode(
                s_tokenToHubTokens[_tokenCollateralAddress],
                _amountOfCollateral,
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

    function addToken(address _token, address _hubToken) external {
        s_isTokenSupported[_token] = true;
        s_tokenToHubTokens[_token] = _hubToken;
    }

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

        (bool _isNative, , address _receiver) = abi.decode(
            message.data,
            (bool, Client.EVMTokenAmount[], address)
        );

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

        s_isMessageExecuted[message.messageId] = true;

        emit CCIPMessageExecuted(
            message.messageId,
            i_chainSelector,
            _receiver,
            _destTokenAmounts
        );
    }
}
