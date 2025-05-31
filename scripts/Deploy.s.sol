// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "forge-std/Script.sol";
import "../contracts/Diamond.sol";
import "../contracts/facets/ProtocolFacet.sol";
import "../contracts/facets/LiquidityPoolFacet.sol";
import "../contracts/facets/GettersFacet.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
    function burn(address from, uint256 amount) external {
        require(from == msg.sender, "can only burn your tokens");
        _burn(from, amount);
    }
}

contract Deployment is Script, IDiamondCut {
    //contract types of facets to be deployed
    Diamond diamond;
    DiamondCutFacet dCutFacet;
    DiamondLoupeFacet dLoupe;
    OwnershipFacet ownerF;
    ProtocolFacet protocolFacet;
    LiquidityPoolFacet liqPoolFacet;
    GettersFacet gettersFacet;

    address USDT_USD = 0x3ec8593F930EA45ea58c968260e6e9FF53FC934f;
    address DAI_USD = 0xD1092a65338d049DB68D7Be6bD89d17a0929945e;
    address LINK_USD = 0xb113F5A928BCfF189C998ab20d753a47F9dE5A61;
    address WETH_USD = 0x4aDC67696bA383F43DD60A9e78F2C97Fbbfc7cb1;
    address ETH_USD = 0x4aDC67696bA383F43DD60A9e78F2C97Fbbfc7cb1;

    address USDT_CONTRACT_ADDRESS = 0x00D1C02E008D594ebEFe3F3b7fd175850f96AEa0;
    // address WETH_CONTRACT_ADDRESS = 0x7fEa3ea63433a35e8516777171D7d0e038804716;
    // address DAI_CONTRACT_ADDRESS = 0x5caF98bf477CBE96d5CA56039FE7beec457bA653;
    // address LINK_CONTRACT_ADDRESS = 0xE4aB69C077896252FAFBD49EFD26B5D171A32410;
    address WETH_CONTRACT_ADDRESS = 0xAB6015514c40F5B0bb583f28c0819cA79e3B9415;
    address DAI_CONTRACT_ADDRESS = 0xb0dbA4BDEC9334f4E9663e9b9941E37018BbE81a;
    address LINK_CONTRACT_ADDRESS = 0x9b76e44C8d3a625D0d5e9a04227dc878B31897C2;
    address ETH_CONTRACT_ADDRESS = address(1);

    address[] tokens;
    address[] priceFeed;

    function setUp() public {}
    function run() external {
        vm.startBroadcast();
        //deploy facets
        dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(msg.sender, address(dCutFacet));
        dLoupe = new DiamondLoupeFacet();
        ownerF = new OwnershipFacet();
        protocolFacet = new ProtocolFacet();
        liqPoolFacet = new LiquidityPoolFacet();
        gettersFacet = new GettersFacet();

        // ERC20 weth = new TestERC20("Wrapped Ether", "WETH");
        // ERC20 dai = new TestERC20("DAI", "DAI");
        // ERC20 link = new TestERC20("Chainlink", "LINK");

        tokens.push(USDT_CONTRACT_ADDRESS);
        tokens.push(DAI_CONTRACT_ADDRESS);
        // tokens.push(address(dai));
        tokens.push(LINK_CONTRACT_ADDRESS);
        // tokens.push(address(link));
        tokens.push(WETH_CONTRACT_ADDRESS);
        // tokens.push(address(weth));
        tokens.push(ETH_CONTRACT_ADDRESS);

        priceFeed.push(USDT_USD);
        priceFeed.push(DAI_USD);
        priceFeed.push(LINK_USD);
        priceFeed.push(WETH_USD);
        priceFeed.push(ETH_USD);

        //upgrade diamond with facets

        //build cut struct
        FacetCut[] memory cut = new FacetCut[](5);

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
                facetAddress: address(liqPoolFacet),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("LiquidityPoolFacet")
            })
        );

        cut[4] = (
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
        liqPoolFacet = LiquidityPoolFacet(address(diamond));

        protocolFacet.setProtocolFeeRecipient(msg.sender);
        ProtocolFacet(address(diamond)).setFeeRate(100);

        uint256 _reserveFactor = 2000; // 20%
        uint256 _optimalUtilization = 8000; // 80%
        uint256 _baseRate = 500; // 5%
        uint256 _slopeRate = 2000; // 20%

        for (uint256 i = 0; i < tokens.length; i++) {
            liqPoolFacet.initializeProtocolPool(
                tokens[i],
                _reserveFactor,
                _optimalUtilization,
                _baseRate,
                _slopeRate
            );
        }

        vm.stopBroadcast();

        console.log("Diamond deployed at: ", address(diamond));
        console.log("DiamondCutFacet deployed at: ", address(dCutFacet));
        console.log("DiamondLoupeFacet deployed at: ", address(dLoupe));
        console.log("OwnershipFacet deployed at: ", address(ownerF));
        console.log("ProtocolFacet deployed at: ", address(protocolFacet));
        console.log("LiquidityPoolFacet deployed at: ", address(liqPoolFacet));
        console.log("GettersFacet deployed at: ", address(gettersFacet));
        // console.log("WETH deployed at: ", address(weth));
        // console.log("DAI deployed at: ", address(dai));
        // console.log("LINK deployed at: ", address(link));
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

    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external override {}
}
