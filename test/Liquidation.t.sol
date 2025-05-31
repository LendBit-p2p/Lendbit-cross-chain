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
import "../contracts/utils/validators/Error.sol";
import {MockV3Aggregator} from "@chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract ProtocolTest is Test, IDiamondCut {
    Diamond diamond;
    DiamondCutFacet dCutFacet;
    DiamondLoupeFacet dLoupe;
    OwnershipFacet ownerF;
    ProtocolFacet protocolFacet;

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
    address feeRecipent;

    address botAddress = address(0x0beaf0BfC5D1f3f3F8d3a6b0F1B6E3f2b0f1b6e3);
    address swapRouterAddress = 0x1689E7B1F10000AE47eBfE339a4f69dECd19F602;

    address[] tokens;
    address[] priceFeed;

    function setUp() public {
        owner = mkaddr("owner");
        B = mkaddr("B address");
        C = mkaddr("C address");
        feeRecipent = mkaddr("feeRecipient");

        switchSigner(owner);
        dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(owner, address(dCutFacet));
        dLoupe = new DiamondLoupeFacet();
        ownerF = new OwnershipFacet();
        protocolFacet = new ProtocolFacet();

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

        FacetCut[] memory cut = new FacetCut[](3);
        cut[0] = FacetCut({
            facetAddress: address(dLoupe),
            action: FacetCutAction.Add,
            functionSelectors: generateSelectors("DiamondLoupeFacet")
        });
        cut[1] = FacetCut({
            facetAddress: address(ownerF),
            action: FacetCutAction.Add,
            functionSelectors: generateSelectors("OwnershipFacet")
        });
        cut[2] = FacetCut({
            facetAddress: address(protocolFacet),
            action: FacetCutAction.Add,
            functionSelectors: generateSelectors("ProtocolFacet")
        });

        IDiamondCut(address(diamond)).diamondCut(cut, address(0x0), "");
        DiamondLoupeFacet(address(diamond)).facetAddresses();

        diamond.initialize(tokens, priceFeed);
        protocolFacet = ProtocolFacet(address(diamond));
        protocolFacet.setProtocolFeeRecipient(feeRecipent);
        ProtocolFacet(address(diamond)).setFeeRate(100);

        transferTokenToOwner();
    }

    function transferTokenToOwner() public {
        ERC20Mock(USDT_CONTRACT_ADDRESS).mint(owner, 1000e6);
        ERC20Mock(DAI_CONTRACT_ADDRESS).mint(owner, 500e18);
        ERC20Mock(WETH_CONTRACT_ADDRESS).mint(owner, 500e18);
        ERC20Mock(LINK_CONTRACT_ADDRESS).mint(owner, 500e18);
    }

    function _mintTokenToAddress(address _token, address _to, uint256 _amount) internal {
        ERC20Mock(_token).mint(_to, _amount);
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

    // Existing Tests (Fixed)
    function testRequestCannotBeLiquidatedIfRequestNotService() public {
        _mintTokenToAddress(USDT_CONTRACT_ADDRESS, B, 100000e6);
        _depositCollateral(owner, WETH_CONTRACT_ADDRESS, 5e18);

        protocolFacet.createLendingRequest(200e6, 500, block.timestamp + (30 days * 3), USDT_CONTRACT_ADDRESS);

        vm.expectRevert(abi.encodeWithSelector(Protocol__RequestNotServiced.selector));
        protocolFacet.liquidateUserRequest(1);
    }

    function testRequestCannot_BeLiquidated_WhenIsNotDueDate() public {
        _mintTokenToAddress(USDT_CONTRACT_ADDRESS, B, 100000e6);
        _depositCollateral(owner, WETH_CONTRACT_ADDRESS, 200e18);

        protocolFacet.createLendingRequest(200e6, 500, block.timestamp + (30 days * 3), USDT_CONTRACT_ADDRESS);

        switchSigner(B);
        ERC20Mock(USDT_CONTRACT_ADDRESS).approve(address(diamond), 200e6);
        protocolFacet.serviceRequest(1, USDT_CONTRACT_ADDRESS);

        vm.expectRevert(abi.encodeWithSelector(Protocol__NotLiquidatable.selector));
        protocolFacet.liquidateUserRequest(1);
    }

    function testRequestCannotBeLiquidated_WhenHealthFactorNotBroken() public {
        _mintTokenToAddress(USDT_CONTRACT_ADDRESS, B, 100000e6);
        _depositCollateral(owner, WETH_CONTRACT_ADDRESS, 200e18);

        protocolFacet.createLendingRequest(200e6, 500, block.timestamp + (30 days * 3), USDT_CONTRACT_ADDRESS);

        switchSigner(B);
        ERC20Mock(USDT_CONTRACT_ADDRESS).approve(address(diamond), 200e6);
        protocolFacet.serviceRequest(1, USDT_CONTRACT_ADDRESS);

        vm.warp(block.timestamp + (30 days * 3) + 1);

        vm.expectRevert(abi.encodeWithSelector(Protocol__NotLiquidatable.selector));
        protocolFacet.liquidateUserRequest(1);
    }

    function testRequestCannotBeLiquidated_WithoutSufficientAllowance() public {
        _mintTokenToAddress(USDT_CONTRACT_ADDRESS, B, 100000e6);
        _depositCollateral(owner, WETH_CONTRACT_ADDRESS, 200e18);

        protocolFacet.createLendingRequest(200e6, 500, block.timestamp + (30 days * 3), USDT_CONTRACT_ADDRESS);

        switchSigner(B);
        ERC20Mock(USDT_CONTRACT_ADDRESS).approve(address(diamond), 200e6);
        protocolFacet.serviceRequest(1, USDT_CONTRACT_ADDRESS);

        vm.warp(block.timestamp + (30 days * 3) + 1);
        MockV3Aggregator(WETH_USD).updateAnswer(1);

        switchSigner(C);
        _mintTokenToAddress(USDT_CONTRACT_ADDRESS, C, 300e6);

        vm.expectRevert();
        protocolFacet.liquidateUserRequest(1);
    }

    function testRequestOwnerCannotLiquidateRequest() public {
        _mintTokenToAddress(USDT_CONTRACT_ADDRESS, B, 100000e6);
        _depositCollateral(owner, WETH_CONTRACT_ADDRESS, 200e18);

        protocolFacet.createLendingRequest(200e6, 500, block.timestamp + (30 days * 3), USDT_CONTRACT_ADDRESS);

        switchSigner(B);
        ERC20Mock(USDT_CONTRACT_ADDRESS).approve(address(diamond), type(uint256).max);
        protocolFacet.serviceRequest(1, USDT_CONTRACT_ADDRESS);

        switchSigner(owner);
        vm.expectRevert(abi.encodeWithSelector(Protocol__OwnerCantLiquidateRequest.selector));
        protocolFacet.liquidateUserRequest(1);
    }

    function testRequestCanBeLiquate() external {
        _mintTokenToAddress(USDT_CONTRACT_ADDRESS, B, 100000e6);
        _depositCollateral(owner, WETH_CONTRACT_ADDRESS, 200e18);

        assertEq(IERC20(WETH_CONTRACT_ADDRESS).balanceOf(address(diamond)), 200e18, "Diamond should hold 200 WETH");

        protocolFacet.createLendingRequest(200e6, 500, block.timestamp + (30 days * 3), USDT_CONTRACT_ADDRESS);

        switchSigner(B);
        ERC20Mock(USDT_CONTRACT_ADDRESS).approve(address(diamond), 200e6);
        protocolFacet.serviceRequest(1, USDT_CONTRACT_ADDRESS);

        vm.warp(block.timestamp + (30 days * 3) + 1);
        MockV3Aggregator(WETH_USD).updateAnswer(1);

        switchSigner(C);
        _mintTokenToAddress(USDT_CONTRACT_ADDRESS, C, 300e6);
        ERC20Mock(USDT_CONTRACT_ADDRESS).approve(address(diamond), type(uint256).max);

        uint256 lenderBalanceBefore = IERC20(USDT_CONTRACT_ADDRESS).balanceOf(B);
        uint256 liquidatorBalanceBefore = IERC20(WETH_CONTRACT_ADDRESS).balanceOf(C);
        uint256 feeRecipientBalanceBefore = IERC20(WETH_CONTRACT_ADDRESS).balanceOf(feeRecipent);

        protocolFacet.liquidateUserRequest(1);

        uint256 totalDebt = 200e6 * 105 / 100;
        uint256 discountedAmount = (200e18 * (10000 - 1000)) / 10000;
        uint256 protocolFee = 200e18 - discountedAmount;

        assertEq(
            IERC20(USDT_CONTRACT_ADDRESS).balanceOf(B),
            lenderBalanceBefore + totalDebt,
            "Lender should receive total debt"
        );
        assertEq(
            IERC20(WETH_CONTRACT_ADDRESS).balanceOf(C),
            liquidatorBalanceBefore + discountedAmount,
            "Liquidator should receive discounted collateral"
        );
        assertEq(
            IERC20(WETH_CONTRACT_ADDRESS).balanceOf(feeRecipent),
            feeRecipientBalanceBefore + protocolFee,
            "Fee recipient should receive protocol fee"
        );
    }

    // // New Tests
    // function testOnlyPriceManipulationCausesLiquidation() public {
    //     _mintTokenToAddress(USDT_CONTRACT_ADDRESS, B, 100000e6);
    //     _depositCollateral(owner, WETH_CONTRACT_ADDRESS, 200e18);

    //     protocolFacet.createLendingRequest(
    //         200e6,
    //         500,
    //         block.timestamp + (30 days * 3),
    //         USDT_CONTRACT_ADDRESS
    //     );

    //     switchSigner(B);
    //     ERC20Mock(USDT_CONTRACT_ADDRESS).approve(address(diamond), 200e6);
    //     protocolFacet.serviceRequest(1, USDT_CONTRACT_ADDRESS);

    //     vm.warp(block.timestamp + (30 days * 3) + 1);

    //     switchSigner(C);
    //     _mintTokenToAddress(USDT_CONTRACT_ADDRESS, C, 300e6);
    //     ERC20Mock(USDT_CONTRACT_ADDRESS).approve(address(diamond), 300e6);

    //     vm.expectRevert(abi.encodeWithSelector(Protocol__NotLiquidatable.selector));
    //     protocolFacet.liquidateUserRequest(1);

    //     MockV3Aggregator(WETH_USD).updateAnswer(1);
    //     protocolFacet.liquidateUserRequest(1);
    // }

    // function testEthDebtCanBeLiquidated() public {
    //     _depositCollateral(owner, WETH_CONTRACT_ADDRESS, 200e18);

    //     protocolFacet.createLendingRequest(
    //         1e18,
    //         500,
    //         block.timestamp + (30 days * 3),
    //         ETH_CONTRACT_ADDRESS
    //     );

    //     switchSigner(B);
    //     vm.deal(B, 2e18);
    //     protocolFacet.serviceRequest{value: 1e18}(1, ETH_CONTRACT_ADDRESS);

    //     vm.warp(block.timestamp + (30 days * 3) + 1);
    //     MockV3Aggregator(WETH_USD).updateAnswer(1);

    //     switchSigner(C);
    //     vm.deal(C, 2e18);

    //     uint256 lenderBalanceBefore = B.balance;
    //     uint256 liquidatorBalanceBefore = C.balance;
    //     uint256 feeRecipientBalanceBefore = feeRecipent.balance;

    //     protocolFacet.liquidateUserRequest{value: 1.05e18}(1);

    //     uint256 totalDebt = 1e18 * 105 / 100;
    //     uint256 discountedAmount = (200e18 * (10000 - Constants.LIQUIDATION_DISCOUNT)) / 10000;
    //     uint256 protocolFee = 200e18 - discountedAmount;

    //     assertEq(B.balance, lenderBalanceBefore + totalDebt, "Lender should receive total debt");
    //     assertEq(IERC20(WETH_CONTRACT_ADDRESS).balanceOf(C), discountedAmount, "Liquidator should receive discounted WETH");
    //     assertEq(IERC20(WETH_CONTRACT_ADDRESS).balanceOf(feeRecipent), protocolFee, "Fee recipient should receive WETH fee");
    // }

    // function testEthDebtLiquidationFailsWithInsufficientEth() public {
    //     _depositCollateral(owner, WETH_CONTRACT_ADDRESS, 200e18);

    //     protocolFacet.createLendingRequest(
    //         1e18,
    //         500,
    //         block.timestamp + (30 days * 3),
    //         ETH_CONTRACT_ADDRESS
    //     );

    //     switchSigner(B);
    //     vm.deal(B, 2e18);
    //     protocolFacet.serviceRequest{value: 1e18}(1, ETH_CONTRACT_ADDRESS);

    //     vm.warp(block.timestamp + (30 days * 3) + 1);
    //     MockV3Aggregator(WETH_USD).updateAnswer(1);

    //     switchSigner(C);
    //     vm.deal(C, 1e18);

    //     vm.expectRevert(abi.encodeWithSelector(Protocol__InsufficientETH.selector));
    //     protocolFacet.liquidateUserRequest{value: 0.5e18}(1);
    // }

    // function testLiquidationBalanceChanges() public {
    //     _mintTokenToAddress(USDT_CONTRACT_ADDRESS, B, 100000e6);
    //     _depositCollateral(owner, WETH_CONTRACT_ADDRESS, 200e18);

    //     protocolFacet.createLendingRequest(
    //         200e6,
    //         500,
    //         block.timestamp + (30 days * 3),
    //         USDT_CONTRACT_ADDRESS
    //     );

    //     switchSigner(B);
    //     ERC20Mock(USDT_CONTRACT_ADDRESS).approve(address(diamond), 200e6);
    //     protocolFacet.serviceRequest(1, USDT_CONTRACT_ADDRESS);

    //     vm.warp(block.timestamp + (30 days * 3) + 1);
    //     MockV3Aggregator(WETH_USD).updateAnswer(1);

    //     switchSigner(C);
    //     _mintTokenToAddress(USDT_CONTRACT_ADDRESS, C, 300e6);
    //     ERC20Mock(USDT_CONTRACT_ADDRESS).approve(address(diamond), 300e6);

    //     uint256 lenderBalanceBefore = IERC20(USDT_CONTRACT_ADDRESS).balanceOf(B);
    //     uint256 liquidatorBalanceBefore = IERC20(WETH_CONTRACT_ADDRESS).balanceOf(C);
    //     uint256 feeRecipientBalanceBefore = IERC20(WETH_CONTRACT_ADDRESS).balanceOf(feeRecipent);
    //     uint256 borrowerBalanceBefore = IERC20(WETH_CONTRACT_ADDRESS).balanceOf(owner);

    //     protocolFacet.liquidateUserRequest(1);

    //     uint256 totalDebt = 200e6 * 105 / 100;
    //     uint256 discountedAmount = (200e18 * (10000 - Constants.LIQUIDATION_DISCOUNT)) / 10000;
    //     uint256 protocolFee = 200e18 - discountedAmount;

    //     assertEq(IERC20(USDT_CONTRACT_ADDRESS).balanceOf(B), lenderBalanceBefore + totalDebt, "Lender balance incorrect");
    //     assertEq(IERC20(WETH_CONTRACT_ADDRESS).balanceOf(C), liquidatorBalanceBefore + discountedAmount, "Liquidator balance incorrect");
    //     assertEq(IERC20(WETH_CONTRACT_ADDRESS).balanceOf(feeRecipent), feeRecipientBalanceBefore + protocolFee, "Fee recipient balance incorrect");
    //     assertEq(IERC20(WETH_CONTRACT_ADDRESS).balanceOf(owner), borrowerBalanceBefore, "Borrower balance should not change");
    // }

    // function testLiquidationWithZeroFeeRecipient() public {
    //     protocolFacet.setProtocolFeeRecipient(address(0));

    //     _mintTokenToAddress(USDT_CONTRACT_ADDRESS, B, 100000e6);
    //     _depositCollateral(owner, WETH_CONTRACT_ADDRESS, 200e18);

    //     protocolFacet.createLendingRequest(
    //         200e6,
    //         500,
    //         block.timestamp + (30 days * 3),
    //         USDT_CONTRACT_ADDRESS
    //     );

    //     switchSigner(B);
    //     ERC20Mock(USDT_CONTRACT_ADDRESS).approve(address(diamond), 200e6);
    //     protocolFacet.serviceRequest(1, USDT_CONTRACT_ADDRESS);

    //     vm.warp(block.timestamp + (30 days * 3) + 1);
    //     MockV3Aggregator(WETH_USD).updateAnswer(1);

    //     switchSigner(C);
    //     _mintTokenToAddress(USDT_CONTRACT_ADDRESS, C, 300e6);
    //     ERC20Mock(USDT_CONTRACT_ADDRESS).approve(address(diamond), 300e6);

    //     uint256 liquidatorBalanceBefore = IERC20(WETH_CONTRACT_ADDRESS).balanceOf(C);

    //     protocolFacet.liquidateUserRequest(1);

    //     uint256 discountedAmount = (200e18 * (10000 - Constants.LIQUIDATION_DISCOUNT)) / 10000;
    //     assertEq(IERC20(WETH_CONTRACT_ADDRESS).balanceOf(C), liquidatorBalanceBefore + discountedAmount, "Liquidator should receive discounted collateral");
    //     assertEq(IERC20(WETH_CONTRACT_ADDRESS).balanceOf(feeRecipent), 0, "Fee recipient should receive nothing");
    // }

    // function testLiquidationWithMultipleCollateral() public {
    //     _mintTokenToAddress(USDT_CONTRACT_ADDRESS, B, 100000e6);
    //     _depositCollateral(owner, WETH_CONTRACT_ADDRESS, 100e18);
    //     _depositCollateral(owner, DAI_CONTRACT_ADDRESS, 1000e18);

    //     protocolFacet.createLendingRequest(
    //         200e6,
    //         500,
    //         block.timestamp + (30 days * 3),
    //         USDT_CONTRACT_ADDRESS
    //     );

    //     switchSigner(B);
    //     ERC20Mock(USDT_CONTRACT_ADDRESS).approve(address(diamond), 200e6);
    //     protocolFacet.serviceRequest(1, USDT_CONTRACT_ADDRESS);

    //     vm.warp(block.timestamp + (30 days * 3) + 1);
    //     MockV3Aggregator(WETH_USD).updateAnswer(1);
    //     MockV3Aggregator(DAI_USD).updateAnswer(1);

    //     switchSigner(C);
    //     _mintTokenToAddress(USDT_CONTRACT_ADDRESS, C, 300e6);
    //     ERC20Mock(USDT_CONTRACT_ADDRESS).approve(address(diamond), 300e6);

    //     uint256 liquidatorWethBefore = IERC20(WETH_CONTRACT_ADDRESS).balanceOf(C);
    //     uint256 liquidatorDaiBefore = IERC20(DAI_CONTRACT_ADDRESS).balanceOf(C);
    //     uint256 feeRecipientWethBefore = IERC20(WETH_CONTRACT_ADDRESS).balanceOf(feeRecipent);
    //     uint256 feeRecipientDaiBefore = IERC20(DAI_CONTRACT_ADDRESS).balanceOf(feeRecipent);

    //     protocolFacet.liquidateUserRequest(1);

    //     uint256 wethDiscounted = (100e18 * (10000 - Constants.LIQUIDATION_DISCOUNT)) / 10000;
    //     uint256 wethFee = 100e18 - wethDiscounted;
    //     uint256 daiDiscounted = (1000e18 * (10000 - Constants.LIQUIDATION_DISCOUNT)) / 10000;
    //     uint256 daiFee = 1000e18 - daiDiscounted;

    //     assertEq(IERC20(WETH_CONTRACT_ADDRESS).balanceOf(C), liquidatorWethBefore + wethDiscounted, "Liquidator WETH incorrect");
    //     assertEq(IERC20(DAI_CONTRACT_ADDRESS).balanceOf(C), liquidatorDaiBefore + daiDiscounted, "Liquidator DAI incorrect");
    //     assertEq(IERC20(WETH_CONTRACT_ADDRESS).balanceOf(feeRecipent), feeRecipientWethBefore + wethFee, "Fee recipient WETH incorrect");
    //     assertEq(IERC20(DAI_CONTRACT_ADDRESS).balanceOf(feeRecipent), feeRecipientDaiBefore + daiFee, "Fee recipient DAI incorrect");
    // }

    // function testLiquidationEmitsEvent() public {
    //     _mintTokenToAddress(USDT_CONTRACT_ADDRESS, B, 100000e6);
    //     _depositCollateral(owner, WETH_CONTRACT_ADDRESS, 200e18);

    //     protocolFacet.createLendingRequest(
    //         200e6,
    //         500,
    //         block.timestamp + (30 days * 3),
    //         USDT_CONTRACT_ADDRESS
    //     );

    //     switchSigner(B);
    //     ERC20Mock(USDT_CONTRACT_ADDRESS).approve(address(diamond), 200e6);
    //     protocolFacet.serviceRequest(1, USDT_CONTRACT_ADDRESS);

    //     vm.warp(block.timestamp + (30 days * 3) + 1);
    //     MockV3Aggregator(WETH_USD).updateAnswer(1);

    //     switchSigner(C);
    //     _mintTokenToAddress(USDT_CONTRACT_ADDRESS, C, 300e6);
    //     ERC20Mock(USDT_CONTRACT_ADDRESS).approve(address(diamond), 300e6);

    //     vm.expectEmit(true, true, true, true);
    //     emit RequestLiquidated(1, C, owner, B, 0);
    //     protocolFacet.liquidateUserRequest(1);
    // }

    // Unchanged helper functions: generateSelectors, mkaddr, switchSigner, diamondCut

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
