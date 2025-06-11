// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../model/Protocol.sol";
import "../../model/Event.sol";
import "../../utils/validators/Error.sol";
import "../../utils/validators/Validator.sol";
import "../../utils/constants/Constant.sol";
import "../LibAppStorage.sol";
import {LibGettersImpl} from "../LibGetters.sol";
import {IWERC20} from "@chainlink/contracts/src/v0.8/shared/interfaces/IWERC20.sol";
import {Client} from "@chainlink/contract-ccip/contracts/libraries/Client.sol";
import {LibCCIP} from "./LibCCIP.sol";
import {ILendbitTokenVault} from "../../interfaces/ILendbitTokenVault.sol";
import {Utils} from "../../utils/functions/Utils.sol";
import {LibInterestAccure} from "../LibInterestAccure.sol";
import {LibLiquidityPool} from "../LibLiquidityPool.sol";

library LibxLiquidityPool {
    using SafeERC20 for IERC20;

    /**
     * @dev Allows a user to deposit tokens into the liquidity pool.
     * @param _appStorage The app storage layout.
     * @param _token The address of the token to deposit.
     * @param _amount The amount of tokens to deposit.
     * @param _user The address of the user depositing the tokens.
     * @param _chainSelector The chain selector for cross-chain operations.
     */
    function _deposit(
        LibAppStorage.Layout storage _appStorage,
        address _token,
        uint256 _amount,
        address _user,
        uint64 _chainSelector
    ) internal {
        // Validation checks
        if (!_appStorage.s_protocolPool[_token].initialize) {
            revert ProtocolPool__NotInitialized();
        }

        if (_amount == 0) {
            revert ProtocolPool__ZeroAmount();
        }

        if (!_appStorage.s_protocolPool[_token].isActive) {
            revert ProtocolPool__IsNotActive();
        }

        // Calculate shares based on the amount deposited
        uint256 shares = Utils.convertToShares(_appStorage.s_tokenData[_token], _amount);

        // Update state variables
        _appStorage.s_protocolPool[_token].totalSupply += shares;
        _appStorage.s_tokenData[_token].totalSupply += shares;
        _appStorage.s_tokenData[_token].poolLiquidity += _amount;
        _appStorage.s_tokenData[_token].lastUpdateTimestamp = block.timestamp;
        _appStorage.s_addressToUserPoolShare[_user][_token] += shares;

        // Handle vault operations
        address vaultAddress = _appStorage.s_vaults[_token];
        if (vaultAddress == address(0)) {
            revert ProtocolPool__VaultNotDeployed();
        }

        // Update vault deposits and mint vault tokens for the user
        _appStorage.s_vaultDeposits[_token] += shares;
        ILendbitTokenVault(vaultAddress).mintFor(_user, shares);

        // Emit deposit event
        emit Deposit(_user, _token, _amount, shares, _chainSelector);
    }


/**
 * @dev Allows users to withdraw tokens from the liquidity pool using vault tokens only
 * @param _appStorage The app storage layout
 * @param _token The address of the token to withdraw
 * @param _amount The amount of token to withdraw (0 for max withdrawal)
 * @param _user The address of the user withdrawing
 * @param _chainSelector The chain selector for cross-chain operations
 * @return amountWithdrawn The actual amount of tokens withdrawn
 */
function _withdraw(
    LibAppStorage.Layout storage _appStorage,
    address _token,
    uint256 _amount,
    address _user,
    uint64 _chainSelector
) internal returns (uint256 amountWithdrawn) {
    // Validate withdraw conditions
    if (!_appStorage.s_protocolPool[_token].initialize) {
        revert ProtocolPool__NotInitialized();
    }

    // Get vault address
    address vaultAddress = _appStorage.s_vaults[_token];
    if (vaultAddress == address(0)) {
        revert ProtocolPool__NoVaultForToken();
    }

    // Get vault instance and user's vault token balance
    ILendbitTokenVault vault = ILendbitTokenVault(vaultAddress);
    uint256 userVaultTokens = IERC20(vaultAddress).balanceOf(_user);
    
    if (userVaultTokens == 0) {
        revert ProtocolPool__NoTokensToWithdraw();
    }

    // Calculate withdrawal amounts
    uint256 sharesToBurn;
    if (_amount == 0) {
        // Withdraw all vault tokens
        sharesToBurn = userVaultTokens;
        amountWithdrawn = Utils.convertToAmount(_appStorage.s_tokenData[_token], sharesToBurn);
    } else {
        // Withdraw specific amount
        sharesToBurn = Utils.convertToShares(_appStorage.s_tokenData[_token], _amount);
        if (userVaultTokens < sharesToBurn) {
            revert ProtocolPool__InsufficientVaultTokens();
        }
        amountWithdrawn = _amount;
    }

    // Get storage references
    TokenData storage tokenData = _appStorage.s_tokenData[_token];
    ProtocolPool storage protocolPool = _appStorage.s_protocolPool[_token];

    // Validate liquidity
    if (tokenData.poolLiquidity == 0) {
        revert ProtocolPool__NoLiquidity();
    }
    if (tokenData.poolLiquidity < amountWithdrawn) {
        revert ProtocolPool__NotEnoughLiquidity();
    }

    // Update borrow index before state changes
    LibInterestAccure.updateBorrowIndex(tokenData, protocolPool);

    // Burn vault tokens (ONLY source of truth for user balance)
    vault.burnFor(_user, sharesToBurn);

    // Update protocol state - ALL share tracking must be consistent
     _appStorage.s_addressToUserPoolShare[_user][_token] -= sharesToBurn;

    // Update protocol state
    protocolPool.totalSupply -= sharesToBurn;
    tokenData.totalSupply -= sharesToBurn;
    tokenData.poolLiquidity -= amountWithdrawn;
    tokenData.lastUpdateTimestamp = block.timestamp;

    // Handle cross-chain transfer
    _handleCrossChainTransfer(_appStorage, _token, amountWithdrawn, _user, _chainSelector);

    // Emit withdrawal event
    emit Withdraw(_user, _token, amountWithdrawn, sharesToBurn, _chainSelector);

}

/**
 * @dev Allows users to borrow tokens from the liquidity pool
 * @param _appStorage The app storage layout
 * @param _token The address of the token to borrow
 * @param _amount The amount of tokens to borrow
 * @param _user The address of the user borrowing
 * @param _chainSelector The chain selector for cross-chain operations
 */
function _borrowFromPool(
    LibAppStorage.Layout storage _appStorage,
    address _token,
    uint256 _amount,
    address _user,
    uint64 _chainSelector
) internal {
    // Validation checks
    if (!_appStorage.s_protocolPool[_token].initialize) {
        revert ProtocolPool__NotInitialized();
    }
    if (_amount == 0) revert ProtocolPool__ZeroAmount();
    if (!_appStorage.s_isLoanable[_token]) {
        revert ProtocolPool__TokenNotSupported();
    }

    // Get storage references
    ProtocolPool storage _protocolPool = _appStorage.s_protocolPool[_token];
    TokenData storage tokenData = _appStorage.s_tokenData[_token];

    // Liquidity validation
    if (_protocolPool.totalSupply == 0) revert ProtocolPool__NoLiquidity();
    if (_protocolPool.totalBorrows + _amount > _protocolPool.totalSupply) {
        revert ProtocolPool__NotEnoughLiquidity();
    }
    if (!_appStorage.s_protocolPool[_token].isActive) {
        revert ProtocolPool__IsNotActive();
    }
    if (tokenData.poolLiquidity < _amount) {
        revert ProtocolPool__NotEnoughLiquidity();
    }

    // Update borrow index to accrue interest before any calculations
    LibInterestAccure.updateBorrowIndex(tokenData, _protocolPool);

    // Verify user has sufficient collateral
    uint8 tokenDecimals = LibGettersImpl._getTokenDecimal(_token);
    uint256 loanUsdValue = LibGettersImpl._getUsdValue(_appStorage, _token, _amount, tokenDecimals);

    // Check health factor after potential borrow
    if (LibGettersImpl._healthFactor(_appStorage, _user, loanUsdValue) < 1e18) {
        revert ProtocolPool__InsufficientCollateral();
    }

    // Lock collateral
    LibLiquidityPool._lockCollateral(_appStorage, _user, _token, _amount);

    // Update user borrow data
    UserBorrowData storage userBorrowData = _appStorage.s_userBorrows[_user][_token];

    // If user has an existing borrow, update it with accrued interest first
    if (userBorrowData.isActive) {
        uint256 currentDebt =LibLiquidityPool._calculateUserDebt(tokenData, userBorrowData);
        userBorrowData.borrowedAmount = currentDebt + _amount;
    } else {
        userBorrowData.borrowedAmount = _amount;
        userBorrowData.isActive = true;
    }

    // Update the user's borrow index to current index
    userBorrowData.borrowIndex = tokenData.borrowIndex;
    userBorrowData.lastUpdateTimestamp = block.timestamp;

    // Update pool state
    tokenData.totalBorrows += _amount;
    tokenData.poolLiquidity -= _amount;
    tokenData.lastUpdateTimestamp = block.timestamp;

    // Handle cross-chain token transfer to user
    _handleCrossChainTransfer(_appStorage, _token, _amount, _user, _chainSelector);

    // Emit borrow event
    emit Borrow(_user, _token, _amount, _chainSelector);



}




/**
 * @dev Handle cross-chain token transfer
 * @param _appStorage The app storage layout
 * @param _token Token address
 * @param _amount Amount to transfer
 * @param _user Recipient address
 * @param _chainSelector Destination chain
 */
function _handleCrossChainTransfer(
    LibAppStorage.Layout storage _appStorage,
    address _token,
    uint256 _amount,
    address _user,
    uint64 _chainSelector
) internal {
    // Prepare tokens for cross-chain transfer
    Client.EVMTokenAmount[] memory tokensToSendDetails = new Client.EVMTokenAmount[](1);
    tokensToSendDetails[0] = Client.EVMTokenAmount({
        token: _token == Constants.NATIVE_TOKEN ? Constants.WETH : _token,
        amount: _amount
    });

    // Handle native token vs ERC20 tokens
    if (_token == Constants.NATIVE_TOKEN) {
        IWERC20(Constants.WETH).deposit{value: _amount}();
        IERC20(Constants.WETH).approve(Constants.CCIP_ROUTER, _amount);

    } else {
    // For ERC20 tokens, ensure approval is set
        IERC20(_token).approve(Constants.CCIP_ROUTER, _amount);
    }

    // Send tokens cross-chain
    bytes32 messageId = LibCCIP._sendTokenCrosschain(
        _appStorage.s_senderSupported[_chainSelector],
        _token == Constants.NATIVE_TOKEN,
        tokensToSendDetails,
        _chainSelector,
        _user
    );

    // Emit CCIP message sent event
    emit CCIPMessageSent(
        messageId,
        _chainSelector,
        abi.encode(_user),
        tokensToSendDetails
    );
}


}