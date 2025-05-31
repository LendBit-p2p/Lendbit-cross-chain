// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.9;

/**
 * @dev Struct to store information about a user in the system.
 * @param userAddr The address of the user.
 * @param gitCoinPoint Points earned by the user in GitCoin or similar systems.
 * @param totalLoanCollected Total amount of loan the user has collected from the platform.
 */
struct User {
    address userAddr;
    uint8 gitCoinPoint;
    uint256 totalLoanCollected;
    uint256 totalLiquidationAmount;
}

/**
 * @title User Borrow Data
 * @notice Structure to track individual user borrowing information
 */
struct UserBorrowData {
    uint256 borrowedAmount; // Original amount borrowed
    uint256 borrowIndex; // Index at time of borrowing (normalized)
    uint256 lastUpdateTimestamp; // Last time user data was updated
    bool isActive; // Whether the borrow is active
}

struct TokenData {
    uint256 totalSupply;
    uint256 poolLiquidity;
    uint256 totalBorrows;
    uint256 lastUpdateTimestamp;
    uint256 borrowIndex;
    uint256 totalReserves;
}

/**
 * @dev Struct to store information about a loan request.
 * @param requestId Unique identifier for the loan request.
 * @param author Address of the user who created the request.
 * @param amount Amount of tokens the user is requesting to borrow.
 * @param interest Interest rate set by the borrower for this loan request.
 * @param totalRepayment Total repayment amount calculated as (amount + interest).
 * @param returnDate The timestamp when the loan is due for repayment.
 * @param lender Address of the lender who accepted the request (if any).
 * @param loanRequestAddr The unique address associated with this specific loan request.
 * @param collateralTokens Array of token addresses offered as collateral for the loan.
 * @param status The current status of the loan request, represented by the `Status` enum.
 */
struct Request {
    uint96 requestId;
    address author;
    uint256 amount;
    uint16 interest;
    uint256 totalRepayment;
    uint256 returnDate;
    address lender;
    address loanRequestAddr;
    address[] collateralTokens;
    Status status;
}

/**
 * @dev Struct to store information about a loan listing created by a lender.
 * @param listingId Unique identifier for the loan listing.
 * @param author Address of the lender creating the listing.
 * @param tokenAddress The address of the token being lent.
 * @param amount Total amount the lender is willing to lend.
 * @param min_amount Minimum amount the lender is willing to lend in a single transaction.
 * @param max_amount Maximum amount the lender is willing to lend in a single transaction.
 * @param returnDate The due date for loan repayment specified by the lender.
 * @param interest Interest rate offered by the lender.
 * @param listingStatus The current status of the loan listing, represented by the `ListingStatus` enum.
 */
struct LoanListing {
    uint96 listingId;
    address author;
    address tokenAddress;
    address[] whitelist;
    uint256 amount;
    uint256 min_amount;
    uint256 max_amount;
    uint256 returnDate;
    uint16 interest;
    ListingStatus listingStatus;
}

struct ProtocolPool {
    address token;
    bool initialize;
    uint256 totalSupply;
    uint256 totalBorrows;
    uint256 reserveFactor;
    uint256 optimalUtilization;
    uint256 baseRate;
    uint256 slopeRate;
    bool isActive;
}

/**
 * @dev Enum representing the status of a loan request.
 * OPEN - The loan request is open and waiting for a lender.
 * SERVICED - The loan request has been accepted and is currently serviced by a lender.
 * CLOSED - The loan request has been closed (either fully repaid or canceled).
 */
enum Status {
    OPEN,
    SERVICED,
    CLOSED,
    LIQUIDATED
}

/**
 * @dev Enum representing the status of a loan listing.
 * OPEN - The loan listing is available and open to borrowers.
 * CLOSED - The loan listing is closed and no longer available.
 */
enum ListingStatus {
    OPEN,
    CLOSED
}
