// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../Base.t.sol";
import {console} from "forge-std/console.sol";
import "../../contracts/model/Protocol.sol";
import "../../contracts/model/Event.sol";

contract ProtocolxFacetTest is Base {
    function setUp() public override {
        owner = address(0x4a3aF8C69ceE81182A9E74b2392d4bDc616Bf7c7);
        deployXDiamonds();
    }

    function test_protocolxFacet() public {
        console.log("protocolxFacet");
        assert(true);
    }

    function test_createLendingRequest() public {
        vm.startPrank(owner);
        uint256 amount = 100 ether;
        //deposit collateral through arb fork
        _xDepositCollateral(ARB_LINK_CONTRACT_ADDRESS, amount, arbFork, owner);
        uint256 userBalance = gettersFacet.getAddressToCollateralDeposited(
            owner,
            LINK_CONTRACT_ADDRESS
        );
        assertEq(userBalance, amount);
        vm.stopPrank();

        uint16 interestRate = 1000;
        uint256 duration = 30 days;
        uint256 returnDate = block.timestamp + duration;
        uint256 borrowAmount = 50E6;

        _xCreateLendingRequest(
            AVAX_USDT_CONTRACT_ADDRESS,
            borrowAmount,
            interestRate,
            returnDate,
            owner,
            avaxFork
        );

        Request memory request = gettersFacet.getRequest(1);
        assertEq(request.author, owner);
        assertEq(request.collateralTokens[0], LINK_CONTRACT_ADDRESS);
        assertEq(request.amount, borrowAmount);
        assertEq(request.interest, interestRate);
        assertEq(request.returnDate, returnDate);
    }

    function _xCreateLendingRequest(
        address _token,
        uint256 _amount,
        uint16 _interestRate,
        uint256 _returnDate,
        address _user,
        uint256 _fork
    ) public {
        vm.selectFork(_fork);
        vm.startPrank(_user);
        vm.deal(_user, 1 ether);
        bytes32 messageId = avaxSpokeContract.createLendingRequest{
            value: 1 ether
        }(_amount, _interestRate, _returnDate, _token);

        assert(messageId != bytes32(0));

        ccipLocalSimulatorFork.switchChainAndRouteMessage(hubFork);
    }
}
