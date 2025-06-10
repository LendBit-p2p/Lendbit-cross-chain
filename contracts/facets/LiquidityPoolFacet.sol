// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../libraries/LibLiquidityPool.sol";
import "../libraries/LibAppStorage.sol";
import "../utils/functions/AppStorage.sol";
import "../utils/constants/Constant.sol";
import {LibGettersImpl} from "../libraries/LibGetters.sol";
import {LibInterestAccure} from "../libraries/LibInterestAccure.sol";
import {LibInterestRateModel} from "../libraries/LibInterestRateModel.sol";
import {LibRateCalculations} from "../libraries/LibRateCalculation.sol";
import {Utils} from "../utils/functions/Utils.sol";
import {ProtocolPool, TokenData, UserBorrowData} from "../model/Protocol.sol";
import {LibGettersImpl} from "../libraries/LibGetters.sol";
import {LibVaultNotifications} from "../libraries/LibVaultNotifications.sol";

// import {VTokenVault} from "../vaults/VTokenVault.sol";

/**
* @title LiquidityPoolFacet
* @notice This facet provides functions for interacting with liquidity pools.
* @dev All state-changing operations are delegated to LibLiquidityPool
*/
contract LiquidityPoolFacet is AppStorage {
using LibLiquidityPool for LibAppStorage.Layout;
using LibVaultNotifications for LibAppStorage.Layout;

/**
* @notice Allows users to deposit tokens into the liquidity pool
* @dev Handles both native token (ETH) and ERC20 deposits
* @param token The address of the token to deposit
* @param amount The amount of tokens to deposit
* @return shares The number of LP shares minted for the deposit
* Requirements:
* - Pool must be initialized and active
* - Token must be supported for lending
* - Amount must be greater than zero
*
* Emits a `Deposit` event on successful deposit.
*/
function deposit(address token, uint256 amount) external payable returns (uint256 shares) {
return _appStorage._deposit(token, amount, msg.sender, Constants.CHAIN_SELECTOR);
}

/**
* @notice Allows users to borrow tokens from the liquidity pool
* @param token The address of the token to borrow
* @param amount The amount of tokens to borrow
*
* Requirements:
* - Pool must be initialized and active
* - Token must be supported for lending
* - Amount must be greater than zero
* - User must have sufficient collateral
* - Pool must have sufficient liquidity
*
* Emits a `Borrow` event on successful borrow.
*/
function borrowFromPool(address token, uint256 amount) external {
_appStorage._borrowFromPool(token, amount, msg.sender, Constants.CHAIN_SELECTOR);
}

/**
* @notice Allows users to repay their borrowed tokens
* @param token The address of the token to repay
* @param amount The amount to repay, use type(uint256).max to repay full debt
* @return amountRepaid The actual amount repaid
*
* Requirements:
* - Pool must be initialized
* - Token must be supported for lending
* - Amount must be greater than zero
* - User must have an active borrow
*
* Emits a `Repay` event on successful repayment.
*/
function repay(address token, uint256 amount) external payable returns (uint256 amountRepaid) {
return _appStorage._repay(token, amount, msg.sender, Constants.CHAIN_SELECTOR);
}

/**
* @notice Allows users to withdraw tokens from the liquidity pool
* @param token The address of the token to withdraw
* @param amount The amount of token to withdraw and burn corresponding shares
* @return amountWithdrawn The actual amount of tokens withdrawn
*
* Requirements:
* - Pool must be initialized
* - Token must be supported for lending
* - Amount must be greater than zero
* - User must have sufficient shares
* - Pool must have sufficient liquidity
*
* Emits a `Withdraw` event on successful withdrawal.
*/
function withdraw(address token, uint256 amount, bool isVault) external returns (uint256 amountWithdrawn) {
return _appStorage._withdraw(token, amount, msg.sender, isVault, Constants.CHAIN_SELECTOR);
}

/////////////////////////
/////READ ONLY FUNCTION///
/////////////////////////

/**
* @notice Gets the borrow data for a specific user and token
* @param _user The address of the user
* @param _token The address of the tok en
* @return borrowedAmount The amount borrowed by the user
* @return borrowIndex The borrow index for the user
* @return lastUpdateTimestamp The last update timestamp for the user's borrow data
* @return isActive Whether the user's borrow is active
*/
function getUserBorrowData(address _user, address _token)
external
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
function getProtocolPoolConfig(address _token)
external
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
function getUserPoolDeposit(address user, address token) external view returns (uint256) {
return maxRedeemable(user, token);
}

/**
* @notice gets token data for a specific token
* @param token The address of the token
* @return totalSupply The total supply of the token
* @return poolLiquidity The total liquidity in the pool for the token
* @return totalBorrows The total amount borrowed from the pool for the token
* @return lastUpdateTimestamp The last time the token data was updated
*/
function getPoolTokenData(address token)
external
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
function getUserDebt(address user, address token) external view returns (uint256 debt) {
UserBorrowData memory userBorrowData = _appStorage.s_userBorrows[user][token];
TokenData memory tokenData = _appStorage.s_tokenData[token];
ProtocolPool memory protocolPool = _appStorage.s_protocolPool[token];

debt = LibGettersImpl.calculateUserDebt(userBorrowData, tokenData, protocolPool);
}

/**
* @notice Calculates the APY for a given APR and compounding periods
* @param apr The APR in basis points
* @param compoundingPeriods The number of compounding periods per year
* @return _apy The APY in basis points
*/
function calculatePoolAPY(uint256 apr, uint256 compoundingPeriods) external pure returns (uint256 _apy) {
_apy = LibRateCalculations.calculateAPY(apr, compoundingPeriods);
}

/**
* @notice Calculates the APR for a given pool based on its parameters
* @param baseRate The base interest rate in basis points
* @param slopeRate The slope of the interest rate curve in basis points
* @param optimalUtilization The optimal utilization rate in basis points
* @param totalBorrows Total borrowed amount
* @param poolLiquidity Total available liquidity
* @return _apr Annual Percentage Rate in basis points
*/
function calculatePoolAPR(
uint256 baseRate,
uint256 slopeRate,
uint256 optimalUtilization,
uint256 totalBorrows,
uint256 poolLiquidity
) external pure returns (uint256 _apr) {
_apr = LibRateCalculations.calculateAPR(baseRate, slopeRate, optimalUtilization, totalBorrows, poolLiquidity);
}

/**
* @notice Retrieves both APR and APY for frontend consumption using direct values
* @param baseRate The base interest rate in basis points
* @param slopeRate The slope of the interest rate curve in basis points
* @param optimalUtilization The optimal utilization rate in basis points
* @param totalBorrows Total borrowed amount
* @param poolLiquidity Total available liquidity
* @return apr Annual Percentage Rate in basis points
* @return apy Annual Percentage Yield in basis points
*/
function getRatesFromPool(
uint256 baseRate,
uint256 slopeRate,
uint256 optimalUtilization,
uint256 totalBorrows,
uint256 poolLiquidity
) external pure returns (uint256 apr, uint256 apy) {
apr = LibRateCalculations.calculateAPR(baseRate, slopeRate, optimalUtilization, totalBorrows, poolLiquidity);

apy = LibRateCalculations.calculateAPY(apr, Constants.DEFAULT_COMPOUNDING_PERIODS);

return (apr, apy);
}

/////////////////////////
/////INTERNAL FUNCTION///
/////////////////////////

/**
* @notice Calculates the maximum redeemable amount for a user based on their shares
* @param user The address of the user
* @param token The address of the token
* @return maxRedeemableAmount The maximum redeemable amount for the user
*/
function maxRedeemable(address user, address token) internal view returns (uint256) {
// Check if the user has any shares in the pool
uint256 _shares = _appStorage.s_addressToUserPoolShare[user][token];
if (_shares == 0) return 0;

TokenData memory _token = _appStorage.s_tokenData[token];
// Calculate the maximum redeemable amount based on shares and pool liquidity
uint256 _maxRedeemableAmount = Utils.convertToAmount(_token, _shares);

return _maxRedeemableAmount;
}

////////////////////
///VAULT ////////////
///////////////////

function deployProtocolAssetVault(address token, string memory name, string memory symbol)
external
returns (address)
{
return _appStorage._deployVault(token, name, symbol, Constants.CHAIN_SELECTOR);
}

/**
* @notice External function called by vaults when deposits occur
* @param asset Token deposited
* @param amount Amount deposited
* @param depositor Address of the depositor
* @param transferAssets Whether to transfer assets
* @return shares Number of shares minted
*/
function notifyVaultDeposit(address asset, uint256 amount, address depositor, bool transferAssets)
external
returns (uint256 shares)
{
return _appStorage.notifyVaultDeposit(asset, amount, depositor, transferAssets);
}

/**
* @notice External function called by vaults when withdrawals occur
* @param asset Token withdrawn
* @param shares Shares being burned
* @param receiver Address receiving tokens
* @param transferAssets Whether to transfer assets
* @return amount Actual amount withdrawn
*/
function notifyVaultWithdrawal(address asset, uint256 shares, address receiver, bool transferAssets)
external
returns (uint256 amount)
{
return _appStorage.notifyVaultWithdrawal(asset, shares, receiver, transferAssets);
}

/**
* @notice External function called by vaults when transfers occur
* @param asset Token being transferred
* @param shares Amount of shares transferred
* @param sender Address sending shares
* @param receiver Address receiving shares
* @return success Whether transfer was successful
*/
function notifyVaultTransfer(address asset, uint256 shares, address sender, address receiver)
external
returns (bool success)
{
return _appStorage.notifyVaultTransfer(asset, shares, sender, receiver);
}

/**
* @notice Get vault's total assets
* @param asset Token address
* @return totalAssets Total assets in the vault
*/
function getVaultTotalAssets(address asset) external view returns (uint256 totalAssets) {
return _appStorage.getVaultTotalAssets(asset);
}

/**
* @notice Get vault's current exchange rate
* @param asset Token address
* @return exchangeRate Current exchange rate
*/
function getVaultExchangeRate(address asset) external view returns (uint256 exchangeRate) {
return _appStorage.getVaultExchangeRate(asset);
}

/**
* @notice Admin function to sync vault exchange rate
* @param asset Token address
*/
function syncVaultExchangeRate(address asset) external {
_appStorage.updateVaultExchangeRate(asset);
}

/**
* @notice Get vault info for a specific token
* @param token The token address
* @return exists Whether vault exists
* @return vaultAddress The vault address
* @return totalDeposits Total deposits in the vault
*/
function getVaultInfo(address token) external view returns (bool, address, uint256) {
return LibGettersImpl._getVaultInfo(_appStorage, token);
}

/**
* @notice Get user's vault token balance
* @param user The user address
* @param token The underlying token address
* @return balance User's vault token balance
*/
function getUserVaultBalance(address user, address token) external view returns (uint256 balance) {
balance = LibGettersImpl._getUserVaultBalance(_appStorage, user, token);
}
}
