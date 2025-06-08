// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../Base.t.sol";

contract SharedFacetTest is Base {
    function setUp() public override {
        super.setUp();
    }

    function test_depositCollateral() public {
        uint256 amount = 100 ether;
        _depositCollateral(USDT_CONTRACT_ADDRESS, amount);

        uint256 userBalance = gettersFacet.getAddressToCollateralDeposited(
            owner,
            USDT_CONTRACT_ADDRESS
        );

        assertEq(userBalance, amount);
        assertEq(
            ERC20Mock(USDT_CONTRACT_ADDRESS).balanceOf(address(sharedFacet)),
            amount
        );
    }

    function test_withdrawCollateral() public {
        uint256 amount = 100 ether;
        _depositCollateral(USDT_CONTRACT_ADDRESS, amount);

        uint256 userBalance = gettersFacet.getAddressToCollateralDeposited(
            owner,
            USDT_CONTRACT_ADDRESS
        );

        assertEq(userBalance, amount);

        sharedFacet.withdrawCollateral(USDT_CONTRACT_ADDRESS, amount);

        uint256 afterWithdrawBalance = gettersFacet
            .getAddressToCollateralDeposited(owner, USDT_CONTRACT_ADDRESS);

        assertEq(afterWithdrawBalance, 0);
        assertEq(
            ERC20Mock(USDT_CONTRACT_ADDRESS).balanceOf(address(sharedFacet)),
            0
        );
    }

    function test_depositNativeCollateral() public {
        uint256 amount = 100 ether;
        _depositNativeCollateral(owner, amount);

        uint256 userBalance = gettersFacet.getAddressToCollateralDeposited(
            owner,
            ETH_CONTRACT_ADDRESS
        );

        assertEq(userBalance, amount);
        assertEq(address(sharedFacet).balance, amount);
    }

    function test_withdrawNativeCollateral() public {
        uint256 amount = 100 ether;
        _depositNativeCollateral(owner, amount);

        sharedFacet.withdrawCollateral(ETH_CONTRACT_ADDRESS, amount);

        uint256 userBalance = gettersFacet.getAddressToCollateralDeposited(
            owner,
            ETH_CONTRACT_ADDRESS
        );

        assertEq(userBalance, 0);
        assertEq(address(sharedFacet).balance, 0);
    }
}
