// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "forge-std/Test.sol";
import "../contracts/Diamond.sol";
import "../contracts/facets/ProtocolFacet.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../contracts/model/Protocol.sol";
import "../contracts/model/Event.sol";
import "../contracts/utils/constants/Constant.sol";
import "../contracts/utils/validators/Validator.sol";
import {LiquidityPoolFacet} from "../contracts/facets/LiquidityPoolFacet.sol";
import {LibAppStorage} from "../contracts/libraries/LibAppStorage.sol";
// MOCK Contracts
import {MockV3Aggregator} from "@chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {Constants} from "../contracts/utils/constants/Constant.sol";
import "../contracts/utils/validators/Error.sol";

contract ProtocolTest is Test, IDiamondCut {
    //contract types of facets to be deployed
    Diamond diamond;
    DiamondCutFacet dCutFacet;
    DiamondLoupeFacet dLoupe;
    OwnershipFacet ownerF;
    ProtocolFacet protocolFacet;
    LiquidityPoolFacet liquidityPoolFacet;

    address USDT_USD;
    address DAI_USD;
    address LINK_USD;
    address WETH_USD;
    address ETH_USD;

    address USDT_CONTRACT_ADDRESS;
    address WETH_CONTRACT_ADDRESS;
    address DAI_CONTRACT_ADDRESS;
    address LINK_CONTRACT_ADDRESS;
    address ETH_CONTRACT_ADDRESS = address(1);

    address owner;
    address B;
    address C;

    address botAddress = address(0x0beaf0BfC5D1f3f3F8d3a6b0F1B6E3f2b0f1b6e3);
    address swapRouterAddress = 0x1689E7B1F10000AE47eBfE339a4f69dECd19F602;

    address[] tokens;
    address[] priceFeed;

    function setUp() public {
        owner = mkaddr("owner");
        B = mkaddr("B address");
        C = mkaddr("C address");

        switchSigner(owner);
        //deploy facets
        dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(owner, address(dCutFacet));
        dLoupe = new DiamondLoupeFacet();
        ownerF = new OwnershipFacet();
        protocolFacet = new ProtocolFacet();
        liquidityPoolFacet = new LiquidityPoolFacet();

        //deploy mock tokens
        (USDT_CONTRACT_ADDRESS, USDT_USD) = deployERC20ContractAndAddPriceFeed("USDT", 6, 1);
        (DAI_CONTRACT_ADDRESS, DAI_USD) = deployERC20ContractAndAddPriceFeed("DAI", 18, 1);
        (LINK_CONTRACT_ADDRESS, LINK_USD) = deployERC20ContractAndAddPriceFeed("LINK", 18, 10);
        (WETH_CONTRACT_ADDRESS, WETH_USD) = deployERC20ContractAndAddPriceFeed("WETH", 18, 2000);

        tokens.push(USDT_CONTRACT_ADDRESS);
        tokens.push(DAI_CONTRACT_ADDRESS);
        tokens.push(LINK_CONTRACT_ADDRESS);
        tokens.push(WETH_CONTRACT_ADDRESS);
        tokens.push(ETH_CONTRACT_ADDRESS);

        priceFeed.push(USDT_USD);
        priceFeed.push(DAI_USD);
        priceFeed.push(LINK_USD);
        priceFeed.push(WETH_USD);
        priceFeed.push(WETH_USD);

        //upgrade diamond with facets

        //build cut struct
        FacetCut[] memory cut = new FacetCut[](4);

        cut[0] = (
            FacetCut({
                facetAddress: address(dLoupe),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("DiamondLoupeFacet")
            })
        );

        cut[1] = (
            FacetCut({
                facetAddress: address(ownerF),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("OwnershipFacet")
            })
        );

        cut[2] = (
            FacetCut({
                facetAddress: address(protocolFacet),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("ProtocolFacet")
            })
        );
        cut[3] = (
            FacetCut({
                facetAddress: address(liquidityPoolFacet),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("LiquidityPoolFacet")
            })
        );

        //upgrade diamond
        IDiamondCut(address(diamond)).diamondCut(cut, address(0x0), "");

        //call a function
        DiamondLoupeFacet(address(diamond)).facetAddresses();

        ///@notice set protocol constructor by the diamond
        diamond.initialize(tokens, priceFeed);

        protocolFacet = ProtocolFacet(address(diamond));
        liquidityPoolFacet = LiquidityPoolFacet(address(diamond));
        // protocolFacet.setBotAddress(botAddress);
        // protocolFacet.setSwapRouter(swapRouterAddress);

        ProtocolFacet(address(diamond)).setFeeRate(100);

        transferTokenToOwner();
    }

    function transferTokenToOwner() public {
        ERC20Mock(USDT_CONTRACT_ADDRESS).mint(owner, 1000e18);
        ERC20Mock(DAI_CONTRACT_ADDRESS).mint(owner, 10000 ether);
        ERC20Mock(WETH_CONTRACT_ADDRESS).mint(owner, 50000 ether);
        ERC20Mock(LINK_CONTRACT_ADDRESS).mint(owner, 500 ether);
    }

    function testOnlyWhitelistedUserCanRequestLoan() public {
        _depositCollateral(C, ETH_CONTRACT_ADDRESS, 1e18);
        switchSigner(owner);
        IERC20(DAI_CONTRACT_ADDRESS).approve(address(protocolFacet), type(uint256).max);
        address[] memory whitelist = new address[](1);
        whitelist[0] = B;
        protocolFacet.createLoanListing(
            10e10, 2e10, 10e10, block.timestamp + 365 days, 500, DAI_CONTRACT_ADDRESS, whitelist
        );

        switchSigner(C);
        vm.expectRevert(abi.encodeWithSelector(Protocol__NotWhitelisted.selector));
        protocolFacet.requestLoanFromListing(1, 5e10);
    }

    // Test successful initialization with ERC20 (DAI)
    function testProtocolPoolCanBeInitializedWithERC20() public {
        // switchSigner(owner);
        _depositCollateral(owner, DAI_CONTRACT_ADDRESS, 200 ether);

        // Parameters
        uint256 _reserveFactor = 2000; // 20%
        uint256 _optimalUtilization = 8000; // 80%
        uint256 _baseRate = 500; // 5%
        uint256 _slopeRate = 2000; // 20%
        // uint256 _initialSupply = 100 ether;

        liquidityPoolFacet.initializeProtocolPool(
            DAI_CONTRACT_ADDRESS, _reserveFactor, _optimalUtilization, _baseRate, _slopeRate
        );
        (address token,,, uint256 reserveFactor, uint256 optimalUtilization,,, bool isActive,) =
            liquidityPoolFacet.getProtocolPoolConfig(DAI_CONTRACT_ADDRESS);

        assertEq(token, DAI_CONTRACT_ADDRESS);
        assertEq(_reserveFactor, reserveFactor);
        assertEq(_optimalUtilization, optimalUtilization);
        assertTrue(isActive);
    }

    // Test successful initialization with ETH
    function testProtocolPoolCanBeInitializedWithETH() public {
        switchSigner(owner);
        vm.deal(owner, 10000000 ether);

        // Parameters
        uint256 _reserveFactor = 2000; // 20%
        uint256 _optimalUtilization = 8000; // 80%
        uint256 _baseRate = 500; // 5%
        uint256 _slopeRate = 2000; // 20%
        uint256 _initialSupply = 100 ether;

        liquidityPoolFacet.initializeProtocolPool{value: _initialSupply}(
            ETH_CONTRACT_ADDRESS, _reserveFactor, _optimalUtilization, _baseRate, _slopeRate
        );
        (address token,,, uint256 reserveFactor, uint256 optimalUtilization,,, bool isActive,) =
            liquidityPoolFacet.getProtocolPoolConfig(ETH_CONTRACT_ADDRESS);

        assertEq(token, ETH_CONTRACT_ADDRESS);
        assertEq(_reserveFactor, reserveFactor);
        assertEq(_optimalUtilization, optimalUtilization);
        assertTrue(isActive);
    }

    function testDepositInsideTheLiquidityPool() public {
        testProtocolPoolCanBeInitializedWithERC20();
        liquidityPoolFacet.deposit(DAI_CONTRACT_ADDRESS, 100 ether);
        uint256 poolDeposit = liquidityPoolFacet.getUserPoolDeposit(owner, DAI_CONTRACT_ADDRESS);
        assertEq(poolDeposit, 100 ether);
    }

    function testListingWithZeroWhitelistAddressIsOpenForAllAddress() public {
        _depositCollateral(C, ETH_CONTRACT_ADDRESS, 1e18);
        _depositCollateral(B, ETH_CONTRACT_ADDRESS, 1e18);
        switchSigner(owner);
        IERC20(DAI_CONTRACT_ADDRESS).approve(address(protocolFacet), type(uint256).max);
        address[] memory whitelist = new address[](0);
        protocolFacet.createLoanListing(
            10e10, 2e10, 10e10, block.timestamp + 365 days, 500, DAI_CONTRACT_ADDRESS, whitelist
        );

        switchSigner(C);
        vm.expectEmit(true, true, true, true);
        emit RequestCreated(C, 1, 5e10, 500);
        protocolFacet.requestLoanFromListing(1, 5e10);

        switchSigner(B);
        vm.expectEmit(true, true, true, true);
        emit RequestCreated(B, 2, 5e10, 500);
        protocolFacet.requestLoanFromListing(1, 5e10);
    }

    function testUserSharesAreCalculatedCorrectly() public {
        initializeTokenPool(DAI_CONTRACT_ADDRESS);
        // IERC20(DAI_CONTRACT_ADDRESS).approve(
        //     address(protocolFacet),
        //     type(uint256).max
        // );
        uint256 amount = 100 ether;
        uint256 shares = liquidityPoolFacet.deposit(DAI_CONTRACT_ADDRESS, amount);
        assertEq(shares, amount);
    }

    function _mintTokenToAddress(address _token, address _to, uint256 _amount) internal {
        ERC20Mock(_token).mint(_to, _amount);
    }

    event Log(string message);

    function testBorrowInsideALiquidityPool() public {
        initializeTokenPool(DAI_CONTRACT_ADDRESS);

        uint256 DEPOSIT_AMOUNT = 100 ether;
        uint256 BORROW_AMOUNT = 10 ether;
        vm.deal(B, 200000 ether);

        liquidityPoolFacet.deposit(DAI_CONTRACT_ADDRESS, 100 ether);
        uint256 poolDeposit = liquidityPoolFacet.getUserPoolDeposit(owner, DAI_CONTRACT_ADDRESS);
        assertEq(poolDeposit, 100 ether);
        _depositCollateral(B, ETH_CONTRACT_ADDRESS, 200 ether);
        liquidityPoolFacet.borrowFromPool(DAI_CONTRACT_ADDRESS, BORROW_AMOUNT);
        // Verify user debt
        (uint256 borrowedAmount,,, bool isActive) = liquidityPoolFacet.getUserBorrowData(B, DAI_CONTRACT_ADDRESS);
        assertEq(borrowedAmount, BORROW_AMOUNT, "Initial debt should equal borrowed amount");

        assertTrue(isActive);
        (, uint256 poolLiquidity, uint256 totalBorrows,) = liquidityPoolFacet.getPoolTokenData(DAI_CONTRACT_ADDRESS);

        assertEq(poolLiquidity, DEPOSIT_AMOUNT - BORROW_AMOUNT, "Pool liquidity should be reduced");
        assertEq(totalBorrows, BORROW_AMOUNT, "Total borrows should be updated");
    }

    function testUser_CantBorrowInLow_LiquidityPool() public {
        initializeTokenPool(DAI_CONTRACT_ADDRESS);

        uint256 DEPOSIT_AMOUNT = 100 ether;
        uint256 BORROW_AMOUNT = 10000 ether; // Large borrow to exceed the pool amount value
        vm.deal(B, 200000 ether);

        // Owner deposits to the pool
        liquidityPoolFacet.deposit(DAI_CONTRACT_ADDRESS, DEPOSIT_AMOUNT);

        // Deposit minimal collateral as B
        _depositCollateral(B, ETH_CONTRACT_ADDRESS, 0.001 ether); // ~$2 USD at $2000/ETH

        // Attempt to borrow as B

        vm.expectRevert(ProtocolPool__NotEnoughLiquidity.selector);
        liquidityPoolFacet.borrowFromPool(DAI_CONTRACT_ADDRESS, BORROW_AMOUNT);
    }

    function testBorrowWithInsufficientCollateral() public {
        initializeTokenPool(DAI_CONTRACT_ADDRESS);

        uint256 DEPOSIT_AMOUNT = 100 ether;
        uint256 BORROW_AMOUNT = 10 ether; // Large borrow to exceed collateral value
        vm.deal(B, 200000 ether);

        // Owner deposits to the pool
        liquidityPoolFacet.deposit(DAI_CONTRACT_ADDRESS, DEPOSIT_AMOUNT);

        // Deposit minimal collateral as B
        _depositCollateral(B, ETH_CONTRACT_ADDRESS, 0.001 ether); // ~$2 USD at $2000/ETH

        // Attempt to borrow as B

        vm.expectRevert(ProtocolPool__InsufficientCollateral.selector);
        liquidityPoolFacet.borrowFromPool(DAI_CONTRACT_ADDRESS, BORROW_AMOUNT);
    }

    function testBorrowFromInactivePool() public {
        initializeTokenPool(DAI_CONTRACT_ADDRESS);

        uint256 DEPOSIT_AMOUNT = 100 ether;
        uint256 BORROW_AMOUNT = 10 ether;
        vm.deal(B, 200000 ether);

        // Owner deposits to the pool
        liquidityPoolFacet.deposit(DAI_CONTRACT_ADDRESS, DEPOSIT_AMOUNT);

        liquidityPoolFacet.setPoolActive(DAI_CONTRACT_ADDRESS, false); // Add this function if needed

        // Deposit collateral as B
        _depositCollateral(B, ETH_CONTRACT_ADDRESS, 200 ether);

        vm.expectRevert(ProtocolPool__IsNotActive.selector);
        liquidityPoolFacet.borrowFromPool(DAI_CONTRACT_ADDRESS, BORROW_AMOUNT);
        vm.stopPrank();
    }

    function testUserCant_BorrowFrom_UninitializedPool() public {
        uint256 BORROW_AMOUNT = 10 ether;
        vm.deal(B, 200000 ether);

        // Deposit collateral as B
        _depositCollateral(B, ETH_CONTRACT_ADDRESS, 200 ether);

        // Attempt to borrow without initializing the pool
        vm.expectRevert(ProtocolPool__NotInitialized.selector);
        liquidityPoolFacet.borrowFromPool(DAI_CONTRACT_ADDRESS, BORROW_AMOUNT);
        vm.stopPrank();
    }

    function testDifferentUserCanMake_MultipleBorrows() public {
        initializeTokenPool(DAI_CONTRACT_ADDRESS);

        uint256 DEPOSIT_AMOUNT = 100 ether;
        uint256 BORROW_AMOUNT_1 = 10 ether;
        uint256 BORROW_AMOUNT_2 = 20 ether;
        vm.deal(B, 200000 ether);
        vm.deal(C, 200000 ether);

        // Owner deposits to the pool
        liquidityPoolFacet.deposit(DAI_CONTRACT_ADDRESS, DEPOSIT_AMOUNT);

        // Deposit collateral as B
        _depositCollateral(B, ETH_CONTRACT_ADDRESS, 200 ether);

        // First borrow as B
        liquidityPoolFacet.borrowFromPool(DAI_CONTRACT_ADDRESS, BORROW_AMOUNT_1);

        // Deposit collateral as C
        _depositCollateral(C, ETH_CONTRACT_ADDRESS, 200 ether);

        // Second borrow as C
        liquidityPoolFacet.borrowFromPool(DAI_CONTRACT_ADDRESS, BORROW_AMOUNT_2);

        // Verify user debt
        (uint256 borrowedAmount,,, bool isActive) = liquidityPoolFacet.getUserBorrowData(B, DAI_CONTRACT_ADDRESS);
        assertEq(borrowedAmount, BORROW_AMOUNT_1, "Debt should accumulate");
        assertTrue(isActive);

        (uint256 borrowedAmount2,,, bool isActive2) = liquidityPoolFacet.getUserBorrowData(C, DAI_CONTRACT_ADDRESS);
        assertEq(borrowedAmount2, BORROW_AMOUNT_2, "Debt should accumulate");
        assertTrue(isActive2);

        // Verify pool state
        (, uint256 poolLiquidity, uint256 totalBorrows,) = liquidityPoolFacet.getPoolTokenData(DAI_CONTRACT_ADDRESS);
        assertEq(
            poolLiquidity, DEPOSIT_AMOUNT - (BORROW_AMOUNT_1 + BORROW_AMOUNT_2), "Pool liquidity should be reduced"
        );
        assertEq(totalBorrows, BORROW_AMOUNT_1 + BORROW_AMOUNT_2, "Total borrows should be updated");
    }

    function testProtocolPoolCanAccrueInterest() public {
        uint256 DEPOSIT_AMOUNT = 100 ether;
        uint256 BORROW_AMOUNT = 10 ether;

        initializeTokenPool(DAI_CONTRACT_ADDRESS);
        vm.deal(B, 200000 ether);

        liquidityPoolFacet.deposit(DAI_CONTRACT_ADDRESS, DEPOSIT_AMOUNT);

        _depositCollateral(B, ETH_CONTRACT_ADDRESS, 200 ether);
        liquidityPoolFacet.borrowFromPool(DAI_CONTRACT_ADDRESS, BORROW_AMOUNT);

        (, uint256 borrowIndex,,) = liquidityPoolFacet.getUserBorrowData(B, DAI_CONTRACT_ADDRESS);
        require(borrowIndex > 0, "Borrow index should be initialized");

        uint256 initialDebt = liquidityPoolFacet.getUserDebt(B, DAI_CONTRACT_ADDRESS);
        assertEq(initialDebt, BORROW_AMOUNT, "Initial debt should match borrowed amount");

        vm.warp(block.timestamp + 365 days);

        uint256 debtAfterOneYear = liquidityPoolFacet.getUserDebt(B, DAI_CONTRACT_ADDRESS);
        console.log("Debt after one year:", debtAfterOneYear);

        // Expect 0.625% interest: 10 ETH * 1.00625 = 10.0625 ETH
        uint256 expectedDebt = (BORROW_AMOUNT * 100625) / 100000; // 0.625% interest
        uint256 tolerance = 0.01 ether;
        assertApproxEqAbs(debtAfterOneYear, expectedDebt, tolerance, "Interest after 1 year should accrue correctly");
        assertGt(debtAfterOneYear, initialDebt, "Debt should increase over time");
    }

    function testRepayPartial() public {
        // Initialize the token pool
        initializeTokenPool(DAI_CONTRACT_ADDRESS);

        uint256 DEPOSIT_AMOUNT = 100 ether;
        uint256 BORROW_AMOUNT = 10 ether;
        vm.deal(B, 200000 ether);

        // Owner deposits to the pool
        liquidityPoolFacet.deposit(DAI_CONTRACT_ADDRESS, DEPOSIT_AMOUNT);
        uint256 poolDeposit = liquidityPoolFacet.getUserPoolDeposit(owner, DAI_CONTRACT_ADDRESS);
        assertEq(poolDeposit, DEPOSIT_AMOUNT);

        _depositCollateral(B, ETH_CONTRACT_ADDRESS, 200 ether);

        liquidityPoolFacet.borrowFromPool(DAI_CONTRACT_ADDRESS, BORROW_AMOUNT);

        // Verify borrow state
        (uint256 borrowedAmount, uint256 borrowIndex,, bool isActive) =
            liquidityPoolFacet.getUserBorrowData(B, DAI_CONTRACT_ADDRESS);

        assertTrue(isActive);
        assertEq(borrowedAmount, BORROW_AMOUNT, "Initial debt should equal borrowed amount");

        // Verify pool state
        (, uint256 poolLiquidity, uint256 totalBorrows,) = liquidityPoolFacet.getPoolTokenData(DAI_CONTRACT_ADDRESS);

        assertEq(poolLiquidity, DEPOSIT_AMOUNT - BORROW_AMOUNT, "Pool liquidity should be reduced");
        assertEq(totalBorrows, BORROW_AMOUNT, "Total borrows should be updated");

        // Partial repayment
        uint256 repayAmount = BORROW_AMOUNT / 2; // Repay half
        // User2 approves and repays
        IERC20(DAI_CONTRACT_ADDRESS).approve(address(liquidityPoolFacet), repayAmount);

        liquidityPoolFacet.repay(DAI_CONTRACT_ADDRESS, repayAmount);

        // Get updated borrow data
        (borrowedAmount, borrowIndex,, isActive) = liquidityPoolFacet.getUserBorrowData(B, DAI_CONTRACT_ADDRESS);

        // Verify remaining debt
        assertEq(borrowedAmount, BORROW_AMOUNT - repayAmount, "Remaining debt should be updated");
    }

    function testRepayPartialWithInterest() public {
        initializeTokenPool(DAI_CONTRACT_ADDRESS);
        // Mint enough DAI to B to cover partial repayment
        _mintTokenToAddress(DAI_CONTRACT_ADDRESS, B, 1);

        uint256 DEPOSIT_AMOUNT = 100 ether;
        uint256 BORROW_AMOUNT = 10 ether;
        vm.deal(B, 200000 ether);

        // Owner deposits to the pool
        liquidityPoolFacet.deposit(DAI_CONTRACT_ADDRESS, DEPOSIT_AMOUNT);

        // Deposit collateral as B
        _depositCollateral(B, ETH_CONTRACT_ADDRESS, 200 ether);

        // Borrow as B

        liquidityPoolFacet.borrowFromPool(DAI_CONTRACT_ADDRESS, BORROW_AMOUNT);

        uint256 balanceAfterBorrow = IERC20(DAI_CONTRACT_ADDRESS).balanceOf(B);

        // Advance time to accrue interest
        vm.warp(block.timestamp + 30 days);

        // Get current debt
        uint256 currentDebt = liquidityPoolFacet.getUserDebt(B, DAI_CONTRACT_ADDRESS);
        assertGt(currentDebt, BORROW_AMOUNT, "Debt should include interest");

        // Partial repayment (half of current debt)
        uint256 repayAmount = currentDebt / 2;

        IERC20(DAI_CONTRACT_ADDRESS).approve(address(liquidityPoolFacet), repayAmount);
        liquidityPoolFacet.repay(DAI_CONTRACT_ADDRESS, repayAmount);

        uint256 balanceAfterRepayment = IERC20(DAI_CONTRACT_ADDRESS).balanceOf(B);

        // Verify remaining debt
        (uint256 borrowedAmount,,, bool isActive) = liquidityPoolFacet.getUserBorrowData(B, DAI_CONTRACT_ADDRESS);
        assertApproxEqAbs(borrowedAmount, currentDebt - repayAmount, 1e10, "Remaining debt should be updated");
        assertTrue(isActive, "Borrow position should remain active");

        // Verify pool state
        (, uint256 poolLiquidity,,) = liquidityPoolFacet.getPoolTokenData(DAI_CONTRACT_ADDRESS);
        assertEq(poolLiquidity, DEPOSIT_AMOUNT - BORROW_AMOUNT + repayAmount, "Pool liquidity should increase");
        assertEq(balanceAfterRepayment, balanceAfterBorrow - repayAmount, "Balance should be unchanged");
    }

    function testRepayFull() public {
        // Initialize the token pool
        initializeTokenPool(DAI_CONTRACT_ADDRESS);
        _mintTokenToAddress(DAI_CONTRACT_ADDRESS, B, 1 ether);

        uint256 DEPOSIT_AMOUNT = 100 ether;
        uint256 BORROW_AMOUNT = 10 ether;
        // Owner deposits to the pool
        liquidityPoolFacet.deposit(DAI_CONTRACT_ADDRESS, DEPOSIT_AMOUNT);

        uint256 poolDeposit = liquidityPoolFacet.getUserPoolDeposit(owner, DAI_CONTRACT_ADDRESS);
        assertEq(poolDeposit, DEPOSIT_AMOUNT);

        _depositCollateral(B, ETH_CONTRACT_ADDRESS, 200 ether);

        liquidityPoolFacet.borrowFromPool(DAI_CONTRACT_ADDRESS, BORROW_AMOUNT);

        uint256 balanceAfterBorrow = IERC20(DAI_CONTRACT_ADDRESS).balanceOf(B);

        // Verify pool state
        (, uint256 poolLiquidity, uint256 totalBorrows,) = liquidityPoolFacet.getPoolTokenData(DAI_CONTRACT_ADDRESS);

        assertEq(poolLiquidity, DEPOSIT_AMOUNT - BORROW_AMOUNT, "Pool liquidity should be reduced");
        assertEq(totalBorrows, BORROW_AMOUNT, "Total borrows should be updated");

        // Advance time to accrue interest
        vm.warp(block.timestamp + 30 days);

        // Get current debt with interest
        uint256 currentDebt = liquidityPoolFacet.getUserDebt(B, DAI_CONTRACT_ADDRESS);
        assertGt(currentDebt, BORROW_AMOUNT, "Debt should include interest");

        IERC20(DAI_CONTRACT_ADDRESS).approve(address(liquidityPoolFacet), currentDebt);

        // B approves and repays
        liquidityPoolFacet.repay(DAI_CONTRACT_ADDRESS, type(uint256).max);

        // Check remaining debt
        (uint256 borrowedAmount,,, bool isActive) = liquidityPoolFacet.getUserBorrowData(B, DAI_CONTRACT_ADDRESS);

        // check user balance after repayment
        uint256 balanceAfterRepayment = IERC20(DAI_CONTRACT_ADDRESS).balanceOf(B);

        //
        assertEq(balanceAfterRepayment, balanceAfterBorrow - currentDebt, "Balance should be unchanged");
        assertEq(borrowedAmount, 0, "Debt should be fully cleared");
        assertFalse(isActive, "Borrow position should be inactive");
    }

    function testWithdrawFromPool() public {
        // Setup: User deposits tokens first
        initializeTokenPool(DAI_CONTRACT_ADDRESS);
        _mintTokenToAddress(DAI_CONTRACT_ADDRESS, B, 1000 ether);

        uint256 DEPOSIT_AMOUNT = 100 ether;
        // uint256 BORROW_AMOUNT = 10 ether;
        vm.deal(B, 200000 ether);

        liquidityPoolFacet.deposit(DAI_CONTRACT_ADDRESS, 100 ether);

        uint256 poolDeposit = liquidityPoolFacet.getUserPoolDeposit(owner, DAI_CONTRACT_ADDRESS);
        assertEq(poolDeposit, 100 ether);

        (, uint256 poolLiquidity,,) = liquidityPoolFacet.getPoolTokenData(DAI_CONTRACT_ADDRESS);

        assertEq(poolLiquidity, DEPOSIT_AMOUNT, "Pool liquidity should be 100 dia");

        switchSigner(B);
        IERC20(DAI_CONTRACT_ADDRESS).approve(address(liquidityPoolFacet), 200 ether);

        liquidityPoolFacet.deposit(DAI_CONTRACT_ADDRESS, 100 ether);

        uint256 poolDeposit_2 = liquidityPoolFacet.getUserPoolDeposit(B, DAI_CONTRACT_ADDRESS);

        assertEq(poolDeposit_2, 100 ether);

        // Get user's shares after deposit
        uint256 userShares = liquidityPoolFacet.getUserPoolDeposit(B, DAI_CONTRACT_ADDRESS);
        assertGt(userShares, 0, "User should have shares after deposit");

        // Get initial token balance before withdrawal
        // uint256 initialBalance = IERC20(DAI_CONTRACT_ADDRESS).balanceOf(B);

        // Withdraw all shares
        liquidityPoolFacet.withdraw(DAI_CONTRACT_ADDRESS, userShares);

        uint256 sharesafterWithdrawn = liquidityPoolFacet.getUserPoolDeposit(B, DAI_CONTRACT_ADDRESS);
        assertEq(sharesafterWithdrawn, 0, "All shares should be withdrawn");
    }

    function testPartialWithdrawFromPool() public {
        // Setup: User deposits tokens first
        initializeTokenPool(DAI_CONTRACT_ADDRESS);
        _mintTokenToAddress(DAI_CONTRACT_ADDRESS, B, 1000 ether);

        uint256 DEPOSIT_AMOUNT = 100 ether;
        // uint256 BORROW_AMOUNT = 10 ether;
        vm.deal(B, 200000 ether);

        liquidityPoolFacet.deposit(DAI_CONTRACT_ADDRESS, 100 ether);

        uint256 poolDeposit = liquidityPoolFacet.getUserPoolDeposit(owner, DAI_CONTRACT_ADDRESS);
        assertEq(poolDeposit, 100 ether);

        (, uint256 poolLiquidity,,) = liquidityPoolFacet.getPoolTokenData(DAI_CONTRACT_ADDRESS);

        assertEq(poolLiquidity, DEPOSIT_AMOUNT, "Pool liquidity should be 100 dia");

        switchSigner(B);
        IERC20(DAI_CONTRACT_ADDRESS).approve(address(liquidityPoolFacet), 200 ether);

        liquidityPoolFacet.deposit(DAI_CONTRACT_ADDRESS, DEPOSIT_AMOUNT);

        uint256 poolDeposit_2 = liquidityPoolFacet.getUserPoolDeposit(B, DAI_CONTRACT_ADDRESS);

        assertEq(poolDeposit_2, 100 ether);

        // Get user's shares after deposit
        uint256 userShares = liquidityPoolFacet.getUserPoolDeposit(B, DAI_CONTRACT_ADDRESS);
        assertGt(userShares, 0, "User should have shares after deposit");

        // Get initial token balance before withdrawal
        // uint256 initialBalance = IERC20(DAI_CONTRACT_ADDRESS).balanceOf(B);

        uint256 withdrawnHalfAmount = DEPOSIT_AMOUNT / 2;
        // Withdraw all shares
        liquidityPoolFacet.withdraw(DAI_CONTRACT_ADDRESS, withdrawnHalfAmount);

        uint256 sharesafterWithdrawn = liquidityPoolFacet.getUserPoolDeposit(B, DAI_CONTRACT_ADDRESS);
        assertEq(sharesafterWithdrawn, DEPOSIT_AMOUNT - withdrawnHalfAmount, "half shares should be withdrawn");
    }

    function _depositCollateral(address user, address token, uint256 amount) internal {
        switchSigner(user);
        if (token == ETH_CONTRACT_ADDRESS) {
            vm.deal(user, amount);
            protocolFacet.depositCollateral{value: amount}(token, amount);
            return;
        }
        IERC20(token).approve(address(protocolFacet), type(uint256).max);
        protocolFacet.depositCollateral(token, amount);
    }

    function _withdrawCollateral(address user, address token, uint256 amount) internal {
        switchSigner(user);
        protocolFacet.withdrawCollateral(token, uint128(amount));
    }

    function deployERC20ContractAndAddPriceFeed(string memory _name, uint8 _decimals, int256 _initialAnswer)
        internal
        returns (address, address)
    {
        ERC20Mock _erc20 = new ERC20Mock();
        MockV3Aggregator _priceFeed = new MockV3Aggregator(_decimals, _initialAnswer * 1e8);
        vm.label(address(_priceFeed), "Price Feed");
        vm.label(address(_erc20), _name);
        return (address(_erc20), address(_priceFeed));
    }

    function initializeTokenPool(address _token) internal {
        switchSigner(owner);
        uint256 _reserveFactor = 2000; // 20%
        uint256 _optimalUtilization = 8000; // 80%
        uint256 _baseRate = 500; // 5%
        uint256 _slopeRate = 2000; // 20%
        // uint256 _initialSupply = 100 ether;

        IERC20(_token).approve(address(protocolFacet), type(uint256).max);

        liquidityPoolFacet.initializeProtocolPool(_token, _reserveFactor, _optimalUtilization, _baseRate, _slopeRate);
    }

    // Test function for normal utilization (below optimal)
    function testCalculateAprNormalUtilization() public {
        // Setup test variables
        uint256 _reserveFactor = 2000; // 20%
        uint256 _optimalUtilization = 8000; // 80%
        uint256 _baseRate = 500; // 5%
        uint256 _slopeRate = 2000; // 20%

        uint256 totalBorrows = 30 ether; // 30% utilization
        uint256 poolLiquidity = 100 ether;

        // Calculate APR
        uint256 poolApr =
            liquidityPoolFacet.calculatePoolAPR(_baseRate, _slopeRate, _optimalUtilization, totalBorrows, poolLiquidity);

        // Expected APR at 30% utilization (below 80% optimal):
        // baseRate + (slopeRate * utilization / optimalUtilization)
        // 500 + (2000 * 3000 / 8000) = 500 + 750 = 1250 (12.5%)
        uint256 expectedApr = 1250; // 12.5%

        assertEq(poolApr, expectedApr, "APR calculation incorrect for normal utilization");
    }

    // Test function for high utilization (above optimal)
    function testCalculateAprHighUtilization() public {
        // Setup test variables
        uint256 _reserveFactor = 2000; // 20%
        uint256 _optimalUtilization = 8000; // 80%
        uint256 _baseRate = 500; // 5%
        uint256 _slopeRate = 2000; // 20%

        uint256 totalBorrows = 90 ether; // 90% utilization (above optimal)
        uint256 poolLiquidity = 100 ether;

        // Calculate APR
        uint256 poolApr =
            liquidityPoolFacet.calculatePoolAPR(_baseRate, _slopeRate, _optimalUtilization, totalBorrows, poolLiquidity);

        // Expected APR at 90% utilization (above 80% optimal):
        // baseRate + slopeRate + (slopeRate * 2 * excessUtilization / maxExcessUtilization)
        // 500 + 2000 + (2000 * 2 * (9000-8000) / (10000-8000)) = 2500 + 2000 = 4500 (45%)
        uint256 expectedApr = 4500; // 45%

        assertEq(poolApr, expectedApr, "APR calculation incorrect for high utilization");
    }

    // Test function for low utilization
    function testCalculateAprLowUtilization() public {
        // Setup test variables
        uint256 _reserveFactor = 2000; // 20%
        uint256 _optimalUtilization = 8000; // 80%
        uint256 _baseRate = 500; // 5%
        uint256 _slopeRate = 2000; // 20%

        uint256 totalBorrows = 10 ether; // 10% utilization
        uint256 poolLiquidity = 100 ether;

        // Calculate APR
        uint256 poolApr =
            liquidityPoolFacet.calculatePoolAPR(_baseRate, _slopeRate, _optimalUtilization, totalBorrows, poolLiquidity);

        // Expected APR at 10% utilization:
        // baseRate + (slopeRate * utilization / optimalUtilization)
        // 500 + (2000 * 1000 / 8000) = 500 + 250 = 750 (7.5%)
        uint256 expectedApr = 750; // 7.5%

        assertEq(poolApr, expectedApr, "APR calculation incorrect for low utilization");
    }

    // Test function for APY calculation
    function testCalculateApy() public {
        uint256 apr = 1000; // 10% APR
        uint256 compoundingPeriods = 12; // Monthly compounding

        // Calculate APY
        uint256 apy = liquidityPoolFacet.calculatePoolAPY(apr, compoundingPeriods);

        // Expected APY with 10% APR compounded monthly:
        // (1 + 0.10/12)^12 - 1 ≈ 10.47%
        // Due to integer math and precision, we use a range
        assertTrue(apy > 1040 && apy < 1050, "APY calculation incorrect");
    }

    // Test function for APY with different compounding periods
    function testCalculateApyDifferentCompounding() public {
        uint256 apr = 1000; // 10% APR

        // Calculate APY with different compounding periods
        uint256 apyMonthly = liquidityPoolFacet.calculatePoolAPY(apr, 12); // Monthly compounding
        uint256 apyDaily = liquidityPoolFacet.calculatePoolAPY(apr, 365); // Daily compounding
        uint256 apyWeekly = liquidityPoolFacet.calculatePoolAPY(apr, 52); // Weekly compounding

        // Check APY increases with more frequent compounding
        assertTrue(apyDaily > apyWeekly, "Daily compounding should yield higher APY than weekly");
        assertTrue(apyWeekly > apyMonthly, "Weekly compounding should yield higher APY than monthly");
    }

    // Test function to check both APR and APY are calculated correctly
    function testGetRates() public {
        // Setup test variables
        uint256 _reserveFactor = 2000; // 20%
        uint256 _optimalUtilization = 8000; // 80%
        uint256 _baseRate = 500; // 5%
        uint256 _slopeRate = 2000; // 20%

        uint256 totalBorrows = 40 ether; // 40% utilization
        uint256 poolLiquidity = 100 ether;

        // Get both APR and APY
        (uint256 apr, uint256 apy) =
            liquidityPoolFacet.getRatesFromPool(_baseRate, _slopeRate, _optimalUtilization, totalBorrows, poolLiquidity);

        // Expected APR at 40% utilization:
        // baseRate + (slopeRate * utilization / optimalUtilization)
        // 500 + (2000 * 4000 / 8000) = 500 + 1000 = 1500 (15%)
        uint256 expectedApr = 1500; // 15%

        assertEq(apr, expectedApr, "APR calculation incorrect in getRates");
        assertTrue(apy > apr, "APY should be greater than APR due to compounding");
    }

    function generateSelectors(string memory _facetName) internal returns (bytes4[] memory selectors) {
        string[] memory cmd = new string[](3);
        cmd[0] = "node";
        cmd[1] = "scripts/genSelectors.js";
        cmd[2] = _facetName;
        bytes memory res = vm.ffi(cmd);
        selectors = abi.decode(res, (bytes4[]));
    }

    function mkaddr(string memory name) public returns (address) {
        address addr = address(uint160(uint256(keccak256(abi.encodePacked(name)))));
        vm.label(addr, name);
        return addr;
    }

    function switchSigner(address _newSigner) public {
        address foundrySigner = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;
        if (msg.sender == foundrySigner) {
            vm.startPrank(_newSigner);
        } else {
            vm.stopPrank();
            vm.startPrank(_newSigner);
        }
    }

    function diamondCut(FacetCut[] calldata _diamondCut, address _init, bytes calldata _calldata) external override {}
}
