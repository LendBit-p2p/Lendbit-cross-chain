// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../Base.t.sol";
import {console} from "forge-std/console.sol";
import {Client} from "@chainlink/contract-ccip/contracts/libraries/Client.sol";
import {CCIPMessageSent} from "../../contracts/spoke/libraries/Events.sol";

contract SharedxFacetTest is Base {
    function setUp() public override {
        owner = address(0x4a3aF8C69ceE81182A9E74b2392d4bDc616Bf7c7);
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
}
