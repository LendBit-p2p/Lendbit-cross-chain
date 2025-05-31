// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

event RequestCreated(address indexed _borrower, uint96 indexed requestId, uint256 _amount, uint16 _interest);

event OrderCreated(address indexed _lender, address indexed_tokenAddress, uint256 _amount, uint96 indexed _requestId);

event RespondToLendingOffer(address indexed sender, uint256 indexed _offerId, uint8 _status, uint8 _offerStatus);

event RequestServiced(uint96 indexed _requestId, address indexed _lender, address indexed _borrower, uint256 _amount);

event RequestClosed(uint96 indexed _requestId, address indexed _borrower);

event CollateralWithdrawn(address indexed sender, address indexed _tokenCollateralAddress, uint256 _amount);

event UpdatedCollateralTokens(address indexed sender, uint8 newTokensCount);

event AcceptedListedAds(address indexed sender, uint96 indexed id, uint256 indexed amount, uint8 adStatus);

event LoanRepayment(address indexed sender, uint96 id, uint256 amount);

event UpdateLoanableToken(address indexed _token, address _priceFeed, address indexed sender);

event CollateralDeposited(address indexed _sender, address indexed _token, uint256 _value);

event withdrawnAdsToken(address indexed sender, uint96 indexed _orderId, uint8 indexed orderStatus, uint256 _amount);

event LoanListingCreated(
    uint96 indexed listingId, address indexed sender, address indexed tokenAddress, uint256 amount
);

event RequestLiquidated(uint96 indexed requestId, address indexed lenderAddress, uint256 indexed totalRepayment);

event FeesWithdrawn(address indexed to, address indexed token, uint256 amount);

event RequestLiquidated(
    uint96 indexed requestId,
    address indexed sender,
    address indexed borrower,
    address lender,
    uint256 totalCollateralValue
);

event ProtocolFeeRecipientSet(address indexed _feeRecipient);

/**
 * @notice Emitted when a protocol pool is initialized
 * @param token The address of the token used for the pool
 * @param reserveFactor The reserve factor set for the pool
 */
event ProtocolPoolInitialized(address indexed token, uint256 reserveFactor);

/**
 * @notice Emitted when a user deposits into a liquidity pool
 * @param user The address of the user making the deposit
 * @param token The address of the token deposited
 * @param amount The amount of tokens deposited
 * @param sharesMinted The amount of LP shares minted to the user
 */
event Deposit(address indexed user, address indexed token, uint256 amount, uint256 sharesMinted);

/**
 * @notice Emitted when a user withdraws from a liquidity pool
 * @param user The address of the user making the withdrawal
 * @param token The address of the token withdrawn
 * @param amount The amount of tokens withdrawn
 * @param sharesBurned The amount of LP shares burned
 */
event Withdraw(address indexed user, address indexed token, uint256 amount, uint256 sharesBurned);

/**
 * @notice Emitted when interest is accrued in a pool
 * @param token The address of the token for which interest was accrued
 * @param interestAccrued The amount of interest accrued
 */
event InterestAccrued(address indexed token, uint256 interestAccrued);

event Borrow(address indexed sender, address indexed token, uint256 indexed amount);

event Repay(address indexed sender, address indexed token, uint256 indexed amountRepaid);
// event Withdraw(address indexed sender,address indexed token,uint256 amountWithdrawn,uint256 shares);
