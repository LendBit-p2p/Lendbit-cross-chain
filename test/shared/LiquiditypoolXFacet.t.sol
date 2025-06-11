// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../Base.t.sol";
import {console} from "forge-std/console.sol";
import {Client} from "@chainlink/contract-ccip/contracts/libraries/Client.sol";
import {CCIPMessageSent} from "../../contracts/spoke/libraries/Events.sol";
import {CollateralWithdrawn} from "../../contracts/model/Event.sol";

contract LiquidityPoolXFacetTest is Base {
    address user = address(0x6e37BC743C6496f0EE268C0ea6AdBf2634d979DD);

    function setUp() public override {
        owner = address(0x4a3aF8C69ceE81182A9E74b2392d4bDc616Bf7c7);

        deployXDiamonds();
    }

    function test_sharedxFacet() public {
        console.log("sharedxFacet");
        assert(true);
    }

  function test_xdepositInto_LiquidityPoolThroughABR() public {
    uint256 amount = 100 ether;

        _intializeProtocolPool(LINK_CONTRACT_ADDRESS);
        _deployVault(LINK_CONTRACT_ADDRESS, "USDT-VAULT", "VUSDT");

        
        xdepositIntoLiquidityPool(ARB_LINK_CONTRACT_ADDRESS, amount, arbFork, owner);


        uint256 userBalance = liquidityPoolFacet.getUserPoolDeposit(
            owner,
            LINK_CONTRACT_ADDRESS
        );

        assertEq(userBalance, amount);
        assertEq(
            ERC20Mock(LINK_CONTRACT_ADDRESS).balanceOf(address(liquidityPoolFacet)),
            amount
        );

        //TESTING THE VAULT WORKS 
        uint vaultAssets = liquidityPoolFacet.getVaultTotalAssets(LINK_CONTRACT_ADDRESS);
        assertEq(vaultAssets, amount);
    }


    function test_xdepositInto_LiquidityPoolThroughAVAX() public {

        _intializeProtocolPool(LINK_CONTRACT_ADDRESS);
        _deployVault(LINK_CONTRACT_ADDRESS, "USDT-VAULT", "VUSDT");

        uint256 amount = 100 ether;
        _dripLink(amount, owner, avaxFork);
         xdepositIntoLiquidityPool(AVAX_LINK_CONTRACT_ADDRESS, amount, avaxFork, owner);


        uint256 userBalance = liquidityPoolFacet.getUserPoolDeposit(
            owner,
            LINK_CONTRACT_ADDRESS
        );

        assertEq(userBalance, amount);
        assertEq(
            ERC20Mock(LINK_CONTRACT_ADDRESS).balanceOf(address(liquidityPoolFacet)),
            amount
        );

          //TESTING THE VAULT WORKS 
        uint vaultAssets = liquidityPoolFacet.getVaultTotalAssets(LINK_CONTRACT_ADDRESS);
        assertEq(vaultAssets, amount);

    }
function test_xdepositInto_LiquidityPoolThroughBoth() public {
    uint256 amount = 100 ether;
    
    // Initialize protocol pool and deploy vault
    _intializeProtocolPool(LINK_CONTRACT_ADDRESS);
    _deployVault(LINK_CONTRACT_ADDRESS, "USDT-VAULT", "VUSDT");
    
    // Drip LINK tokens to owner for AVAX fork
    _dripLink(amount, owner, avaxFork);
    
    // First deposit: AVAX LINK -> Base LINK (cross-chain)
    xdepositIntoLiquidityPool(AVAX_LINK_CONTRACT_ADDRESS, amount, avaxFork, owner);
    
    // Second deposit: ARB LINK -> Base LINK (cross-chain) 
    xdepositIntoLiquidityPool(ARB_LINK_CONTRACT_ADDRESS, amount, arbFork, owner);
    
    // Third deposit: Another AVAX LINK -> Base LINK (cross-chain)
    // Drip more tokens for second AVAX deposit
    _dripLink(amount, owner, avaxFork);
    xdepositIntoLiquidityPool(AVAX_LINK_CONTRACT_ADDRESS, amount, avaxFork, owner);
    
    // Verify total user balance (should be 3 * amount)
    uint256 userBalance = liquidityPoolFacet.getUserPoolDeposit(
        owner,
        LINK_CONTRACT_ADDRESS
    );
    
    assertEq(userBalance, amount * 3);
    assertEq(
        ERC20Mock(LINK_CONTRACT_ADDRESS).balanceOf(address(liquidityPoolFacet)),
        amount * 3
    );
    
    // Testing the vault works 
    uint vaultAssets = liquidityPoolFacet.getVaultTotalAssets(LINK_CONTRACT_ADDRESS);
    assertEq(vaultAssets, amount * 3);
}

function test_xWithdrawFrom_ARB_And_DepositOnAVAX() public {
    _intializeProtocolPool(LINK_CONTRACT_ADDRESS);
    _deployVault(LINK_CONTRACT_ADDRESS, "USDT-VAULT", "VUSDT");
    _dripLink(100 ether, owner, hubFork);
    
    uint256 amount = 100 ether;
    _dripLink(amount, owner, avaxFork);
    
    // Deposit on AVAX (mints vault tokens to owner on hub)
    xdepositIntoLiquidityPool(AVAX_LINK_CONTRACT_ADDRESS, amount, avaxFork, owner);

    // Verify vault tokens exist BEFORE withdrawal
    vm.selectFork(hubFork);
    uint256 vaultBalance = liquidityPoolFacet.getVaultTotalAssets(LINK_CONTRACT_ADDRESS);
    require(vaultBalance > 0, "No vault tokens to withdraw");

    vm.prank(owner);
    _xWithdrawnFromPool(
        ARB_LINK_CONTRACT_ADDRESS,
        amount,
        arbFork,
        owner
    );

    // Verify withdrawal
    vm.selectFork(hubFork);
    uint256 finalBalance = liquidityPoolFacet.getUserPoolDeposit(owner, LINK_CONTRACT_ADDRESS);
    assertEq(finalBalance, 0, "Withdrawal failed");
}

/**
 * Test Case 1: Partial Withdrawal - Deposit on ARB, Partially Withdraw on AVAX
 */
function test_xPartialWithdrawFrom_ARB_DepositOnAVAX() public {
    _intializeProtocolPool(LINK_CONTRACT_ADDRESS);
    _deployVault(LINK_CONTRACT_ADDRESS, "USDT-VAULT", "VUSDT");
    
    uint256 depositAmount = 100 ether;
    uint256 withdrawAmount = 30 ether; // Partial withdrawal
    
    // Deposit on ARB (mints vault tokens to owner on hub)
    xdepositIntoLiquidityPool(ARB_LINK_CONTRACT_ADDRESS, depositAmount, arbFork, owner);
    
    // Verify deposit was successful
    vm.selectFork(hubFork);
    uint256 initialBalance = liquidityPoolFacet.getUserPoolDeposit(owner, LINK_CONTRACT_ADDRESS);
    assertEq(initialBalance, depositAmount);
    
    // Verify vault tokens exist BEFORE withdrawal
    uint256 vaultBalance = liquidityPoolFacet.getVaultTotalAssets(LINK_CONTRACT_ADDRESS);
    require(vaultBalance >= withdrawAmount);
    
    // Perform partial withdrawal to AVAX
    vm.prank(owner);
    _xWithdrawnFromPool(
        AVAX_LINK_CONTRACT_ADDRESS,
        withdrawAmount,
        avaxFork,
        owner
    );
    
    // Verify partial withdrawal - remaining balance should be depositAmount - withdrawAmount
    vm.selectFork(hubFork);
    uint256 finalBalance = liquidityPoolFacet.getUserPoolDeposit(owner, LINK_CONTRACT_ADDRESS);
    uint256 expectedBalance = depositAmount - withdrawAmount;
    assertEq(finalBalance, expectedBalance);
    
    // Verify vault assets are correctly updated
    uint256 finalVaultAssets = liquidityPoolFacet.getVaultTotalAssets(LINK_CONTRACT_ADDRESS);
    assertEq(finalVaultAssets, expectedBalance);
}


function test_xCrossChainRoundTrip() public {
    _intializeProtocolPool(LINK_CONTRACT_ADDRESS);
    _deployVault(LINK_CONTRACT_ADDRESS, "USDT-VAULT", "VUSDT");
    
    uint256 amount = 80 ether;
    
    // === ROUND 1: ARB -> AVAX ===
    
    // Deposit on ARB
    xdepositIntoLiquidityPool(ARB_LINK_CONTRACT_ADDRESS, amount, arbFork, owner);
    
    // Verify deposit
    vm.selectFork(hubFork);
    uint256 balanceAfterDeposit1 = liquidityPoolFacet.getUserPoolDeposit(owner, LINK_CONTRACT_ADDRESS);
    assertEq(balanceAfterDeposit1, amount);
    
    // Withdraw to AVAX
    vm.prank(owner);
    _xWithdrawnFromPool(
        AVAX_LINK_CONTRACT_ADDRESS,
        amount,
        avaxFork,
        owner
    );
    
    // Verify withdrawal
    vm.selectFork(hubFork);
    uint256 balanceAfterWithdraw1 = liquidityPoolFacet.getUserPoolDeposit(owner, LINK_CONTRACT_ADDRESS);
    assertEq(balanceAfterWithdraw1, 0);
    
    // === ROUND 2: AVAX -> ARB ===
    
    // Deposit on AVAX (need to drip tokens first since they were "withdrawn" cross-chain)
    _dripLink(amount, owner, avaxFork);
    xdepositIntoLiquidityPool(AVAX_LINK_CONTRACT_ADDRESS, amount, avaxFork, owner);
    
    // Verify second deposit
    vm.selectFork(hubFork);
    uint256 balanceAfterDeposit2 = liquidityPoolFacet.getUserPoolDeposit(owner, LINK_CONTRACT_ADDRESS);
    assertEq(balanceAfterDeposit2, amount);
    
    // Withdraw to ARB
    vm.prank(owner);
    _xWithdrawnFromPool(
        ARB_LINK_CONTRACT_ADDRESS,
        amount,
        arbFork,
        owner
    );
    
    // Verify final withdrawal
    vm.selectFork(hubFork);
    uint256 finalBalance = liquidityPoolFacet.getUserPoolDeposit(owner, LINK_CONTRACT_ADDRESS);
    assertEq(finalBalance, 0);
    
    // Verify vault is empty after round trip
    uint256 finalVaultAssets = liquidityPoolFacet.getVaultTotalAssets(LINK_CONTRACT_ADDRESS);
    assertEq(finalVaultAssets, 0);
}

//todo still failing dont know tho..
function test_xtestBorrowFromLiquidityPool() public {
    // Initialize protocol pool and deploy vault
    _intializeProtocolPool(LINK_CONTRACT_ADDRESS);
    _deployVault(LINK_CONTRACT_ADDRESS, "LINK-VAULT", "VLINK");

    uint256 liquidityAmount = 100 ether;
    uint256 collateralAmount = 400 ether;
    uint256 borrowAmount = 50 ether;

    // === STEP 1: Provide liquidity to the pool ===
    // Owner deposits LINK liquidity on AVAX
    _dripLink(liquidityAmount, owner, avaxFork);
    xdepositIntoLiquidityPool(AVAX_LINK_CONTRACT_ADDRESS, liquidityAmount, avaxFork, owner);

   
   //hub check
    uint256 poolLiquidity = liquidityPoolFacet.getUserPoolDeposit(owner, LINK_CONTRACT_ADDRESS);
    assertEq(poolLiquidity, liquidityAmount);

    // === STEP 2: User deposits collateral ===
    // User deposits LINK collateral on AVAX
   
    
        vm.startPrank(user);
        //deposit collateral through avax fork
        ERC20Mock(AVAX_LINK_CONTRACT_ADDRESS).mint(user, 1000e18);
    _xDepositCollateral(
        AVAX_LINK_CONTRACT_ADDRESS,
        collateralAmount,
        avaxFork,
        user
    );
    vm.stopPrank();

   
    uint256 userCollateral = gettersFacet.getAddressToCollateralDeposited(
        user,
        LINK_CONTRACT_ADDRESS
    );
    assertEq(userCollateral, collateralAmount);

    // === STEP 3: User borrows from pool ===
    // User borrows LINK tokens to ARB chain
    vm.startPrank(user);
    _xborrowFromPool(
        ARB_USDT_CONTRACT_ADDRESS,
        borrowAmount,
        arbFork,
        user
    );
    vm.stopPrank();

    // === STEP 4: Verify borrow was successful ===
    vm.selectFork(hubFork);
    (uint256 borrowedAmount,,, bool isActive) = liquidityPoolFacet.getUserBorrowData(user, USDT_CONTRACT_ADDRESS);

    assertEq(borrowedAmount, borrowAmount);
    assertTrue(isActive);
}


}






