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
import "../contracts/facets/SharedFacet.sol";
import "../contracts/facets/CcipFacet.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {console} from "forge-std/console.sol";
import {CCIPLocalSimulatorFork, Register} from "@chainlink/local/src/ccip/CCIPLocalSimulatorFork.sol";

import {SpokeContract} from "../contracts/spoke/SpokeContract.sol";

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
    uint64 HUB_CHAIN_SELECTOR = 10344971235874465080;

    // SPOKEs
    SpokeContract arbSpokeContract;
    SpokeContract avaxSpokeContract;

    // CCIP
    CCIPLocalSimulatorFork public ccipLocalSimulatorFork;
    uint256 hubFork;
    uint256 arbFork;
    uint256 avaxFork;

    // Users Addresses
    address owner;
    address B;
    address C;

    address[] _hubTokens;
    string[] _hubSymbols;
    address[] _spokeTokens;
    address[] _priceFeed;

    address WETH_CONTRACT_ADDRESS =
        address(0xbAd49269309C439e811E2315B343c4b54CdBEd07);
    address USDT_CONTRACT_ADDRESS =
        address(0x036CbD53842c5426634e7929541eC2318f3dCF7e);
    address DAI_CONTRACT_ADDRESS =
        address(0xFEa8109D6955c4F3F7930ad57B5798606264BDB0);
    address LINK_CONTRACT_ADDRESS =
        address(0x46d4AafcEd9cc65089D1606e6cAE85fe6D7df456);
    address ETH_CONTRACT_ADDRESS = address(1);
    address AVAX_CONTRACT_ADDRESS =
        address(0x2cB2118262a75B494183b6c44De23e50776843eb);
    address ARB_LINK_CONTRACT_ADDRESS =
        address(0x23eb68D3C0472f6892c2d68B0F2A8F0f5282a7ED);
    address ARB_USDT_CONTRACT_ADDRESS =
        address(0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d);
    address ARB_DAI_CONTRACT_ADDRESS =
        address(0x6bc614678F6B64Fa7F4530C66E03F3DaB8C236a6);
    address ARB_WETH_CONTRACT_ADDRESS =
        address(0x5cB4bfA9f8803Ae9231b6eAC4AC85e1dAd8bC432);
    address AVAX_LINK_CONTRACT_ADDRESS =
        address(0xdEd13e60DF60b5C1CA192160487D7B5ef82769A4);
    address AVAX_USDT_CONTRACT_ADDRESS =
        address(0x5425890298aed601595a70AB815c96711a31Bc65);
    address AVAX_DAI_CONTRACT_ADDRESS =
        address(0xaEa812b8B553E270A49B0f4093e86E24DDA88b46);

    address OP_WETH = 0x972B21b50b9b5B05C5907928197e76eBFbBCe0C6;
    address OP_LINK = 0xB68D6a420f60FAa64bFE165a3ce9313E734eFD34;
    address OP_DAI = 0x3fE4a6f534aCB3f1fEaf6C7Bc3810cB7eC9136aE;
    address OP_USDC = 0x5fd84259d66Cd46123540766Be93DFE6D43130D7;

    address USDT_USD = 0x3ec8593F930EA45ea58c968260e6e9FF53FC934f;
    address DAI_USD = 0xD1092a65338d049DB68D7Be6bD89d17a0929945e;
    address LINK_USD = 0xb113F5A928BCfF189C998ab20d753a47F9dE5A61;
    address WETH_USD = 0x4aDC67696bA383F43DD60A9e78F2C97Fbbfc7cb1;
    address ETH_USD = 0x4aDC67696bA383F43DD60A9e78F2C97Fbbfc7cb1;

    function setUp() public {
        _hubTokens.push(AVAX_CONTRACT_ADDRESS);
        // _hubTokens.push(LINK_CONTRACT_ADDRESS);
        // _hubTokens.push(WETH_CONTRACT_ADDRESS);
        // _hubTokens.push(ETH_CONTRACT_ADDRESS);
        // _hubTokens.push(DAI_CONTRACT_ADDRESS);

        // _hubSymbols.push("vUSDC");
        // _hubSymbols.push("vLINK");
        // _hubSymbols.push("vWETH");
        // _hubSymbols.push("vETH");
        // _hubSymbols.push("vDAI");

        // _priceFeed.push(USDT_USD);
        // _priceFeed.push(LINK_USD);
        _priceFeed.push(LINK_USD);
        // _priceFeed.push(WETH_USD);
        // _priceFeed.push(WETH_USD);
        // _priceFeed.push(DAI_USD);
    }
    function run() external {
        // deployXDiamonds();
        // bytes32 salt = bytes32(abi.encodePacked("SpokeContractLendBit!"));
        // deploySpokes(salt);
        vm.startBroadcast();
        // OwnershipFacet(0x052C88f4f88c9330f6226cdC120ba173416134C3)
        //     .addSupportedChain(
        //         14767482510784806043,
        //         0xf6B39D70fDA787aB1cd9eF0DD6AC2190f34a6458
        //     );
        // OwnershipFacet(0x052C88f4f88c9330f6226cdC120ba173416134C3)
        //     .addCollateralTokens(_hubTokens, _priceFeed);
        // OwnershipFacet(0x052C88f4f88c9330f6226cdC120ba173416134C3)
        //     .addSupportedChain(
        //         3478487238524512106,
        //         0x1C0fbFf22C5Ab94bA0B5d46403b8101855355262
        //     );
        SpokeContract(payable(0xf6B39D70fDA787aB1cd9eF0DD6AC2190f34a6458))
            .addToken(
                ETH_CONTRACT_ADDRESS,
                AVAX_CONTRACT_ADDRESS,
                SpokeContract.TokenType.CHAIN_SPECIFIC
            );
        // FoR UPGRADING THE CONTRACT
        // upgradeDiamond(0x052C88f4f88c9330f6226cdC120ba173416134C3);
        // uint256 _reserveFactor = 2000; // 20%
        // uint256 _optimalUtilization = 8000; // 80%
        // uint256 _baseRate = 500; // 5%
        // uint256 _slopeRate = 2000; // 20%
        // for (uint256 i = 0; i < _hubTokens.length; i++) {
        //     LiquidityPoolFacet(
        //         address(0x052C88f4f88c9330f6226cdC120ba173416134C3)
        //     ).deployProtocolAssetVault(
        //             _hubTokens[i],
        //             _hubSymbols[i],
        //             _hubSymbols[i]
        //         );
        // }
        vm.stopBroadcast();

        // console.log("Diamond deployed at: ", address(diamond));
        // console.log("DiamondCutFacet deployed at: ", address(dCutFacet));
        // console.log("DiamondLoupeFacet deployed at: ", address(dLoupe));
        // console.log("OwnershipFacet deployed at: ", address(ownerF));
        // console.log("ProtocolFacet deployed at: ", address(protocolFacet));
        // console.log(
        //     "LiquidityPoolFacet deployed at: ",
        //     address(liquidityPoolFacet)
        // );
        // console.log("GettersFacet deployed at: ", address(gettersFacet));
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

    function deployXDiamonds() public virtual {
        vm.startBroadcast();
        dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(msg.sender, address(dCutFacet));
        dLoupe = new DiamondLoupeFacet();
        ownerF = new OwnershipFacet();
        protocolFacet = new ProtocolFacet();
        gettersFacet = new GettersFacet();
        sharedFacet = new SharedFacet();
        liquidityPoolFacet = new LiquidityPoolFacet();
        ccipFacet = new CcipFacet();

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
        ownerF = OwnershipFacet(address(diamond));

        ownerF.setFeeRate(100);
        uint256 _reserveFactor = 2000; // 20%
        uint256 _optimalUtilization = 8000; // 80%
        uint256 _baseRate = 500; // 5%
        uint256 _slopeRate = 2000; // 20%

        for (uint256 i = 0; i < _hubTokens.length; i++) {
            OwnershipFacet(address(diamond)).initializeProtocolPool(
                _hubTokens[i],
                _reserveFactor,
                _optimalUtilization,
                _baseRate,
                _slopeRate
            );
        }
        vm.stopBroadcast();
        // vm.selectFork(arbFork);
        // vm.startBroadcast();
        // Register.NetworkDetails
        //     memory arbNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(
        //         block.chainid
        //     );
        // arbSpokeContract = new SpokeContract(
        //     address(diamond),
        //     HUB_CHAIN_SELECTOR,
        //     arbNetworkDetails.linkAddress,
        //     arbNetworkDetails.routerAddress,
        //     arbNetworkDetails.wrappedNativeAddress
        // );
        // arbSpokeContract.addToken(
        //     ARB_USDT_CONTRACT_ADDRESS,
        //     USDT_CONTRACT_ADDRESS
        // );
        // arbSpokeContract.addToken(
        //     ARB_LINK_CONTRACT_ADDRESS,
        //     LINK_CONTRACT_ADDRESS
        // );
        // arbSpokeContract.addToken(
        //     arbNetworkDetails.wrappedNativeAddress,
        //     WETH_CONTRACT_ADDRESS
        // );
        // arbSpokeContract.addToken(ETH_CONTRACT_ADDRESS, ETH_CONTRACT_ADDRESS);
        // vm.stopBroadcast();
        // vm.selectFork(avaxFork);
        // vm.startBroadcast();
        // Register.NetworkDetails
        //     memory avaxNetworkDetails = ccipLocalSimulatorFork
        //         .getNetworkDetails(block.chainid);
        // avaxSpokeContract = new SpokeContract(
        //     address(diamond),
        //     HUB_CHAIN_SELECTOR,
        //     avaxNetworkDetails.linkAddress,
        //     avaxNetworkDetails.routerAddress,
        //     avaxNetworkDetails.wrappedNativeAddress
        // );
        // avaxSpokeContract.addToken(
        //     AVAX_USDT_CONTRACT_ADDRESS,
        //     USDT_CONTRACT_ADDRESS
        // );
        // avaxSpokeContract.addToken(
        //     AVAX_LINK_CONTRACT_ADDRESS,
        //     LINK_CONTRACT_ADDRESS
        // );
        // avaxSpokeContract.addToken(
        //     avaxNetworkDetails.wrappedNativeAddress,
        //     WETH_CONTRACT_ADDRESS
        // );
        // avaxSpokeContract.addToken(ETH_CONTRACT_ADDRESS, ETH_CONTRACT_ADDRESS);
        // vm.stopBroadcast();
        // vm.selectFork(hubFork);
        // vm.startBroadcast();
        // ownerF.addSupportedChain(
        //     arbNetworkDetails.chainSelector,
        //     address(arbSpokeContract)
        // );
        // ownerF.addSupportedChain(
        //     avaxNetworkDetails.chainSelector,
        //     address(avaxSpokeContract)
        // );
        // uint256 _reserveFactor = 2000; // 20%
        // uint256 _optimalUtilization = 8000; // 80%
        // uint256 _baseRate = 500; // 5%
        // uint256 _slopeRate = 2000; // 20%

        // for (uint256 i = 0; i < _hubTokens.length; i++) {
        //     OwnershipFacet(address(diamond)).initializeProtocolPool(
        //         _hubTokens[i],
        //         _reserveFactor,
        //         _optimalUtilization,
        //         _baseRate,
        //         _slopeRate
        //     );
        // }

        // vm.stopBroadcast();
    }

    function upgradeDiamond(address _diamondAddress) public {
        diamond = Diamond(payable(_diamondAddress));
        dLoupe = new DiamondLoupeFacet();
        ownerF = new OwnershipFacet();
        protocolFacet = new ProtocolFacet();
        gettersFacet = new GettersFacet();
        sharedFacet = new SharedFacet();
        liquidityPoolFacet = new LiquidityPoolFacet();
        ccipFacet = new CcipFacet();

        //upgrade diamond with facets
        FacetCut[] memory cut = new FacetCut[](1);

        cut[0] = (
            FacetCut({
                facetAddress: address(ccipFacet),
                action: FacetCutAction.Replace,
                functionSelectors: generateSelectors("CcipFacet")
            })
        );

        IDiamondCut(address(diamond)).diamondCut(cut, address(0x0), "");

        //call a function
        DiamondLoupeFacet(address(diamond)).facetAddresses();
        console.log("Successfully Upgraded");
    }

    function computeSpokeAddress(
        uint64 chainId,
        address hubContract,
        uint64 hubChainSelector,
        address linkToken,
        address router,
        address wrappedNative
    ) public view returns (address) {
        bytes32 bytecodeHash = keccak256(type(SpokeContract).creationCode);
        bytes32 salt = keccak256(
            abi.encode(
                chainId,
                hubContract,
                hubChainSelector,
                linkToken,
                router,
                wrappedNative
            )
        );

        return
            address(
                uint160(
                    uint256(
                        keccak256(
                            abi.encodePacked(
                                bytes1(0xff),
                                address(this),
                                salt,
                                bytecodeHash
                            )
                        )
                    )
                )
            );
    }

    function deploySpokes(bytes32 salt) public {
        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(ccipLocalSimulatorFork));

        vm.startBroadcast();
        Register.NetworkDetails
            memory avaxNetworkDetails = ccipLocalSimulatorFork
                .getNetworkDetails(block.chainid);

        // Compute deterministic salt based on chain parameters
        bytes32 chainSpecificSalt = keccak256(
            abi.encode(
                block.chainid,
                address(0x052C88f4f88c9330f6226cdC120ba173416134C3),
                HUB_CHAIN_SELECTOR,
                avaxNetworkDetails.linkAddress,
                avaxNetworkDetails.routerAddress,
                OP_WETH
            )
        );

        // Log the predicted address before deployment
        address predictedAddress = computeSpokeAddress(
            uint64(block.chainid),
            address(0x052C88f4f88c9330f6226cdC120ba173416134C3),
            HUB_CHAIN_SELECTOR,
            avaxNetworkDetails.linkAddress,
            avaxNetworkDetails.routerAddress,
            avaxNetworkDetails.wrappedNativeAddress
        );
        console.log("Predicted Spoke Contract address: ", predictedAddress);

        avaxSpokeContract = new SpokeContract(
            address(0x052C88f4f88c9330f6226cdC120ba173416134C3),
            HUB_CHAIN_SELECTOR,
            avaxNetworkDetails.linkAddress,
            avaxNetworkDetails.routerAddress,
            avaxNetworkDetails.wrappedNativeAddress
        );

        console.log(
            "Actual Spoke Contract deployed at: ",
            address(avaxSpokeContract)
        );
        // require(
        //     address(avaxSpokeContract) == predictedAddress,
        //     "Deployed address doesn't match predicted address"
        // );

        avaxSpokeContract.addToken(
            AVAX_USDT_CONTRACT_ADDRESS,
            USDT_CONTRACT_ADDRESS,
            SpokeContract.TokenType.INTEROPORABLE
        );
        avaxSpokeContract.addToken(
            AVAX_LINK_CONTRACT_ADDRESS,
            LINK_CONTRACT_ADDRESS,
            SpokeContract.TokenType.INTEROPORABLE
        );
        // avaxSpokeContract.addToken(OP_WETH, WETH_CONTRACT_ADDRESS);
        avaxSpokeContract.addToken(
            ETH_CONTRACT_ADDRESS,
            AVAX_CONTRACT_ADDRESS,
            SpokeContract.TokenType.CHAIN_SPECIFIC
        );
        avaxSpokeContract.addToken(
            AVAX_DAI_CONTRACT_ADDRESS,
            DAI_CONTRACT_ADDRESS,
            SpokeContract.TokenType.INTEROPORABLE
        );

        vm.stopBroadcast();
    }

    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external override {}
}
