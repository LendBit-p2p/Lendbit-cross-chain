// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Diamond} from "../contracts/Diamond.sol";
import {DiamondCutFacet} from "../contracts/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../contracts/facets/DiamondLoupeFacet.sol";
import {OwnershipFacet} from "../contracts/facets/OwnershipFacet.sol";
import {ProtocolFacet} from "../contracts/facets/ProtocolFacet.sol";
import {GettersFacet} from "../contracts/facets/GettersFacet.sol";
import {CcipFacet} from "../contracts/facets/CcipFacet.sol";
import {SharedFacet} from "../contracts/facets/SharedFacet.sol";
import {SpokeContract} from "../contracts/spoke/SpokeContract.sol";
import {LiquidityPoolFacet} from "../contracts/facets/LiquidityPoolFacet.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockV3Aggregator} from "@chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";
import {IDiamondCut} from "../contracts/interfaces/IDiamondCut.sol";

contract Base is Test, IDiamondCut {
    // HUB
    Diamond diamond;
    DiamondCutFacet dCutFacet;
    DiamondLoupeFacet dLoupe;
    OwnershipFacet ownerF;
    ProtocolFacet protocolFacet;
    LiquidityPoolFacet liquidityPoolFacet;
    GettersFacet gettersFacet;
    CcipFacet ccipFacet;
    SharedFacet sharedFacet;

    // SPOKE
    SpokeContract spokeContract;

    // Users Addresses
    address owner;
    address B;
    address C;

    address[] _hubTokens;
    address[] _spokeTokens;
    address[] _priceFeed;

    address WETH_CONTRACT_ADDRESS = address(1);
    address USDT_CONTRACT_ADDRESS = address(2);
    address DAI_CONTRACT_ADDRESS = address(3);
    address LINK_CONTRACT_ADDRESS = address(4);
    address ETH_CONTRACT_ADDRESS = address(1);

    address USDT_USD;
    address DAI_USD;
    address LINK_USD;
    address WETH_USD;
    address ETH_USD;

    function setUp() public virtual {
        owner = mkaddr("owner");
        B = mkaddr("B address");
        C = mkaddr("C address");

        switchSigner(owner);

        deployDiamond();
    }

    function deployDiamond() public virtual {
        dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(owner, address(dCutFacet));
        dLoupe = new DiamondLoupeFacet();
        ownerF = new OwnershipFacet();
        protocolFacet = new ProtocolFacet();
        gettersFacet = new GettersFacet();
        sharedFacet = new SharedFacet();
        liquidityPoolFacet = new LiquidityPoolFacet();
        ccipFacet = new CcipFacet();

        (USDT_CONTRACT_ADDRESS, USDT_USD) = deployERC20ContractAndAddPriceFeed(
            "USDT",
            6,
            1
        );
        (DAI_CONTRACT_ADDRESS, DAI_USD) = deployERC20ContractAndAddPriceFeed(
            "DAI",
            18,
            1
        );
        (LINK_CONTRACT_ADDRESS, LINK_USD) = deployERC20ContractAndAddPriceFeed(
            "LINK",
            18,
            10
        );
        (WETH_CONTRACT_ADDRESS, WETH_USD) = deployERC20ContractAndAddPriceFeed(
            "WETH",
            18,
            2000
        );

        _hubTokens.push(USDT_CONTRACT_ADDRESS);
        _hubTokens.push(DAI_CONTRACT_ADDRESS);
        _hubTokens.push(LINK_CONTRACT_ADDRESS);
        _hubTokens.push(WETH_CONTRACT_ADDRESS);
        _hubTokens.push(ETH_CONTRACT_ADDRESS);

        _priceFeed.push(USDT_USD);
        _priceFeed.push(DAI_USD);
        _priceFeed.push(LINK_USD);
        _priceFeed.push(WETH_USD);
        _priceFeed.push(WETH_USD);

        //upgrade diamond with facets
        FacetCut[] memory cut = new FacetCut[](7);

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
        cut[4] = (
            FacetCut({
                facetAddress: address(sharedFacet),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("SharedFacet")
            })
        );
        cut[5] = (
            FacetCut({
                facetAddress: address(liquidityPoolFacet),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("LiquidityPoolFacet")
            })
        );
        cut[6] = (
            FacetCut({
                facetAddress: address(ccipFacet),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("CcipFacet")
            })
        );

        IDiamondCut(address(diamond)).diamondCut(cut, address(0x0), "");

        //call a function
        DiamondLoupeFacet(address(diamond)).facetAddresses();

        diamond.initialize(_hubTokens, _priceFeed);

        protocolFacet = ProtocolFacet(address(diamond));
        gettersFacet = GettersFacet(address(diamond));
        liquidityPoolFacet = LiquidityPoolFacet(address(diamond));
        ccipFacet = CcipFacet(address(diamond));
        sharedFacet = SharedFacet(address(diamond));

        OwnershipFacet(address(diamond)).setFeeRate(100);

        transferTokenToOwner();
    }

    function transferTokenToOwner() public {
        ERC20Mock(USDT_CONTRACT_ADDRESS).mint(owner, 1000e18);
        ERC20Mock(DAI_CONTRACT_ADDRESS).mint(owner, 500 ether);
        ERC20Mock(WETH_CONTRACT_ADDRESS).mint(owner, 500 ether);
        ERC20Mock(LINK_CONTRACT_ADDRESS).mint(owner, 500 ether);
    }

    function deployERC20ContractAndAddPriceFeed(
        string memory _name,
        uint8 _decimals,
        int256 _initialAnswer
    ) internal returns (address, address) {
        ERC20Mock _erc20 = new ERC20Mock();
        MockV3Aggregator priceFeed = new MockV3Aggregator(
            _decimals,
            _initialAnswer * 1e8
        );
        vm.label(address(priceFeed), "Price Feed");
        vm.label(address(_erc20), _name);
        return (address(_erc20), address(priceFeed));
    }

    function _depositCollateral(address _token, uint256 _amount) public {
        ERC20Mock(_token).approve(address(sharedFacet), _amount);
        sharedFacet.depositCollateral(_token, _amount);
    }

    function generateSelectors(
        string memory _facetName
    ) internal returns (bytes4[] memory selectors) {
        string[] memory cmd = new string[](3);
        cmd[0] = "node";
        cmd[1] = "scripts/genSelectors.js";
        cmd[2] = _facetName;
        bytes memory res = vm.ffi(cmd);
        selectors = abi.decode(res, (bytes4[]));
    }

    function mkaddr(string memory name) public returns (address) {
        address addr = address(
            uint160(uint256(keccak256(abi.encodePacked(name))))
        );
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

    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external override {}
}
