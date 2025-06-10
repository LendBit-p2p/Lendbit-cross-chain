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
        uint256 userBalance = gettersFacet.getAddressToCollateralDeposited(owner, LINK_CONTRACT_ADDRESS);
        assertEq(userBalance, amount);
        vm.stopPrank();

        uint16 interestRate = 1000;
        uint256 duration = 30 days;
        uint256 returnDate = block.timestamp + duration;
        uint256 borrowAmount = 50e6;

        _xCreateLendingRequest(AVAX_USDT_CONTRACT_ADDRESS, borrowAmount, interestRate, returnDate, owner, avaxFork);

        Request memory request = gettersFacet.getRequest(1);
        assertEq(request.author, owner);
        assertEq(request.collateralTokens[0], LINK_CONTRACT_ADDRESS);
        assertEq(request.amount, borrowAmount);
        assertEq(request.interest, interestRate);
        assertEq(request.returnDate, returnDate);
    }

    function test_xCreateLoanListing() public {
        _dripLink(100 ether, owner, arbFork);
        vm.deal(owner, 10 ether);
        uint256 _amount = 50 ether;
        uint256 _returnDate = block.timestamp + 30 days;
        uint16 _interest = 500; // 5bps
        address _loanCurrency = ARB_LINK_CONTRACT_ADDRESS;
        uint256 _min_amount = 10 ether;
        uint256 _max_amount = 100 ether;
        address[] memory _whitelist = new address[](0);

        switchSigner(owner);
        ERC20Mock(ARB_LINK_CONTRACT_ADDRESS).approve(address(arbSpokeContract), _amount);
        arbSpokeContract.createLoanListing{value: 1 ether}(
            _amount, _min_amount, _max_amount, _returnDate, _interest, _loanCurrency, _whitelist
        );

        ccipLocalSimulatorFork.switchChainAndRouteMessage(hubFork);

        // vm.selectFork(hubFork);
        LoanListing memory _listing = gettersFacet.getLoanListing(1);
        assertEq(_listing.amount, _amount);
        assertEq(_listing.min_amount, _min_amount);
        assertEq(_listing.max_amount, _max_amount);
        assertEq(_listing.returnDate, _returnDate);
        assertEq(_listing.interest, _interest);
        assertEq(_listing.tokenAddress, _loanCurrency);
        assertEq(_listing.author, owner);
        assertEq(uint8(_listing.listingStatus), uint8(ListingStatus.OPEN));

        uint256 _balance = ERC20Mock(LINK_CONTRACT_ADDRESS).balanceOf(address(gettersFacet));
        assertEq(_balance, _amount);
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
        bytes32 messageId =
            avaxSpokeContract.createLendingRequest{value: 1 ether}(_amount, _interestRate, _returnDate, _token);

        assert(messageId != bytes32(0));

        ccipLocalSimulatorFork.switchChainAndRouteMessage(hubFork);
    }
}
