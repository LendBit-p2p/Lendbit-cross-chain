// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../Base.t.sol";
import {console} from "forge-std/console.sol";
import {Client} from "@chainlink/contract-ccip/contracts/libraries/Client.sol";
import {CCIPMessageSent} from "../../contracts/spoke/libraries/Events.sol";
import {CollateralWithdrawn} from "../../contracts/model/Event.sol";

contract LiquidityPoolXFacetTest is Base {
    function setUp() public override {
        owner = address(0x4a3aF8C69ceE81182A9E74b2392d4bDc616Bf7c7);
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


        uint256 userBalance = liquidityPoolFacet.getUserPoolDeposit(
            owner,
            LINK_CONTRACT_ADDRESS
        );

        assertEq(userBalance, amount);
        assertEq(
            ERC20Mock(LINK_CONTRACT_ADDRESS).balanceOf(address(liquidityPoolFacet)),
            amount
        );

        //TESTING THE VAULT WORKS 
        uint vaultAssets = liquidityPoolFacet.getVaultTotalAssets(LINK_CONTRACT_ADDRESS);
        assertEq(vaultAssets, amount);
    }


    function test_xdepositInto_LiquidityPoolThroughAVAX() public {

        _intializeProtocolPool(LINK_CONTRACT_ADDRESS);
        _deployVault(LINK_CONTRACT_ADDRESS, "USDT-VAULT", "VUSDT");

        uint256 amount = 100 ether;
        _dripLink(amount, owner, avaxFork);
         xdepositIntoLiquidityPool(AVAX_LINK_CONTRACT_ADDRESS, amount, avaxFork, owner);


        uint256 userBalance = liquidityPoolFacet.getUserPoolDeposit(
            owner,
            LINK_CONTRACT_ADDRESS
        );

        assertEq(userBalance, amount);
        assertEq(
            ERC20Mock(LINK_CONTRACT_ADDRESS).balanceOf(address(liquidityPoolFacet)),
            amount
        );

          //TESTING THE VAULT WORKS 
        uint vaultAssets = liquidityPoolFacet.getVaultTotalAssets(LINK_CONTRACT_ADDRESS);
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
    uint256 userBalance = liquidityPoolFacet.getUserPoolDeposit(
        owner,
        LINK_CONTRACT_ADDRESS
    );
    
    assertEq(userBalance, amount * 3);
    assertEq(
        ERC20Mock(LINK_CONTRACT_ADDRESS).balanceOf(address(liquidityPoolFacet)),
        amount * 3
    );
    
    // Testing the vault works 
    uint vaultAssets = liquidityPoolFacet.getVaultTotalAssets(LINK_CONTRACT_ADDRESS);
    assertEq(vaultAssets, amount * 3);
}

 function test_xWithdrawFrom_ARB_And_DepositOnAVAX() public {

     _intializeProtocolPool(LINK_CONTRACT_ADDRESS);
        _deployVault(LINK_CONTRACT_ADDRESS, "USDT-VAULT", "VUSDT");

     uint256 amount = 100 ether;
        _dripLink(amount, owner, avaxFork);
         xdepositIntoLiquidityPool(AVAX_LINK_CONTRACT_ADDRESS, amount, avaxFork, owner);


        uint256 userBalance = liquidityPoolFacet.getUserPoolDeposit(
            owner,
            LINK_CONTRACT_ADDRESS
        );

        assertEq(userBalance, amount);
        assertEq(
            ERC20Mock(LINK_CONTRACT_ADDRESS).balanceOf(address(liquidityPoolFacet)),
            amount
        );

          //TESTING THE VAULT WORKS 
        uint vaultAssets = liquidityPoolFacet.getVaultTotalAssets(LINK_CONTRACT_ADDRESS);
        assertEq(vaultAssets, amount);


        // Withdraw from AVAX fork
        _xWithdrawnFromPool(
            ARB_LINK_CONTRACT_ADDRESS,
            amount,
            arbFork,
            owner
        );

        vm.selectFork(hubFork);
        uint256 finalUserBalance = liquidityPoolFacet.getUserPoolDeposit(owner, LINK_CONTRACT_ADDRESS);
        assertEq(finalUserBalance, 0, "User should have no remaining shares");

    //       vm.selectFork(arbFork);
    //     uint256 finalArbBalance = ERC20Mock(ARB_LINK_CONTRACT_ADDRESS).balanceOf(owner);
    //     assertGt(finalArbBalance, initialArbBalance, "User should have received tokens on ARB");
    // }

//     function 
// test_xDepositOnABR_WithdrawFromHUB() public {

}










}