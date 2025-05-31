// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

///////////////
/// errors ///
/////////////
error Governance__NotEnoughTokenBalance();
error Governance__NotEnoughAllowance();
error Governance__ProposalDoesNotExist();
error Governance__ProposalInactive();
error Governance__ProposalExpired();
error Governance__NotEnoughVotingPower();
error Governance__AlreadyVoted();
error Governance__AlreadyStaked();
error Governance__NoStakedToken();
error Governance__OptionDoesNotExist();

error Protocol__MustBeMoreThanZero();
error Protocol__tokensAndPriceFeedsArrayMustBeSameLength();
error Protocol__TokenNotAllowed();
error Protocol__TransferFailed();
error Protocol__BreaksHealthFactor();
error Protocol__InsufficientCollateral();
error Protocol__RequestNotOpen();
error Protocol__InsufficientBalance();
error Protocol__IdNotExist();
error Protocol__InvalidId();
error Protocol__Unauthorized();
error Protocol__OrderNotOpen();
error Protocol__InvalidToken();
error Protocol__InsufficientAllowance();
error Protocol__RequestNotServiced();
error Protocol__TokenNotLoanable();
error Protocol__DateMustBeInFuture();
error Protocol__CantFundSelf();
error Protocol__RequestExpired();
error Protocol__EmailNotVerified();
error Protocol__InsufficientCollateralDeposited();
error Protocol__RepayAmountExceedsDebt();
error Protocol__LoanNotServiced();
error Protocol__InvalidAmount();
error Protocol__NotOwner();
error Protocol__OwnerCreatedOrder();
error Protocol__OrderNotServiced();
error Protocol__ListingNotOpen();
error Protocol__OwnerCreatedListing();
error Protocol__InsufficientAmount();
error Protocol__OnlyBotCanAccess();

error Protocol__OwnerCantLiquidateRequest();
error Protocol__NotLiquidatable();
error Protocol__HealthFactorNotBroken();
error Protocol__InsufficientETH();
error Protocol__RefundFailed();
error Protocol__ETHTransferFailed();
error Protocol__ETHFeeTransferFailed();
error Protocol__NotWhitelisted();

// Custom errors
// /// @notice Thrown when trying to interact with a protocol pool that is not active
// error ProtocolPool__IsNotActive();
/// @notice Thrown when trying to initialize an already initialized protocol pool
error ProtocolPool__AlreadyInitialized();
/// @notice Thrown when trying to use a token that is not supported by the protocol
error ProtocolPool__TokenNotSupported();
/// @notice Thrown when attempting an operation with zero amount
error ProtocolPool__ZeroAmount();
/// @notice Thrown when trying to use a protocol pool that has not been initialized
error ProtocolPool__NotInitialized();
/// @notice Thrown when a user tries to withdraw more than their balance
error ProtocolPool__InsufficientBalance();
/// @notice Thrown when a withdrawal is not possible due to insufficient liquidity
error ProtocolPool__InsufficientLiquidity();

/// protocolpool errors
error ProtocolPool__NoLiquidity();
error ProtocolPool__NotEnoughLiquidity();
error ProtocolPool__IsNotActive();
error ProtocolPool__InsufficientCollateral();
error ProtocolPool__NoBorrow();
error ProtocolPool__InsufficientShares();


  // Error definitions
    error Protocol__AprTooHigh();
    error Protocol__InvalidCompoundingPeriods();
    error Protocol__ZeroLiquidity();
    error Protocol__InvalidBorrows();