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
import {CCIPLocalSimulatorFork, Register} from "@chainlink/local/src/ccip/CCIPLocalSimulatorFork.sol";


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
    address[] _spokeTokens;
    address[] _priceFeed;

    address WETH_CONTRACT_ADDRESS = address(1);
    address USDT_CONTRACT_ADDRESS = address(2);
    address DAI_CONTRACT_ADDRESS = address(3);
    address LINK_CONTRACT_ADDRESS = address(4);
    address ETH_CONTRACT_ADDRESS = address(1);
    address ARB_LINK_CONTRACT_ADDRESS =
        address(0x23eb68D3C0472f6892c2d68B0F2A8F0f5282a7ED);
    address ARB_USDT_CONTRACT_ADDRESS =
        address(0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d);
    address AVAX_LINK_CONTRACT_ADDRESS =
        address(0xdEd13e60DF60b5C1CA192160487D7B5ef82769A4);
    address AVAX_USDT_CONTRACT_ADDRESS =
        address(0x5425890298aed601595a70AB815c96711a31Bc65);

    address USDT_USD = 0x3ec8593F930EA45ea58c968260e6e9FF53FC934f;
    address DAI_USD = 0xD1092a65338d049DB68D7Be6bD89d17a0929945e;
    address LINK_USD = 0xb113F5A928BCfF189C998ab20d753a47F9dE5A61;
    address WETH_USD = 0x4aDC67696bA383F43DD60A9e78F2C97Fbbfc7cb1;
    address ETH_USD = 0x4aDC67696bA383F43DD60A9e78F2C97Fbbfc7cb1;

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

    function deployXDiamonds() public virtual {
        string memory HUB_RPC_URL = vm.envString("BASE_SEPOLIA_RPC_URL");
        string memory SPOKE_ARB_RPC_URL = vm.envString(
            "ARBITRUM_SEPOLIA_RPC_URL"
        );
        string memory SPOKE_AVAX_RPC_URL = vm.envString("AVAX_SEPOLIA_RPC_URL");

        hubFork = vm.createFork(HUB_RPC_URL);
        arbFork = vm.createFork(SPOKE_ARB_RPC_URL);
        avaxFork = vm.createFork(SPOKE_AVAX_RPC_URL);

        switchSigner(owner);

        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(ccipLocalSimulatorFork));

        vm.selectFork(hubFork); // Deploy Hub to baseSepolia

        dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(owner, address(dCutFacet));
        dLoupe = new DiamondLoupeFacet();
        ownerF = new OwnershipFacet();
        protocolFacet = new ProtocolFacet();
        gettersFacet = new GettersFacet();
        sharedFacet = new SharedFacet();
        liquidityPoolFacet = new LiquidityPoolFacet();
        ccipFacet = new CcipFacet();

        WETH_CONTRACT_ADDRESS = address(
            0x4200000000000000000000000000000000000006
        );
        LINK_CONTRACT_ADDRESS = address(
            0x46d4AafcEd9cc65089D1606e6cAE85fe6D7df456
        );
        USDT_CONTRACT_ADDRESS = address(
            0x036CbD53842c5426634e7929541eC2318f3dCF7e
        ); //Here we are using a USDC address instead of USDT.

        _hubTokens.push(USDT_CONTRACT_ADDRESS);
        _hubTokens.push(LINK_CONTRACT_ADDRESS);
        _hubTokens.push(WETH_CONTRACT_ADDRESS);
        _hubTokens.push(ETH_CONTRACT_ADDRESS);

        _priceFeed.push(USDT_USD);
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
        ownerF = OwnershipFacet(address(diamond));

        ownerF.setFeeRate(100);

        vm.selectFork(arbFork);
        Register.NetworkDetails
            memory arbNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(
                block.chainid
            );
        arbSpokeContract = new SpokeContract(
            address(diamond),
            HUB_CHAIN_SELECTOR,
            arbNetworkDetails.linkAddress,
            arbNetworkDetails.routerAddress,
            arbNetworkDetails.wrappedNativeAddress
        );
        arbSpokeContract.addToken(
            ARB_USDT_CONTRACT_ADDRESS,
            USDT_CONTRACT_ADDRESS
        );
        arbSpokeContract.addToken(
            ARB_LINK_CONTRACT_ADDRESS,
            LINK_CONTRACT_ADDRESS
        );
        arbSpokeContract.addToken(
            arbNetworkDetails.wrappedNativeAddress,
            WETH_CONTRACT_ADDRESS
        );
        arbSpokeContract.addToken(ETH_CONTRACT_ADDRESS, ETH_CONTRACT_ADDRESS);

        vm.selectFork(avaxFork);
        Register.NetworkDetails
            memory avaxNetworkDetails = ccipLocalSimulatorFork
                .getNetworkDetails(block.chainid);
        avaxSpokeContract = new SpokeContract(
            address(diamond),
            HUB_CHAIN_SELECTOR,
            avaxNetworkDetails.linkAddress,
            avaxNetworkDetails.routerAddress,
            avaxNetworkDetails.wrappedNativeAddress
        );
        avaxSpokeContract.addToken(
            AVAX_USDT_CONTRACT_ADDRESS,
            USDT_CONTRACT_ADDRESS
        );
        avaxSpokeContract.addToken(
            AVAX_LINK_CONTRACT_ADDRESS,
            LINK_CONTRACT_ADDRESS
        );
        avaxSpokeContract.addToken(
            avaxNetworkDetails.wrappedNativeAddress,
            WETH_CONTRACT_ADDRESS
        );
        avaxSpokeContract.addToken(ETH_CONTRACT_ADDRESS, ETH_CONTRACT_ADDRESS);

        vm.selectFork(hubFork);
        ownerF.addSupportedChain(
            arbNetworkDetails.chainSelector,
            address(arbSpokeContract)
        );
        ownerF.addSupportedChain(
            avaxNetworkDetails.chainSelector,
            address(avaxSpokeContract)
        );

        ccipLocalSimulatorFork.requestLinkFromFaucet(
            address(diamond),
            1000000 ether
        );
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
    ///////////////////////////
    // LENDING POOL DEPOSIT
    /////////////////////////
    function _depositIntoLiquidityPool(
        address _token, uint256 _amount
    ) public {
         ERC20Mock(_token).approve(address(liquidityPoolFacet), _amount);
         liquidityPoolFacet.deposit(_token, _amount);
    }

     function _deployVault(address token, string memory name, string memory symbol) public returns (address){
       return liquidityPoolFacet.deployProtocolAssetVault(token, name, symbol);
    }

    



function _intializeProtocolPool(address tokenAddress) public {
    switchSigner(owner);
    vm.deal(owner, 10000000 ether);

// Parameters
uint256 _reserveFactor = 2000; // 20%
uint256 _optimalUtilization = 8000; // 80%
uint256 _baseRate = 500; // 5%
uint256 _slopeRate = 2000; // 20%
uint256 _initialSupply = 100 ether;

OwnershipFacet(address(diamond)).initializeProtocolPool(
tokenAddress, _reserveFactor, _optimalUtilization, _baseRate, _slopeRate
);

// (address token,,, uint256 reserveFactor, uint256 optimalUtilization,,, bool isActive,) =
// liquidityPoolFacet.getProtocolPoolConfig(ETH_CONTRACT_ADDRESS);

// assertEq(token, ETH_CONTRACT_ADDRESS);
// assertEq(_reserveFactor, reserveFactor);
// assertEq(_optimalUtilization, optimalUtilization);
// assertTrue(isActive);



    }





  function xdepositIntoLiquidityPool(
        address _token, 
        uint256 _amount,
        uint256 _fork,
        address _user
    ) public {
        if (_token == ETH_CONTRACT_ADDRESS) {
            revert("ETH is not supported use _xDepositNativeCollateral");
        }
        if (_fork == hubFork) {
        //    _deployVault(_token, "name", "symbol");
            _depositIntoLiquidityPool(_token, _amount);
            return;
        }

        if (_fork == arbFork) {
            vm.selectFork(_fork);
            vm.deal(_user, 1 ether);
             vm.startPrank(_user);
            ERC20Mock(_token).approve(address(arbSpokeContract), _amount);
            arbSpokeContract.deposit{value: 1 ether}(_token, _amount);
             vm.stopPrank();
        }

        if (_fork == avaxFork) {
            vm.selectFork(_fork);
            vm.deal(_user, 1 ether);
            vm.startPrank(_user);
            ERC20Mock(_token).approve(address(avaxSpokeContract), _amount);
            avaxSpokeContract.deposit{value: 1 ether}(
                _token,
                _amount
            );
            vm.stopPrank();
        }
        //give ccipLocalSimulatorFork the ability to route messages
        ccipLocalSimulatorFork.switchChainAndRouteMessage(hubFork);


    }

  function _xWithdrawnFromPool(
    address _token,
    uint256 _amount, 
    uint256 _fork,
    address _user
) public {
    if (_fork == hubFork) {
        liquidityPoolFacet.withdraw(_token, _amount); 
        return;
    }

    if (_fork == arbFork) {
        vm.selectFork(_fork);
        vm.deal(_user, 1 ether);
        arbSpokeContract.withdraw{value: 1 ether}(
            _token,
            _amount
        );
    }

    if (_fork == avaxFork) {
        vm.selectFork(_fork);
        vm.deal(_user, 1 ether);
        avaxSpokeContract.withdraw{value: 1 ether}(
            _token,
            _amount
        );
    }
    ccipLocalSimulatorFork.switchChainAndRouteMessage(hubFork);
    ccipLocalSimulatorFork.switchChainAndRouteMessage(_fork);
}


function _xborrowFromPool(
    address _token,
    uint256 _amount, 
    uint256 _fork,
    address _user
) public {
    if (_fork == hubFork) {
        liquidityPoolFacet.borrowFromPool(_token, _amount); 
        return;
    }

    if (_fork == arbFork) {
        vm.selectFork(_fork);
        vm.deal(_user, 1 ether);
        arbSpokeContract.borrowFromPool{value: 1 ether}(
            _token,
            _amount
        );
    }

    if (_fork == avaxFork) {
        vm.selectFork(_fork);
        vm.deal(_user, 1 ether);
        avaxSpokeContract.borrowFromPool{value: 1 ether}( 
            _token,
            _amount
        );
    }
    ccipLocalSimulatorFork.switchChainAndRouteMessage(hubFork);
    ccipLocalSimulatorFork.switchChainAndRouteMessage(_fork);
}


    function xRepayFromPool(
        address _token,
         uint256 _amount, 
         uint256 _fork,
         address _user
    ) public {

          if (_token == ETH_CONTRACT_ADDRESS) {
            revert("ETH is not supported use _xDepositNativeCollateral");
        }
        if (_fork == hubFork) {
            liquidityPoolFacet.repay(_token, _amount);
            return;
        }

        if (_fork == arbFork) {
            vm.selectFork(_fork);
            vm.deal(_user, 1 ether);
            ERC20Mock(_token).approve(address(arbSpokeContract), _amount);
            arbSpokeContract.repay{value: 1 ether}(_token, _amount);
        }

        if (_fork == avaxFork) {
            vm.selectFork(_fork);
            vm.deal(_user, 1 ether);
            ERC20Mock(_token).approve(address(avaxSpokeContract), _amount);
            avaxSpokeContract.repay{value: 1 ether}(
                _token,
                _amount
            );
        }
        //give ccipLocalSimulatorFork the ability to route messages
        ccipLocalSimulatorFork.switchChainAndRouteMessage(hubFork);



    }


    /////////////////////////
    /////////////////////////
    /////////////////////////
    function _xDepositCollateral(
        address _token,
        uint256 _amount,
        uint256 _fork,
        address _user
    ) public {
        if (_token == ETH_CONTRACT_ADDRESS) {
            revert("ETH is not supported use _xDepositNativeCollateral");
        }
        if (_fork == hubFork) {
            _depositCollateral(_token, _amount);
            return;
        }

        if (_fork == arbFork) {
            vm.selectFork(_fork);
            vm.deal(_user, 1 ether);
            ERC20Mock(_token).approve(address(arbSpokeContract), _amount);
            arbSpokeContract.depositCollateral{value: 1 ether}(_token, _amount);
        }

        if (_fork == avaxFork) {
            vm.selectFork(_fork);
            vm.deal(_user, 1 ether);
            ERC20Mock(_token).approve(address(avaxSpokeContract), _amount);
            avaxSpokeContract.depositCollateral{value: 1 ether}(
                _token,
                _amount
            );
        }
        //give ccipLocalSimulatorFork the ability to route messages
        ccipLocalSimulatorFork.switchChainAndRouteMessage(hubFork);
    }

    function _xDepositNativeCollateral(
        address _user,
        uint256 _amount,
        uint256 _fork
    ) public {
        if (_fork == hubFork) {
            _depositNativeCollateral(_user, _amount);
            return;
        }

        if (_fork == arbFork) {
            vm.selectFork(_fork);
            vm.deal(_user, _amount + 1 ether);
            arbSpokeContract.depositCollateral{value: _amount + 1 ether}(
                ETH_CONTRACT_ADDRESS,
                _amount
            );
        }

        if (_fork == avaxFork) {
            vm.selectFork(_fork);
            vm.deal(_user, _amount + 1 ether);
            avaxSpokeContract.depositCollateral{value: _amount + 1 ether}(
                ETH_CONTRACT_ADDRESS,
                _amount
            );
        }
        //give ccipLocalSimulatorFork the ability to route messages
        ccipLocalSimulatorFork.switchChainAndRouteMessage(hubFork);
    }

    function _xWithdrawCollateral(
        address _token,
        uint256 _amount,
        uint256 _fork,
        address _user
    ) public {
        if (_fork == hubFork) {
            sharedFacet.withdrawCollateral(_token, _amount);
            return;
        }

        if (_fork == arbFork) {
            vm.selectFork(_fork);
            vm.deal(_user, 1 ether);
            arbSpokeContract.withdrawCollateral{value: 1 ether}(
                _token,
                _amount
            );
        }

        if (_fork == avaxFork) {
            vm.selectFork(_fork);
            vm.deal(_user, 1 ether);
            avaxSpokeContract.withdrawCollateral{value: 1 ether}(
                _token,
                _amount
            );
        }
        //give ccipLocalSimulatorFork the ability to route messages
        ccipLocalSimulatorFork.switchChainAndRouteMessage(hubFork);
        ccipLocalSimulatorFork.switchChainAndRouteMessage(_fork);
    }

    function _depositNativeCollateral(address _user, uint256 _amount) public {
        vm.deal(_user, _amount);
        sharedFacet.depositCollateral{value: _amount}(
            ETH_CONTRACT_ADDRESS,
            _amount
        );
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

    // Fixed _dripLink function
function _dripLink(uint256 _amount, address _user, uint256 _fork) public {
    vm.selectFork(_fork); // Select fork FIRST
    vm.startPrank(_user);
    
    if (_fork == hubFork) {
        ERC20Mock(LINK_CONTRACT_ADDRESS).mint(_user, _amount);
    }
    else if (_fork == arbFork) {
        ERC20Mock(ARB_LINK_CONTRACT_ADDRESS).mint(_user, _amount);
    }
    else if (_fork == avaxFork) {
        ERC20Mock(AVAX_LINK_CONTRACT_ADDRESS).mint(_user, _amount);
    }
    
    vm.stopPrank();
}

    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external override {}
}
