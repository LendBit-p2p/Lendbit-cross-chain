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

        B = mkaddr("B address");

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

        uint256 userBalance = gettersFacet.getUserPoolDeposit(owner, LINK_CONTRACT_ADDRESS);

        assertEq(userBalance, amount);
        assertEq(ERC20Mock(LINK_CONTRACT_ADDRESS).balanceOf(address(liquidityPoolFacet)), amount);

        //TESTING THE VAULT WORKS
        uint256 vaultAssets = gettersFacet.getVaultTotalAssets(LINK_CONTRACT_ADDRESS);
        assertEq(vaultAssets, amount);
    }

    function test_xdepositInto_LiquidityPoolThroughAVAX() public {
        _intializeProtocolPool(LINK_CONTRACT_ADDRESS);
        _deployVault(LINK_CONTRACT_ADDRESS, "USDT-VAULT", "VUSDT");

        uint256 amount = 100 ether;
        _dripLink(amount, owner, avaxFork);
        xdepositIntoLiquidityPool(AVAX_LINK_CONTRACT_ADDRESS, amount, avaxFork, owner);

        uint256 userBalance = gettersFacet.getUserPoolDeposit(owner, LINK_CONTRACT_ADDRESS);

        assertEq(userBalance, amount);
        assertEq(ERC20Mock(LINK_CONTRACT_ADDRESS).balanceOf(address(liquidityPoolFacet)), amount);

        //TESTING THE VAULT WORKS
        uint256 vaultAssets = gettersFacet.getVaultTotalAssets(LINK_CONTRACT_ADDRESS);
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
        uint256 userBalance = gettersFacet.getUserPoolDeposit(owner, LINK_CONTRACT_ADDRESS);

        assertEq(userBalance, amount * 3);
        assertEq(ERC20Mock(LINK_CONTRACT_ADDRESS).balanceOf(address(liquidityPoolFacet)), amount * 3);

        // Testing the vault works
        uint256 vaultAssets = gettersFacet.getVaultTotalAssets(LINK_CONTRACT_ADDRESS);
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
        uint256 vaultBalance = gettersFacet.getVaultTotalAssets(LINK_CONTRACT_ADDRESS);
        require(vaultBalance > 0, "No vault tokens to withdraw");

        vm.prank(owner);
        _xWithdrawnFromPool(ARB_LINK_CONTRACT_ADDRESS, amount, arbFork, owner);

        // Verify withdrawal
        vm.selectFork(hubFork);
        uint256 finalBalance = gettersFacet.getUserPoolDeposit(owner, LINK_CONTRACT_ADDRESS);
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
        uint256 initialBalance = gettersFacet.getUserPoolDeposit(owner, LINK_CONTRACT_ADDRESS);
        assertEq(initialBalance, depositAmount);

        // Verify vault tokens exist BEFORE withdrawal
        uint256 vaultBalance = gettersFacet.getVaultTotalAssets(LINK_CONTRACT_ADDRESS);
        require(vaultBalance >= withdrawAmount);

        // Perform partial withdrawal to AVAX
        vm.prank(owner);
        _xWithdrawnFromPool(AVAX_LINK_CONTRACT_ADDRESS, withdrawAmount, avaxFork, owner);

        // Verify partial withdrawal - remaining balance should be depositAmount - withdrawAmount
        vm.selectFork(hubFork);
        uint256 finalBalance = gettersFacet.getUserPoolDeposit(owner, LINK_CONTRACT_ADDRESS);
        uint256 expectedBalance = depositAmount - withdrawAmount;
        assertEq(finalBalance, expectedBalance);

        // Verify vault assets are correctly updated
        uint256 finalVaultAssets = gettersFacet.getVaultTotalAssets(LINK_CONTRACT_ADDRESS);
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
        uint256 balanceAfterDeposit1 = gettersFacet.getUserPoolDeposit(owner, LINK_CONTRACT_ADDRESS);
        assertEq(balanceAfterDeposit1, amount);

        // Withdraw to AVAX
        vm.prank(owner);
        _xWithdrawnFromPool(AVAX_LINK_CONTRACT_ADDRESS, amount, avaxFork, owner);

        // Verify withdrawal
        vm.selectFork(hubFork);
        uint256 balanceAfterWithdraw1 = gettersFacet.getUserPoolDeposit(owner, LINK_CONTRACT_ADDRESS);
        assertEq(balanceAfterWithdraw1, 0);

        // === ROUND 2: AVAX -> ARB ===

        // Deposit on AVAX (need to drip tokens first since they were "withdrawn" cross-chain)
        _dripLink(amount, owner, avaxFork);
        xdepositIntoLiquidityPool(AVAX_LINK_CONTRACT_ADDRESS, amount, avaxFork, owner);

        // Verify second deposit
        vm.selectFork(hubFork);
        uint256 balanceAfterDeposit2 = gettersFacet.getUserPoolDeposit(owner, LINK_CONTRACT_ADDRESS);
        assertEq(balanceAfterDeposit2, amount);

        // Withdraw to ARB
        vm.prank(owner);
        _xWithdrawnFromPool(ARB_LINK_CONTRACT_ADDRESS, amount, arbFork, owner);

        // Verify final withdrawal
        vm.selectFork(hubFork);
        uint256 finalBalance = gettersFacet.getUserPoolDeposit(owner, LINK_CONTRACT_ADDRESS);
        assertEq(finalBalance, 0);

        // Verify vault is empty after round trip
        uint256 finalVaultAssets = gettersFacet.getVaultTotalAssets(LINK_CONTRACT_ADDRESS);
        assertEq(finalVaultAssets, 0);
    }

    function test_xtestBorrowFromLiquidityPool() public {
        uint256 amount = 100 ether;
        _dripLink(amount, owner, hubFork);
        _intializeProtocolPool(LINK_CONTRACT_ADDRESS);
        _deployVault(LINK_CONTRACT_ADDRESS, "USDT-VAULT", "VUSDT");

        uint256 depositAmount = 100 ether;
        uint256 borrowAmount = 30 ether; // Partial withdrawal

        // Deposit on ARB (mints vault tokens to owner on hub)
        xdepositIntoLiquidityPool(ARB_LINK_CONTRACT_ADDRESS, depositAmount, arbFork, owner);

        // Verify deposit was successful
        vm.selectFork(hubFork);
        uint256 initialBalance = gettersFacet.getUserPoolDeposit(owner, LINK_CONTRACT_ADDRESS);
        assertEq(initialBalance, depositAmount);

        // Verify vault tokens exist BEFORE withrawal
        uint256 vaultBalance = gettersFacet.getVaultTotalAssets(LINK_CONTRACT_ADDRESS);
        require(vaultBalance >= depositAmount);

        vm.selectFork(avaxFork);
        _dripLink(depositAmount, B, avaxFork);
        switchSigner(B);

        _xDepositCollateral(AVAX_LINK_CONTRACT_ADDRESS, depositAmount, avaxFork, B);

        uint256 userBalance = gettersFacet.getAddressToCollateralDeposited(B, LINK_CONTRACT_ADDRESS);
        assertEq(userBalance, depositAmount);

        vm.selectFork(arbFork);

        switchSigner(B);
        _xborrowFromPool(ARB_LINK_CONTRACT_ADDRESS, borrowAmount, arbFork, B);
        vm.stopPrank();

        vm.selectFork(hubFork);
        //TEST THE HUB

        (uint256 borrowedAmount,,, bool isActive) = gettersFacet.getUserBorrowData(B, LINK_CONTRACT_ADDRESS);
        assertTrue(isActive);
        assertEq(borrowedAmount, borrowAmount, "Initial debt should equal borrowed amount");
    }

    function test_xRepayFromLiquidityPool() public {
        uint256 amount = 100 ether;
        _dripLink(amount, owner, hubFork);
        _intializeProtocolPool(LINK_CONTRACT_ADDRESS);
        _deployVault(LINK_CONTRACT_ADDRESS, "USDT-VAULT", "VUSDT");

        uint256 depositAmount = 100 ether;
        uint256 borrowAmount = 30 ether; // Partial withdrawal

        // Deposit on ARB (mints vault tokens to owner on hub)
        xdepositIntoLiquidityPool(ARB_LINK_CONTRACT_ADDRESS, depositAmount, arbFork, owner);

        // Verify deposit was successful
        vm.selectFork(hubFork);
        uint256 initialBalance = gettersFacet.getUserPoolDeposit(owner, LINK_CONTRACT_ADDRESS);
        assertEq(initialBalance, depositAmount);

        // Verify vault tokens exist BEFORE withrawal
        uint256 vaultBalance = gettersFacet.getVaultTotalAssets(LINK_CONTRACT_ADDRESS);
        require(vaultBalance >= depositAmount);

        vm.selectFork(avaxFork);
        _dripLink(depositAmount, B, avaxFork);
        switchSigner(B);

        _xDepositCollateral(AVAX_LINK_CONTRACT_ADDRESS, depositAmount, avaxFork, B);

        uint256 userBalance = gettersFacet.getAddressToCollateralDeposited(B, LINK_CONTRACT_ADDRESS);
        assertEq(userBalance, depositAmount);

        vm.selectFork(arbFork);

        switchSigner(B);
        _xborrowFromPool(ARB_LINK_CONTRACT_ADDRESS, borrowAmount, arbFork, B);
        vm.stopPrank();

        vm.selectFork(hubFork);

        (uint256 borrowedAmount,,, bool isActive) = gettersFacet.getUserBorrowData(B, LINK_CONTRACT_ADDRESS);
        assertTrue(isActive);
        assertEq(borrowedAmount, borrowAmount, "Initial debt should equal borrowed amount");

        vm.stopPrank();

        vm.warp(block.timestamp + 31 days);
        vm.selectFork(hubFork);
        uint256 currentDebt = gettersFacet.getUserDebt(B, LINK_CONTRACT_ADDRESS);

        vm.selectFork(avaxFork);
        _dripLink(borrowAmount + 20 ether, B, avaxFork);
        vm.deal(B, 10 ether);
        switchSigner(B);

        ERC20Mock(AVAX_LINK_CONTRACT_ADDRESS).approve(address(liquidityPoolFacet), type(uint256).max);
        uint256 currentBalance = ERC20Mock(AVAX_LINK_CONTRACT_ADDRESS).balanceOf(B);

        xRepayFromPool(AVAX_LINK_CONTRACT_ADDRESS, currentDebt, avaxFork, B);
        vm.stopPrank();

        vm.selectFork(hubFork);
        (uint256 remainingBorrowedAmount,,, bool isStillActive) =
            gettersFacet.getUserBorrowData(B, LINK_CONTRACT_ADDRESS);

        // Check user balance after repayment
        uint256 balanceAfterRepay = ERC20Mock(LINK_CONTRACT_ADDRESS).balanceOf(B);

        // Assertions
        assertEq(remainingBorrowedAmount, 0, "Debt should be fully cleared");
        assertFalse(isStillActive, "Borrow position should be inactive");
    }

    function test_xBorrowFromLiquidityPool_MaxBorrow() public {
        uint256 amount = 200 ether;
        _dripLink(amount, owner, hubFork);
        _intializeProtocolPool(LINK_CONTRACT_ADDRESS);
        _deployVault(LINK_CONTRACT_ADDRESS, "USDT-VAULT", "VUSDT");

        uint256 depositAmount = 200 ether;
        uint256 collateralAmount = 100 ether;
        // Assuming 75% LTV ratio, max borrow would be ~75 ether
        uint256 maxBorrowAmount = 75 ether;

        xdepositIntoLiquidityPool(ARB_LINK_CONTRACT_ADDRESS, depositAmount, arbFork, owner);

        vm.selectFork(avaxFork);
        _dripLink(collateralAmount, B, avaxFork);
        switchSigner(B);

        _xDepositCollateral(AVAX_LINK_CONTRACT_ADDRESS, collateralAmount, avaxFork, B);

        vm.selectFork(arbFork);
        switchSigner(B);

        _xborrowFromPool(ARB_LINK_CONTRACT_ADDRESS, maxBorrowAmount, arbFork, B);
        vm.stopPrank();

        vm.selectFork(hubFork);
        (uint256 borrowedAmount,,, bool isActive) = gettersFacet.getUserBorrowData(B, LINK_CONTRACT_ADDRESS);
        assertTrue(isActive);
        assertEq(borrowedAmount, maxBorrowAmount, "Should borrow maximum allowed amount");
    }

    // Additional Test Cases for test_xRepayFromLiquidityPool()

    // Test Case 1: Test partial repayment
    function test_xRepayFromLiquidityPool_PartialRepay() public {
        uint256 amount = 100 ether;
        _dripLink(amount, owner, hubFork);
        _intializeProtocolPool(LINK_CONTRACT_ADDRESS);
        _deployVault(LINK_CONTRACT_ADDRESS, "USDT-VAULT", "VUSDT");

        uint256 depositAmount = 100 ether;
        uint256 borrowAmount = 30 ether;
        uint256 partialRepayAmount = 15 ether; // Half of borrowed amount

        // Setup borrowing scenario
        xdepositIntoLiquidityPool(ARB_LINK_CONTRACT_ADDRESS, depositAmount, arbFork, owner);

        vm.selectFork(avaxFork);
        _dripLink(depositAmount, B, avaxFork);
        switchSigner(B);

        _xDepositCollateral(AVAX_LINK_CONTRACT_ADDRESS, depositAmount, avaxFork, B);

        vm.selectFork(arbFork);
        switchSigner(B);
        _xborrowFromPool(ARB_LINK_CONTRACT_ADDRESS, borrowAmount, arbFork, B);
        vm.stopPrank();

        // Fast forward time to accrue interest
        vm.warp(block.timestamp + 15 days);

        vm.selectFork(hubFork);
        uint256 currentDebt = gettersFacet.getUserDebt(B, LINK_CONTRACT_ADDRESS);

        vm.selectFork(avaxFork);
        _dripLink(partialRepayAmount + 10 ether, B, avaxFork);
        vm.deal(B, 10 ether);
        switchSigner(B);

        ERC20Mock(AVAX_LINK_CONTRACT_ADDRESS).approve(address(liquidityPoolFacet), type(uint256).max);

        xRepayFromPool(AVAX_LINK_CONTRACT_ADDRESS, partialRepayAmount, avaxFork, B);
        vm.stopPrank();

        vm.selectFork(hubFork);
        (uint256 remainingBorrowedAmount,,, bool isStillActive) =
            gettersFacet.getUserBorrowData(B, LINK_CONTRACT_ADDRESS);

        assertTrue(isStillActive, "Borrow position should still be active");
        assertGt(remainingBorrowedAmount, 0, "Should have remaining debt");
        assertLt(remainingBorrowedAmount, currentDebt, "Debt should be reduced");
    }

    // Test Case 3: Test repayment after significant time passage with interest accrual
    function test_xRepayFromLiquidityPool_LongTermInterest() public {
        uint256 amount = 100 ether;
        _dripLink(amount, owner, hubFork);
        _intializeProtocolPool(LINK_CONTRACT_ADDRESS);
        _deployVault(LINK_CONTRACT_ADDRESS, "USDT-VAULT", "VUSDT");

        uint256 depositAmount = 100 ether;
        uint256 borrowAmount = 30 ether;

        // Setup borrowing scenario
        xdepositIntoLiquidityPool(ARB_LINK_CONTRACT_ADDRESS, depositAmount, arbFork, owner);

        vm.selectFork(avaxFork);
        _dripLink(depositAmount, B, avaxFork);
        switchSigner(B);

        _xDepositCollateral(AVAX_LINK_CONTRACT_ADDRESS, depositAmount, avaxFork, B);

        vm.selectFork(arbFork);
        switchSigner(B);
        _xborrowFromPool(ARB_LINK_CONTRACT_ADDRESS, borrowAmount, arbFork, B);
        vm.stopPrank();

        vm.selectFork(hubFork);
        (uint256 initialBorrowedAmount,,,) = gettersFacet.getUserBorrowData(B, LINK_CONTRACT_ADDRESS);

        // Fast forward 6 months to accrue significant interest
        vm.warp(block.timestamp + 180 days);

        uint256 currentDebt = gettersFacet.getUserDebt(B, LINK_CONTRACT_ADDRESS);

        vm.selectFork(avaxFork);
        _dripLink(currentDebt + 50 ether, B, avaxFork);
        vm.deal(B, 10 ether);
        switchSigner(B);

        ERC20Mock(AVAX_LINK_CONTRACT_ADDRESS).approve(address(liquidityPoolFacet), type(uint256).max);

        xRepayFromPool(AVAX_LINK_CONTRACT_ADDRESS, currentDebt, avaxFork, B);
        vm.stopPrank();

        vm.selectFork(hubFork);
        (uint256 remainingBorrowedAmount,,, bool isStillActive) =
            gettersFacet.getUserBorrowData(B, LINK_CONTRACT_ADDRESS);

        assertEq(remainingBorrowedAmount, 0, "Debt should be fully cleared");
        assertFalse(isStillActive, "Borrow position should be inactive");
        assertGt(currentDebt, initialBorrowedAmount, "Interest should have accrued over time");
    }
}
