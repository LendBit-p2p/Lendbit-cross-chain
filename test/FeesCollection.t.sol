// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "forge-std/Test.sol";
import "../contracts/Diamond.sol";
import "../contracts/facets/ProtocolFacet.sol";
import "../contracts/facets/GettersFacet.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../contracts/model/Protocol.sol";
import "../contracts/model/Event.sol";
import "../contracts/utils/constants/Constant.sol";
import "../contracts/utils/validators/Validator.sol";

// MOCK Contracts
import {MockV3Aggregator} from "@chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract ProtocolTest is Test, IDiamondCut {
    //contract types of facets to be deployed
    Diamond diamond;
    DiamondCutFacet dCutFacet;
    DiamondLoupeFacet dLoupe;
    OwnershipFacet ownerF;
    ProtocolFacet protocolFacet;
    GettersFacet gettersFacet;

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
        gettersFacet = new GettersFacet();

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
                facetAddress: address(gettersFacet),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("GettersFacet")
            })
        );

        //upgrade diamond
        IDiamondCut(address(diamond)).diamondCut(cut, address(0x0), "");

        //call a function
        DiamondLoupeFacet(address(diamond)).facetAddresses();

        ///@notice set protocol constructor by the diamond
        diamond.initialize(tokens, priceFeed);

        protocolFacet = ProtocolFacet(address(diamond));
        gettersFacet = GettersFacet(address(diamond));
        // protocolFacet.setBotAddress(botAddress);
        // protocolFacet.setSwapRouter(swapRouterAddress);

        ProtocolFacet(address(diamond)).setFeeRate(100);

        transferTokenToOwner();
    }

    function transferTokenToOwner() public {
        ERC20Mock(USDT_CONTRACT_ADDRESS).mint(owner, 1000e18);
        ERC20Mock(DAI_CONTRACT_ADDRESS).mint(owner, 500 ether);
        ERC20Mock(WETH_CONTRACT_ADDRESS).mint(owner, 500 ether);
        ERC20Mock(LINK_CONTRACT_ADDRESS).mint(owner, 500 ether);
    }

    function _mintTokenToAddress(address _token, address _to, uint256 _amount) internal {
        ERC20Mock(_token).mint(_to, _amount);
    }

    function testGetFeesAccrued() public {
        _mintTokenToAddress(USDT_CONTRACT_ADDRESS, B, 100000e18);
        _depositCollateral(owner, WETH_CONTRACT_ADDRESS, 5e18);

        ProtocolFacet protocol = ProtocolFacet(address(diamond));
        protocol.createLendingRequest(200e18, 500, block.timestamp + (30 days * 3), USDT_CONTRACT_ADDRESS);

        IERC20 usdt = IERC20(USDT_CONTRACT_ADDRESS);

        switchSigner(B);
        usdt.approve(address(diamond), 250e18);
        protocol.serviceRequest(1, USDT_CONTRACT_ADDRESS);

        switchSigner(owner);
        usdt.approve(address(diamond), 250e18);
        protocol.repayLoan(1, 210e18);

        uint256 _feesAccruedUsdt = gettersFacet.getFeesAccrued(USDT_CONTRACT_ADDRESS);
        // assuming 1% fee rate
        assertEq(_feesAccruedUsdt, 210e16);
    }

    function testFeeAccruedOnNativeToken() public {
        vm.deal(owner, 3 ether);
        vm.deal(B, 10 ether);
        _depositCollateral(owner, WETH_CONTRACT_ADDRESS, 5e18);

        ProtocolFacet protocol = ProtocolFacet(address(diamond));
        protocol.createLendingRequest(2e18, 500, block.timestamp + (30 days * 3), ETH_CONTRACT_ADDRESS);

        switchSigner(B);
        protocol.serviceRequest{value: 2e18}(1, ETH_CONTRACT_ADDRESS);

        switchSigner(owner);
        protocol.repayLoan{value: 21e17}(1, 21e17);

        uint256 _feesAccruedUsdt = gettersFacet.getFeesAccrued(ETH_CONTRACT_ADDRESS);
        // assuming 1% fee rate
        assertEq(_feesAccruedUsdt, 21e15);
    }

    function testFeesAccrueWithPeriodicPayments() public {
        _mintTokenToAddress(DAI_CONTRACT_ADDRESS, B, 10000e18);
        _depositCollateral(owner, WETH_CONTRACT_ADDRESS, 5e18);

        ProtocolFacet protocol = ProtocolFacet(address(diamond));
        protocol.createLendingRequest(200e18, 500, block.timestamp + (30 days * 3), DAI_CONTRACT_ADDRESS);

        IERC20 dai = IERC20(DAI_CONTRACT_ADDRESS);

        switchSigner(B);
        dai.approve(address(diamond), 250e18);
        protocol.serviceRequest(1, DAI_CONTRACT_ADDRESS);

        gettersFacet.getRequest(1);

        switchSigner(owner);
        dai.approve(address(diamond), 250e18);
        protocol.repayLoan(1, 50e18);

        uint256 _feesAccruedAfter1 = gettersFacet.getFeesAccrued(DAI_CONTRACT_ADDRESS);
        // assuming 1% fee rate
        assertEq(_feesAccruedAfter1, 5e17);

        protocol.repayLoan(1, 120e18);
        uint256 _feesAccruedAfter2 = gettersFacet.getFeesAccrued(DAI_CONTRACT_ADDRESS);
        assertEq(_feesAccruedAfter2, 17e17);

        protocol.repayLoan(1, 80e18);
        uint256 _feesAccruedAfter3 = gettersFacet.getFeesAccrued(DAI_CONTRACT_ADDRESS);
        assertEq(_feesAccruedAfter3, 21e17);

        gettersFacet.getRequest(1);
    }

    function testFeeWithdrawalERC20() public {
        _mintTokenToAddress(DAI_CONTRACT_ADDRESS, B, 100_000_000e18);
        _mintTokenToAddress(WETH_CONTRACT_ADDRESS, owner, 500_000e18);
        _mintTokenToAddress(DAI_CONTRACT_ADDRESS, owner, 100_000_000e18);
        _depositCollateral(owner, WETH_CONTRACT_ADDRESS, 500_000e18);

        ProtocolFacet protocol = ProtocolFacet(address(diamond));
        protocol.createLendingRequest(70_000_000e18, 1000, block.timestamp + (30 days * 3), DAI_CONTRACT_ADDRESS);

        IERC20 dai = IERC20(DAI_CONTRACT_ADDRESS);

        switchSigner(B);
        dai.approve(address(diamond), 100_000_000e18);
        protocol.serviceRequest(1, DAI_CONTRACT_ADDRESS);

        switchSigner(owner);
        dai.approve(address(diamond), 100_000_000e18);
        protocol.repayLoan(1, 77_000_000e18);

        uint256 _feesAccruedUsdt = gettersFacet.getFeesAccrued(DAI_CONTRACT_ADDRESS);
        // assuming 1% fee rate
        assertEq(_feesAccruedUsdt, 770_000e18);

        protocol.withdrawFees(DAI_CONTRACT_ADDRESS, C, 500_000e18);
        uint256 _feesAfterWithdrawal = gettersFacet.getFeesAccrued(DAI_CONTRACT_ADDRESS);
        assertEq(_feesAfterWithdrawal, 270_000e18);

        uint256 _balance = dai.balanceOf(C);
        assertEq(_balance, 500_000e18);
    }

    function testFeeWithdrawalNative() public {
        vm.deal(B, 1_000_000e18);
        vm.deal(owner, 1_000_000e18);
        _mintTokenToAddress(WETH_CONTRACT_ADDRESS, owner, 500_000e18);
        _depositCollateral(owner, WETH_CONTRACT_ADDRESS, 500_000e18);

        uint128 _amount = 300_000e18;
        uint256 _repayAmount = 330_000e18;
        uint256 _feeAccrued = 3300e18;

        ProtocolFacet protocol = ProtocolFacet(address(diamond));
        protocol.createLendingRequest(_amount, 1000, block.timestamp + (30 days * 3), ETH_CONTRACT_ADDRESS);

        switchSigner(B);
        protocol.serviceRequest{value: _amount}(1, ETH_CONTRACT_ADDRESS);

        switchSigner(owner);
        protocol.repayLoan{value: _repayAmount}(1, _repayAmount);

        uint256 _feesAccruedEth = gettersFacet.getFeesAccrued(ETH_CONTRACT_ADDRESS);
        // assuming 1% fee rate
        assertEq(_feesAccruedEth, _feeAccrued);

        protocol.withdrawFees(ETH_CONTRACT_ADDRESS, C, 1000e18);
        uint256 _feesAfterWithdrawal = gettersFacet.getFeesAccrued(ETH_CONTRACT_ADDRESS);
        assertEq(_feesAfterWithdrawal, 2300e18);

        uint256 _balance = C.balance;
        assertEq(_balance, 1000e18);
    }

    function testWithdrawRevertsIfNotContractOwner() public {
        testFeeWithdrawalERC20();
        vm.startPrank(B);
        vm.expectRevert(LibDiamond.NotDiamondOwner.selector);
        protocolFacet.withdrawFees(USDT_CONTRACT_ADDRESS, C, 1000e18);
    }

    function testWithdrawRevertsIfZeroAddress() public {
        testFeeWithdrawalERC20();
        vm.expectRevert("invalid address");
        protocolFacet.withdrawFees(USDT_CONTRACT_ADDRESS, address(0), 1000e18);
    }

    function testWithdrawRevertsIfFeesLowerThatWithdrawAmount() public {
        testFeeWithdrawalERC20();
        vm.expectRevert("insufficient fees");
        protocolFacet.withdrawFees(USDT_CONTRACT_ADDRESS, C, 100_000_000e18);
    }

    function testFeeRateCannotExceedTenPercent() public {
        vm.expectRevert("rate cannot exceed 10%");
        protocolFacet.setFeeRate(1001);
    }

    function testSetFeeRateRevertsIfNotContractOwner() public {
        vm.startPrank(B);
        vm.expectRevert(LibDiamond.NotDiamondOwner.selector);
        protocolFacet.setFeeRate(1000);
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
