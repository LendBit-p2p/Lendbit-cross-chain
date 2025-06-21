# Lendbit Protocol

> **Lend and borrow on any blockchain - one platform, multiple chains**

## What Makes Lendbit Different?

Lendbit lets you **borrow on one blockchain and repay on another**. Your loans and collateral are managed from a single hub, but you can interact with the protocol from any supported chain.

### The Big Idea
- **Borrow on Arbitrum** → **Repay on Optimism** ✅
- **Deposit collateral on Base** → **Get loan on Arbitrum** ✅  
- **One account, multiple chains** → **Maximum flexibility** ✅

## How Our Cross-Chain System Works

### Hub and Spoke Architecture

```
        Base Chain (Hub)
    ┌─────────────────────┐
    │   Main Contract     │
    │   - All loan data   │
    │   - User balances   │
    │   - Collateral      │
    └─────────┬───────────┘
              │
    ┌─────────┼───────────┐
    │         │           │
Arbitrum   Optimism   [More chains]
(Spoke)    (Spoke)    (Coming soon)
```

**Hub (Base Chain)**: Stores all your loan information and collateral  
**Spokes (Other Chains)**: Entry points where you can interact with your loans

## Contract Addresses

### Main Hub (Base Chain)
- **Diamond Contract**: `0x7286F2708f8f4d0a1a1b6c19f5D14AdB4c3207B2`
- **Protocol Logic**: `0x09C4De2818D8DAaBefA1aDb016134199f1418aaB`

### Spoke Contracts
- **Arbitrum Spoke**: `0x1C0fbFf22C5Ab94bA0B5d46403b8101855355262`
- **Optimism Spoke**: `0xe2923E98728e32f236380dDFfCf628c07339C818`

*Note: You can use any of these addresses to interact with your loans*

## Core Features

### 1. Cross-Chain Lending
**Borrow Anywhere, Repay Anywhere**
- Deposit collateral on Base
- Take loan on Arbitrum  
- Repay from Optimism
- All managed from one account

### 2. Peer-to-Peer Loans
**Full Control Over Your Lending Terms**
- **Lenders**: Create custom loan offers - set your own interest rates, duration, and requirements
- **Borrowers**: Create loan requests - specify how much you need and what rate you're willing to pay
- **Complete Flexibility**: Negotiate terms that work for both parties
- **No Middleman**: Direct agreements between users, you keep all profits

### 3. Multi-Token Collateral
**Use What You Have**
- ETH, DAI, USDC supported
- Mix different tokens as collateral
- Real-time value tracking
- Smart liquidation protection

### 4. Automated Safety
**Protection for Everyone**
- 24/7 loan monitoring
- Automatic liquidation when needed
- Off-chain bots ensure instant action
- Lenders always protected

## How Cross-Chain Works (Step by Step)

### Example: Borrow on Arbitrum, Repay on Optimism

1. **You on Arbitrum**: "I want to borrow $1000"
2. **Message Sent**: Arbitrum contract sends message to Base hub
3. **Hub Checks**: Base hub verifies you have enough collateral
4. **Loan Approved**: Hub approves loan and sends tokens to Arbitrum
5. **You Get Funds**: $1000 appears in your Arbitrum wallet
6. **Later... You on Optimism**: "I want to repay my loan"
7. **Repayment**: Send repayment from Optimism to Base hub
8. **Loan Closed**: Hub marks loan as repaid, releases collateral


## Loan Process

### For Borrowers

#### Step 1: Deposit Collateral (Any Chain)
```
Connect wallet → Choose chain → Deposit ETH/DAI/USDC
```
- Your collateral goes to the Base hub
- Available for borrowing from any chain

#### Step 2: Create Loan Request (Any Chain)
```
Amount: $1000
Your Offered Interest Rate: 5% APR (you set this!)
Duration: 30 days
Collateral: Already deposited
```
*You control the interest rate you're willing to pay*

#### Step 3: Wait for Lender
- Lenders see your request
- They can fund it from any chain
- You get notified when funded

#### Step 4: Receive Loan (Same or Different Chain)
- Funds appear in your wallet
- Loan officially starts
- Timer begins counting

#### Step 5: Repay (Any Chain You Want)
- Repay from Arbitrum, Optimism, or Base
- System automatically finds your loan
- Collateral released after repayment

### For Lenders

#### Step 1: Create Loan Offers (Any Chain)
- **Set Your Terms**: Choose interest rate, loan amount, duration
- **Your Rules**: Set minimum collateral requirements
- **Browse Requests**: Or fund existing borrower requests
- **Full Control**: You decide which loans to fund

#### Step 2: Earn Interest
- Interest calculated daily
- Automatic liquidation protects you
- Get repaid with profit

## Loan Terms & Safety

### Collateral Rules
- **Maximum Loan**: 80% of collateral value
- **Liquidation**: Happens when collateral drops below loan value
- **Grace Period**: Small buffer before liquidation

### Example Loan
```
Collateral: 1 ETH ($2,000)
Max Loan: $1,600 (80%)
Safe Zone: ETH above $2,000
Warning Zone: ETH between $1,600-$2,000  
Liquidation: ETH below $1,600
```

### Cross-Chain Fees
- **Bridge Fees**: Small fee for cross-chain messages
- **Gas Fees**: Normal transaction fees on each chain
- **Protocol Fees**: 0.5% on successful loans

## Supported Chains

| Chain | Status | Role | Best For |
|-------|--------|------|----------|
| **Base** | ✅ Live | Hub | Collateral storage
| **Arbitrum** | ✅ Live | Spoke | 
| **Optimism** | ✅ Live | Spoke | 


## Why Choose Lendbit?

### Traditional DeFi Problems
❌ Stuck on one expensive chain  
❌ Limited by chain-specific liquidity  
❌ High gas fees for simple operations  
❌ Complex user experience  

### Lendbit Solutions
✅ **Chain Freedom**: Borrow and repay anywhere  
✅ **Cost Efficiency**: Use cheapest chain for each action  
✅ **Unified Experience**: One account, all chains  
✅ **Better Rates**: Access liquidity from all chains  

## Getting Started

### Quick Start (5 Minutes)
1. **Connect Wallet**: MetaMask or any Web3 wallet
2. **Choose Chain**: Start on Arbitrum (cheapest) or Optimism (fastest)
3. **Deposit Collateral**: Send ETH, DAI, or USDC
4. **Create Request**: Set your loan terms
5. **Get Funded**: Wait for lenders to fund your request



## Real-World Use Cases

### Cross-Chain Arbitrage
1. Borrow USDC on cheap chain
2. Buy ETH where it's cheaper
3. Sell ETH where it's expensive
4. Repay loan on convenient chain
5. Keep the profit



### Emergency Liquidity
1. Need cash fast on Optimism
2. Have collateral sitting on Base
3. Get loan instantly on Optimism
4. Repay later from any chain

## Security & Risks

### What We're Building to Protect You
- **Cross-Chain Security**: Chainlink CCIP for safe messaging
- **Automated Monitoring**: 24/7 loan health tracking



## Support

### Need Help?
- **Discord**: [https://discord.gg/E9ChPVZxDC]
- **Documentation**: [Technical Guides]  
- **Email**: support@lendbit.com

### Report Issues
- **GitHub**: Report technical issues
- **Discord**: Community feedback and suggestions
- **Security**: security@lendbit.com

---

**Ready to try cross-chain lending?** Connect your wallet and experience the freedom of borrowing and repaying on any chain.
