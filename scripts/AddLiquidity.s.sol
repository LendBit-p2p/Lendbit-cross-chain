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

contract AddLiquidity is Script {
    //contract types of facets to be deployed
    Diamond diamond;
    // DiamondCutFacet dCutFacet;
    // DiamondLoupeFacet dLoupe;
    // OwnershipFacet ownerF;
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
    address ETH_CONTRACT_ADDRESS = address(1);

    address WETH_CONTRACT_ADDRESS = 0xAB6015514c40F5B0bb583f28c0819cA79e3B9415;
    address DAI_CONTRACT_ADDRESS = 0xb0dbA4BDEC9334f4E9663e9b9941E37018BbE81a;
    address LINK_CONTRACT_ADDRESS = 0x9b76e44C8d3a625D0d5e9a04227dc878B31897C2;

    address[] tokens;
    address[] priceFeed;

    function setUp() public {}
    function run() external {
        vm.startBroadcast();
        //deploy facets

        diamond = Diamond(payable(0xFbD73D79571DB3a46cA82414a8EF5107e640dF63));

        //upgrade diamond with facets
        protocolFacet = ProtocolFacet(address(diamond));
        liqPoolFacet = LiquidityPoolFacet(address(diamond));

        TestERC20(DAI_CONTRACT_ADDRESS).mint(msg.sender, 1_000_000E18);
        TestERC20(LINK_CONTRACT_ADDRESS).mint(msg.sender, 1_000_000E18);
        TestERC20(WETH_CONTRACT_ADDRESS).mint(msg.sender, 1_000_000E18);

        ERC20(DAI_CONTRACT_ADDRESS).approve(
            address(diamond),
            type(uint256).max
        );
        ERC20(LINK_CONTRACT_ADDRESS).approve(
            address(diamond),
            type(uint256).max
        );
        ERC20(WETH_CONTRACT_ADDRESS).approve(
            address(diamond),
            type(uint256).max
        );

        liqPoolFacet.deposit(DAI_CONTRACT_ADDRESS, 100_000E18);
        liqPoolFacet.deposit(LINK_CONTRACT_ADDRESS, 100_000E18);
        liqPoolFacet.deposit(WETH_CONTRACT_ADDRESS, 100_000E18);

        uint256 amount = 10_000E18;
        uint256 amount2 = 1_000E18;
        uint256 amount3 = 100E18;

        // ERC20(WETH_CONTRACT_ADDRESS).approve(address(diamond), 100_000E18);
        // ERC20(DAI_CONTRACT_ADDRESS).approve(address(diamond), 100_000E18);
        // ERC20(LINK_CONTRACT_ADDRESS).approve(address(diamond), 100_000E18);

        protocolFacet.depositCollateral(WETH_CONTRACT_ADDRESS, amount);

        protocolFacet.createLendingRequest(
            uint128(amount2),
            500,
            (block.timestamp + 120 days),
            DAI_CONTRACT_ADDRESS
        );
        protocolFacet.createLendingRequest(
            uint128(amount3),
            500,
            block.timestamp + (120 days),
            LINK_CONTRACT_ADDRESS
        );

        protocolFacet.createLoanListing(
            100_000E18,
            50E18,
            100_000E18,
            block.timestamp + 120 days,
            500,
            LINK_CONTRACT_ADDRESS,
            new address[](0)
        );

        protocolFacet.createLoanListing(
            100_000E18,
            50E18,
            100_000E18,
            block.timestamp + 120 days,
            500,
            DAI_CONTRACT_ADDRESS,
            new address[](0)
        );

        liqPoolFacet.borrowFromPool(LINK_CONTRACT_ADDRESS, 100E18);
        liqPoolFacet.borrowFromPool(DAI_CONTRACT_ADDRESS, 100E18);
        liqPoolFacet.borrowFromPool(WETH_CONTRACT_ADDRESS, 100E18);

        vm.stopBroadcast();
    }
}
