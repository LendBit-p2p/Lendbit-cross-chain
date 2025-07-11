// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../Base.t.sol";
import {console} from "forge-std/console.sol";
import {Client} from "@chainlink/contract-ccip/contracts/libraries/Client.sol";
import {CCIPMessageSent} from "../../contracts/spoke/libraries/Events.sol";
import {CollateralWithdrawn} from "../../contracts/model/Event.sol";
import {IERC20} from "@chainlink/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";

contract SharedxFacetTest is Base {
    function setUp() public override {
        owner = address(0x4a3aF8C69ceE81182A9E74b2392d4bDc616Bf7c7);
        B = mkaddr("B");
        deployXDiamonds();
    }

    function test_sharedxFacet() public {
        console.log("sharedxFacet");
        assert(true);
    }

    function test_xDepositCollateralARB() public {
        vm.startPrank(owner);
        uint256 amount = 100 ether;
        //deposit collateral through arb fork
        _xDepositCollateral(ARB_LINK_CONTRACT_ADDRESS, amount, arbFork, owner);
        uint256 userBalance = gettersFacet.getAddressToCollateralDeposited(
            owner,
            LINK_CONTRACT_ADDRESS
        );

        assertEq(userBalance, amount);
    }

    function test_xDepositCollateralAVAX() public {
        uint256 amount = 100 ether;
        _dripLink(amount, owner, avaxFork);
        vm.startPrank(owner);
        //deposit collateral through avax fork
        _xDepositCollateral(
            AVAX_LINK_CONTRACT_ADDRESS,
            amount,
            avaxFork,
            owner
        );
        uint256 userBalance = gettersFacet.getAddressToCollateralDeposited(
            owner,
            LINK_CONTRACT_ADDRESS
        );

        assertEq(userBalance, amount);
    }

    function test_xDepositCollateralBoth() public {
        uint256 amount = 100 ether;
        _dripLink(amount, owner, avaxFork);

        vm.startPrank(owner);
        _xDepositCollateral(
            AVAX_LINK_CONTRACT_ADDRESS,
            amount,
            avaxFork,
            owner
        );
        vm.startPrank(owner);
        _xDepositCollateral(ARB_LINK_CONTRACT_ADDRESS, amount, arbFork, owner);
        vm.startPrank(owner);
        _xDepositCollateral(LINK_CONTRACT_ADDRESS, amount, hubFork, owner);

        uint256 userBalance = gettersFacet.getAddressToCollateralDeposited(
            owner,
            LINK_CONTRACT_ADDRESS
        );

        assertEq(userBalance, amount * 3);
    }

    function test_xDepositCollateralNativeARB() public {
        uint256 amount = 100 ether;
        vm.startPrank(owner);
        _xDepositNativeCollateral(owner, amount, arbFork);
        uint256 userBalance = gettersFacet.getAddressToCollateralDeposited(
            owner,
            ETH_CONTRACT_ADDRESS
        );

        assertEq(userBalance, amount);
    }

    function test_xWithdrawCollateralNativeARB() public {
        uint256 amount = 100 ether;
        vm.startPrank(owner);
        _xDepositNativeCollateral(owner, amount, arbFork);
        uint256 userBalance = gettersFacet.getAddressToCollateralDeposited(
            owner,
            ETH_CONTRACT_ADDRESS
        );

        assertEq(userBalance, amount);

        vm.startPrank(owner);
        _xWithdrawCollateral(ETH_CONTRACT_ADDRESS, amount, arbFork, owner);
        vm.selectFork(hubFork);
        userBalance = gettersFacet.getAddressToCollateralDeposited(
            owner,
            ETH_CONTRACT_ADDRESS
        );
        assertEq(userBalance, 0);
    }

    /**
     * Testing deposit from a spoke and withdrawing from the HUB
     */
    function test_xWithdrawCollateralARB() public {
        uint256 amount = 100 ether;
        _dripLink(amount, owner, arbFork);
        vm.startPrank(owner);
        _xDepositCollateral(ARB_LINK_CONTRACT_ADDRESS, amount, arbFork, owner);
        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit CollateralWithdrawn(
            owner,
            LINK_CONTRACT_ADDRESS,
            amount,
            HUB_CHAIN_SELECTOR
        );
        _xWithdrawCollateral(LINK_CONTRACT_ADDRESS, amount, hubFork, owner);
        uint256 userBalance = gettersFacet.getAddressToCollateralDeposited(
            owner,
            LINK_CONTRACT_ADDRESS
        );
        assertEq(userBalance, 0);
    }

    /**
     * Testing deposit from the Spoke and withdrawing from another spoke
     */
    function test_xWithdrawCollateralSpokes() public {
        uint256 amount = 100 ether;
        _dripLink(amount, owner, hubFork);
        vm.startPrank(owner);
        _xDepositCollateral(ARB_LINK_CONTRACT_ADDRESS, amount, arbFork, owner);
        vm.startPrank(owner);
        _xWithdrawCollateral(
            AVAX_LINK_CONTRACT_ADDRESS,
            amount,
            avaxFork,
            owner
        );

        assertEq(
            ERC20Mock(AVAX_LINK_CONTRACT_ADDRESS).balanceOf(owner),
            amount
        );
    }

    function test_weth() public {
        vm.startPrank(B);
        vm.expectRevert();
        IWERC20(WETH_CONTRACT_ADDRESS).withdraw(1 ether);
    }

    //////////////////////////
    // TOKENS NOT INTERPROABLE
    ///////////////////////////

    function test_xDepositCollateralNativeAVAX() public {
        uint256 amount = 100 ether;
        vm.startPrank(owner);
        _xDepositNativeCollateral(owner, amount, avaxFork);
        uint256 userBalance = gettersFacet.getAddressToCollateralDeposited(
            owner,
            AVAX_CONTRACT_ADDRESS
        );

        assertEq(userBalance, amount);
    }

    function test_xWithdrawCollateralNativeAVAX() public {
        uint256 amount = 100 ether;
        vm.startPrank(owner);
        _xDepositNativeCollateral(owner, amount, avaxFork);
        uint256 userBalance = gettersFacet.getAddressToCollateralDeposited(
            owner,
            AVAX_CONTRACT_ADDRESS
        );

        assertEq(userBalance, amount);

        vm.startPrank(owner);
        _xWithdrawCollateral(ETH_CONTRACT_ADDRESS, amount, avaxFork, owner);
        vm.selectFork(hubFork);
        userBalance = gettersFacet.getAddressToCollateralDeposited(
            owner,
            AVAX_CONTRACT_ADDRESS
        );
        assertEq(userBalance, 0);
    }
}
