// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "../Base.t.sol";

contract LiquidityPoolFacetTest is Base {

    function setUp() public override {
        super.setUp();
    }

    function test_depositInto_LiquidityPool() public {
        uint256 amount = 100 ether;

        _deployVault(USDT_CONTRACT_ADDRESS, "USDT-VAULT", "VUSDT");
        _intializeProtocolPool(USDT_CONTRACT_ADDRESS);
        _depositIntoLiquidityPool(USDT_CONTRACT_ADDRESS, amount);
        

        uint256 userBalance = liquidityPoolFacet.getUserPoolDeposit(
            owner,
            USDT_CONTRACT_ADDRESS
        );

        assertEq(userBalance, amount);
        assertEq(
            ERC20Mock(USDT_CONTRACT_ADDRESS).balanceOf(address(liquidityPoolFacet)),
            amount
        );
    }

    function test_withdrawFrom_LiquidityPool() public {
        uint256 amount = 100 ether;
         _deployVault(USDT_CONTRACT_ADDRESS, "USDT-VAULT", "VUSDT");
        _intializeProtocolPool(USDT_CONTRACT_ADDRESS);
        _depositIntoLiquidityPool(USDT_CONTRACT_ADDRESS, amount);

        

        uint256 userBalance = liquidityPoolFacet.getUserPoolDeposit(
            owner,
            USDT_CONTRACT_ADDRESS
        );

        assertEq(userBalance, amount);
        assertEq(
            ERC20Mock(USDT_CONTRACT_ADDRESS).balanceOf(address(liquidityPoolFacet)),
            amount
        );

        liquidityPoolFacet.withdraw(
            USDT_CONTRACT_ADDRESS,
            amount
        );
        uint256 afterWithdrawBalance = liquidityPoolFacet
            .getUserPoolDeposit(owner, USDT_CONTRACT_ADDRESS);
        assertEq(afterWithdrawBalance, 0);

    }


}