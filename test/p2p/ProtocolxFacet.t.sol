// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../Base.t.sol";
import {console} from "forge-std/console.sol";
import "../../contracts/model/Protocol.sol";
import "../../contracts/model/Event.sol";

contract ProtocolxFacetTest is Base {
    function setUp() public override {
        owner = address(0x4a3aF8C69ceE81182A9E74b2392d4bDc616Bf7c7);
        B = mkaddr("B address");
        C = mkaddr("C address");
        deployXDiamonds();
    }

    function test_protocolxFacet() public {
        console.log("protocolxFacet");
        assert(true);
    }

    function test_xCreateLendingRequest() public {
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

    /**
     * @notice Test the xServiceLendingRequest function
     * This creates a lending request on a spoke chain
     * and services it on the hub chain
     *
     * @dev This test is designed to test the xServiceLendingRequest function
     * and the xDepositCollateral function
     */
    function test_xServiceLendingRequestHub() public {
        uint256 amount = 100 ether;
        _dripLink(amount, B, arbFork);
        vm.startPrank(B);
        _xDepositCollateral(ARB_LINK_CONTRACT_ADDRESS, amount, arbFork, B);
        uint256 userBalance = gettersFacet.getAddressToCollateralDeposited(B, LINK_CONTRACT_ADDRESS);
        assertEq(userBalance, amount);

        vm.stopPrank();

        uint16 interestRate = 1000;
        uint256 duration = 30 days;
        uint256 returnDate = block.timestamp + duration;
        uint256 borrowAmount = 50 ether;

        _xCreateLendingRequest(AVAX_LINK_CONTRACT_ADDRESS, borrowAmount, interestRate, returnDate, B, avaxFork);

        Request memory request = gettersFacet.getRequest(1);
        assertEq(request.author, B);
        assertEq(request.collateralTokens[0], LINK_CONTRACT_ADDRESS);
        assertEq(request.amount, borrowAmount);
        assertEq(request.interest, interestRate);
        assertEq(request.returnDate, returnDate);

        vm.startPrank(owner);
        ERC20Mock(LINK_CONTRACT_ADDRESS).approve(address(protocolFacet), borrowAmount);
        protocolFacet.serviceRequest(1, LINK_CONTRACT_ADDRESS);
        ccipLocalSimulatorFork.switchChainAndRouteMessage(avaxFork);
        vm.stopPrank();
        uint256 balance = ERC20Mock(AVAX_LINK_CONTRACT_ADDRESS).balanceOf(B);
        assertEq(balance, borrowAmount);

        vm.selectFork(hubFork);
        Request memory _request = gettersFacet.getRequest(1);
        assert(_request.lender == owner);
        assert(_request.status == Status.SERVICED);
        assert(_request.amount == borrowAmount);
        assert(_request.interest == interestRate);
    }

    /**
     * @notice Test the xServiceLendingRequest function
     * This creates a lending request on a hub chain
     * and services it on a spoke chain
     *
     * @dev This test is designed to test the xServiceLendingRequest function
     * and the xDepositCollateral function
     */
    function test_xServiceLendingRequestOnSpoke() public {
        uint256 amount = 100 ether;
        _dripLink(amount, B, arbFork);
        vm.startPrank(B);
        _xDepositCollateral(ARB_LINK_CONTRACT_ADDRESS, amount, arbFork, B);
        uint256 userBalance = gettersFacet.getAddressToCollateralDeposited(B, LINK_CONTRACT_ADDRESS);
        assertEq(userBalance, amount);

        vm.stopPrank();

        uint16 interestRate = 1000;
        uint256 duration = 30 days;
        uint256 returnDate = block.timestamp + duration;
        uint256 borrowAmount = 10 ether;

        _xCreateLendingRequest(LINK_CONTRACT_ADDRESS, borrowAmount, interestRate, returnDate, B, hubFork);

        Request memory request = gettersFacet.getRequest(1);
        assertEq(request.author, B);
        assertEq(request.collateralTokens[0], LINK_CONTRACT_ADDRESS);
        assertEq(request.amount, borrowAmount);
        assertEq(request.interest, interestRate);
        assertEq(request.returnDate, returnDate);

        vm.selectFork(avaxFork);
        vm.deal(owner, 1 ether);
        _dripLink(borrowAmount, owner, avaxFork);
        vm.startPrank(owner);
        ERC20Mock(AVAX_LINK_CONTRACT_ADDRESS).approve(address(avaxSpokeContract), borrowAmount);
        avaxSpokeContract.serviceRequest{value: 1 ether}(1, AVAX_LINK_CONTRACT_ADDRESS, borrowAmount);
        ccipLocalSimulatorFork.switchChainAndRouteMessage(hubFork);
        vm.stopPrank();
        uint256 balance = ERC20Mock(LINK_CONTRACT_ADDRESS).balanceOf(B);
        assertEq(balance, borrowAmount);

        Request memory _request = gettersFacet.getRequest(1);
        assert(_request.lender == owner);
        assert(_request.status == Status.SERVICED);
        assert(_request.amount == borrowAmount);
        assert(_request.interest == interestRate);
    }

    function test_xServiceLendingRequestSpokeToSpoke() public {
        uint256 amount = 100 ether;
        _dripLink(amount, B, arbFork);
        vm.startPrank(B);
        _xDepositCollateral(ARB_LINK_CONTRACT_ADDRESS, amount, arbFork, B);
        uint256 userBalance = gettersFacet.getAddressToCollateralDeposited(B, LINK_CONTRACT_ADDRESS);
        assertEq(userBalance, amount);

        vm.stopPrank();

        uint16 interestRate = 1000;
        uint256 duration = 30 days;
        uint256 returnDate = block.timestamp + duration;
        uint256 borrowAmount = 10 ether;

        _xCreateLendingRequest(ARB_LINK_CONTRACT_ADDRESS, borrowAmount, interestRate, returnDate, B, arbFork);

        Request memory request = gettersFacet.getRequest(1);
        assertEq(request.author, B);
        assertEq(request.collateralTokens[0], LINK_CONTRACT_ADDRESS);
        assertEq(request.amount, borrowAmount);
        assertEq(request.interest, interestRate);
        assertEq(request.returnDate, returnDate);

        vm.selectFork(avaxFork);
        vm.deal(owner, 1 ether);
        _dripLink(borrowAmount, owner, avaxFork);
        vm.startPrank(owner);
        ERC20Mock(AVAX_LINK_CONTRACT_ADDRESS).approve(address(avaxSpokeContract), borrowAmount);
        avaxSpokeContract.serviceRequest{value: 1 ether}(1, AVAX_LINK_CONTRACT_ADDRESS, borrowAmount);
        ccipLocalSimulatorFork.switchChainAndRouteMessage(hubFork);
        vm.stopPrank();

        Request memory _request = gettersFacet.getRequest(1);
        assert(_request.lender == owner);
        assert(_request.status == Status.SERVICED);
        assert(_request.amount == borrowAmount);
        assert(_request.interest == interestRate);

        ccipLocalSimulatorFork.switchChainAndRouteMessage(arbFork);

        uint256 balance = ERC20Mock(ARB_LINK_CONTRACT_ADDRESS).balanceOf(B);
        assertEq(balance, borrowAmount);
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
        assertEq(_listing.tokenAddress, LINK_CONTRACT_ADDRESS);
        assertEq(_listing.author, owner);
        assertEq(uint8(_listing.listingStatus), uint8(ListingStatus.OPEN));

        uint256 _balance = ERC20Mock(LINK_CONTRACT_ADDRESS).balanceOf(address(gettersFacet));
        assertEq(_balance, _amount);
    }

    function test_requestLoanFromListing() public {
        _xCreateLoanListing();
        _dripLink(200 ether, B, avaxFork);
        vm.deal(B, 10 ether);
        switchSigner(B);
        _xDepositCollateral(AVAX_LINK_CONTRACT_ADDRESS, 100 ether, avaxFork, B);

        vm.selectFork(arbFork);
        vm.deal(B, 10 ether);
        switchSigner(B);
        // uint256 balanceBeforeLoan = ERC20Mock(ARB_LINK_CONTRACT_ADDRESS).balanceOf(B);
        bytes32 messageId = arbSpokeContract.requestLoanFromListing{value: 1 ether}(1, 30 ether);
        assert(messageId != bytes32(0));

        ccipLocalSimulatorFork.switchChainAndRouteMessage(hubFork);
        ccipLocalSimulatorFork.switchChainAndRouteMessage(arbFork);

        uint256 balanceAfterLoan = ERC20Mock(ARB_LINK_CONTRACT_ADDRESS).balanceOf(B);
        assertEq(balanceAfterLoan, 30 ether);

        vm.selectFork(hubFork);
        LoanListing memory _listing = gettersFacet.getLoanListing(1);
        assertEq(_listing.amount, 50 ether - 30 ether);
        assertEq(uint8(_listing.listingStatus), uint8(ListingStatus.OPEN));

        Request memory _request = gettersFacet.getRequest(1);
        assertEq(_request.author, B);
        assertEq(_request.lender, owner);
        assertEq(_request.amount, 30 ether);
    }

    function test_repayLoan() public {
        _xCreateLoanListing();
        _dripLink(200 ether, B, avaxFork);
        vm.deal(B, 10 ether);
        switchSigner(B);
        _xDepositCollateral(AVAX_LINK_CONTRACT_ADDRESS, 100 ether, avaxFork, B);

        vm.selectFork(arbFork);
        vm.deal(B, 10 ether);
        switchSigner(B);

        bytes32 messageId = arbSpokeContract.requestLoanFromListing{value: 1 ether}(1, 30 ether);
        assert(messageId != bytes32(0));

        ccipLocalSimulatorFork.switchChainAndRouteMessage(hubFork);
        Request memory _request = gettersFacet.getRequest(1);

        ccipLocalSimulatorFork.switchChainAndRouteMessage(arbFork);

        vm.selectFork(avaxFork);
        vm.deal(B, 10 ether);
        switchSigner(B);
        ERC20Mock(AVAX_LINK_CONTRACT_ADDRESS).approve(address(avaxSpokeContract), _request.totalRepayment);
        messageId = avaxSpokeContract.repayLoan{value: 1 ether}(1, AVAX_LINK_CONTRACT_ADDRESS, _request.totalRepayment);
        assert(messageId != bytes32(0));
        ccipLocalSimulatorFork.switchChainAndRouteMessage(hubFork);

        uint256 _lenderBalance = gettersFacet.getAddressToAvailableBalance(owner, LINK_CONTRACT_ADDRESS);
        Request memory _requestAfterRepay = gettersFacet.getRequest(1);
        assertEq(uint8(_requestAfterRepay.status), uint8(Status.CLOSED));
        assertEq(_lenderBalance, 31185000000000000000); // totalRepayment - fees
    }

    function test_xCloseRequest() public {
        _dripLink(200 ether, owner, avaxFork);
        vm.deal(owner, 10 ether);
        switchSigner(owner);
        _xDepositCollateral(AVAX_LINK_CONTRACT_ADDRESS, 100 ether, avaxFork, B);
        _xCreateLendingRequest(ARB_LINK_CONTRACT_ADDRESS, 10 ether, 500, block.timestamp + 20 days, owner, arbFork);

        vm.selectFork(avaxFork);
        switchSigner(owner);
        avaxSpokeContract.closeRequest{value: 1 ether}(1);

        ccipLocalSimulatorFork.switchChainAndRouteMessage(hubFork);
        Request memory _request = gettersFacet.getRequest(1);
        assertEq(uint8(_request.status), uint8(Status.CLOSED));
    }

    function test_xCloseListing() public {
        _xCreateLoanListing();
        vm.selectFork(hubFork);
        uint256 _balanceBefore = gettersFacet.getAddressToAvailableBalance(owner, LINK_CONTRACT_ADDRESS);

        vm.selectFork(avaxFork);
        vm.deal(owner, 1 ether);
        switchSigner(owner);
        avaxSpokeContract.closeListingAd{value: 1 ether}(1);

        ccipLocalSimulatorFork.switchChainAndRouteMessage(hubFork);
        LoanListing memory _listing = gettersFacet.getLoanListing(1);
        uint256 _balanceAfter = gettersFacet.getAddressToAvailableBalance(owner, LINK_CONTRACT_ADDRESS);

        assertEq(uint8(_listing.listingStatus), uint8(ListingStatus.CLOSED));
        assertEq(_listing.amount, 0);
        assertEq(_balanceBefore + 50 ether, _balanceAfter);
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

        bytes32 messageId;

        if (_fork == hubFork) {
            protocolFacet.createLendingRequest(_amount, _interestRate, _returnDate, _token);
        }

        if (_fork == avaxFork) {
            messageId =
                avaxSpokeContract.createLendingRequest{value: 1 ether}(_amount, _interestRate, _returnDate, _token);
        }
        if (_fork == arbFork) {
            messageId =
                arbSpokeContract.createLendingRequest{value: 1 ether}(_amount, _interestRate, _returnDate, _token);
        }

        if (_fork != hubFork) {
            assert(messageId != bytes32(0));

            ccipLocalSimulatorFork.switchChainAndRouteMessage(hubFork);
        }
    }

    function _xCreateLoanListing() internal {
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
    }

    function _xCreateLoanListing(
        uint256 _amount,
        uint256 _returnDate,
        uint16 _interest,
        address _loanCurrency,
        uint256 _min_amount,
        uint256 _max_amount,
        address[] memory _whitelist,
        address _user,
        uint256 _fork
    ) internal {
        vm.selectFork(_fork);
        vm.deal(_user, 10 ether);
        vm.startPrank(_user);

        bytes32 messageId;

        if (_fork == hubFork) {
            protocolFacet.createLoanListing{value: 1 ether}(
                _amount, _min_amount, _max_amount, _returnDate, _interest, _loanCurrency, _whitelist
            );
        }

        if (_fork == avaxFork) {
            messageId = avaxSpokeContract.createLoanListing{value: 1 ether}(
                _amount, _min_amount, _max_amount, _returnDate, _interest, _loanCurrency, _whitelist
            );
        }
        if (_fork == arbFork) {
            messageId = arbSpokeContract.createLoanListing{value: 1 ether}(
                _amount, _min_amount, _max_amount, _returnDate, _interest, _loanCurrency, _whitelist
            );
        }

        if (_fork != hubFork) {
            assert(messageId != bytes32(0));

            ccipLocalSimulatorFork.switchChainAndRouteMessage(hubFork);
        }
    }
}
