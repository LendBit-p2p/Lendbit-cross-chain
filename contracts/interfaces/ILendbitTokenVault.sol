// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface ILendbitTokenVault {
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares);
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);
    function maxWithdraw(address owner) external view returns (uint256);
    function mintFor(address receiver, uint256 shares) external;
    function burnFor(address owner, uint256 shares) external;
    function updateExchangeRate(uint256 _newExchangeRate) external;
}
