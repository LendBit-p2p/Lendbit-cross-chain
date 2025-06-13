// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "../Base.t.sol";

contract LiquidityPoolFacetTest is Base {
        address user = address(0x6e37BC743C6496f0EE268C0ea6AdBf2634d979DD);

    function setUp() public override {
        super.setUp();
    }

    function test_depositInto_LiquidityPool() public {
        uint256 amount = 100 ether;

        _deployVault(USDT_CONTRACT_ADDRESS, "USDT-VAULT", "VUSDT");
        _intializeProtocolPool(USDT_CONTRACT_ADDRESS);
        _depositIntoLiquidityPool(USDT_CONTRACT_ADDRESS, amount);
        

        uint256 userBalance = liquidityPoolFacet.getUserPoolDeposit(
            owner,
            USDT_CONTRACT_ADDRESS
        );

        assertEq(userBalance, amount);
        assertEq(
            ERC20Mock(USDT_CONTRACT_ADDRESS).balanceOf(address(liquidityPoolFacet)),
            amount
        );
    }

    function test_withdrawFrom_LiquidityPool() public {
        uint256 amount = 100 ether;
         _deployVault(USDT_CONTRACT_ADDRESS, "USDT-VAULT", "VUSDT");
        _intializeProtocolPool(USDT_CONTRACT_ADDRESS);
        _depositIntoLiquidityPool(USDT_CONTRACT_ADDRESS, amount);

        

        uint256 userBalance = liquidityPoolFacet.getUserPoolDeposit(
            owner,
            USDT_CONTRACT_ADDRESS
        );

        assertEq(userBalance, amount);
        assertEq(
            ERC20Mock(USDT_CONTRACT_ADDRESS).balanceOf(address(liquidityPoolFacet)),
            amount
        );

        liquidityPoolFacet.withdraw(
            USDT_CONTRACT_ADDRESS,
            amount
        );
        uint256 afterWithdrawBalance = liquidityPoolFacet
            .getUserPoolDeposit(owner, USDT_CONTRACT_ADDRESS);
        assertEq(afterWithdrawBalance, 0);

    }

    function testBorrowFromPool() public{
        test_depositInto_LiquidityPool();

         uint256 amountToCollaterized = 200 ether;
         uint256 amountToBorrowed = 100 ether;

        vm.startPrank(user);
        //deposit collateral through avax fork
        ERC20Mock(LINK_CONTRACT_ADDRESS).mint(user, 1000e18);

        _depositCollateral(LINK_CONTRACT_ADDRESS, amountToCollaterized);

        uint256 userBalance = gettersFacet.getAddressToCollateralDeposited(
            user,
            LINK_CONTRACT_ADDRESS
        );

        liquidityPoolFacet.borrowFromPool(USDT_CONTRACT_ADDRESS, amountToBorrowed);

            vm.stopPrank();

        (uint256 borrowedAmount,,, bool isActive) = liquidityPoolFacet.getUserBorrowData(user, USDT_CONTRACT_ADDRESS);

        assertEq(borrowedAmount, amountToBorrowed, "Initial debt should equal borrowed amount");
    }

function testRepayToLoanToPool() public {
    test_depositInto_LiquidityPool();

    uint256 amountToCollaterized = 200 ether;
    uint256 amountToBorrowed = 100 ether;

    vm.startPrank(user);
    
    // Mint LINK for collateral
    ERC20Mock(LINK_CONTRACT_ADDRESS).mint(user, 1000e18);
    
    // Deposit collateral
    _depositCollateral(LINK_CONTRACT_ADDRESS, amountToCollaterized);

    uint256 userBalance = gettersFacet.getAddressToCollateralDeposited(
        user,
        LINK_CONTRACT_ADDRESS
    );

    // Borrow USDT
    liquidityPoolFacet.borrowFromPool(USDT_CONTRACT_ADDRESS, amountToBorrowed);

    vm.stopPrank();

    (uint256 borrowedAmount,,, bool isActive) = liquidityPoolFacet.getUserBorrowData(user, USDT_CONTRACT_ADDRESS);
    assertEq(borrowedAmount, amountToBorrowed, "Initial debt should equal borrowed amount");

    // Advance time to accrue interest
    vm.warp(block.timestamp + 30 days);

    // Get current debt with interest
    uint256 currentDebt = liquidityPoolFacet.getUserDebt(user, USDT_CONTRACT_ADDRESS);
    assertGt(currentDebt, amountToBorrowed, "Debt should include interest");

    vm.startPrank(user);
    
    // The user needs more USDT than just the borrowed amount to pay interest
    uint256 additionalUSDTNeeded = currentDebt - amountToBorrowed;
    ERC20Mock(USDT_CONTRACT_ADDRESS).mint(user, additionalUSDTNeeded);
    
    // Get balance before repayment for verification
    uint256 balanceBeforeRepay = ERC20Mock(USDT_CONTRACT_ADDRESS).balanceOf(user);
    
    // Approve the full debt amount
    ERC20Mock(USDT_CONTRACT_ADDRESS).approve(address(liquidityPoolFacet), currentDebt);

    // User repays the debt
    liquidityPoolFacet.repay(USDT_CONTRACT_ADDRESS, type(uint256).max);

    vm.stopPrank();
    
    // Check remaining debt
    (uint256 remainingBorrowedAmount,,, bool isStillActive) = liquidityPoolFacet.getUserBorrowData(user, USDT_CONTRACT_ADDRESS);
    
    // Check user balance after repayment
    uint256 balanceAfterRepay = ERC20Mock(USDT_CONTRACT_ADDRESS).balanceOf(user);

    // Assertions
    assertEq(remainingBorrowedAmount, 0, "Debt should be fully cleared");
    assertFalse(isStillActive, "Borrow position should be inactive");
    assertEq(balanceAfterRepay, balanceBeforeRepay - currentDebt, "Balance should reflect repayment amount");
}


}