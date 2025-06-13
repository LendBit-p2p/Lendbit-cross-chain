// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {LibDiamond} from "./libraries/LibDiamond.sol";
import {Constants} from "./utils/constants/Constant.sol";
import {IWeth} from "./interfaces/Iweth.sol";

/**
 * @title Lendbit VTokenVault
 * @author Lendbit Protocol
 * @notice ERC4626-compliant tokenized vault for Lendbit Protocol
 * @dev This vault integrates with the lending protocol to provide yield-bearing tokens
 */
contract VTokenVault is ERC4626, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Custom errors
    error InvalidAddressZero();
    error InvalidRateCanOnlyIncrease();
    error InvalidAmount();
    error VaultPaused();
    error OnlyDiamond();
    error InsufficientShares();
    error TransferNotAllowed();
    error NotWETHVault();
    error ETHTransferFailed();
    error OnlyWETHContract();

    /// @notice Protocol diamond address
    address public immutable diamond;

    /// @notice Exchange rate when last updated (asset per share, scaled by 1e18)
    uint256 public exchangeRateStored;

    /// @notice Last update timestamp
    uint256 public lastUpdateTimestamp;

    /// @notice Boolean indicating if vault is paused
    bool public paused;

    /// @dev Only diamond modifier
    modifier onlyDiamond() {
        if (msg.sender != diamond) revert OnlyDiamond();
        _;
    }

    /// @dev Not paused modifier
    modifier notPaused() {
        if (paused) revert VaultPaused();
        _;
    }

    /// @dev Update exchange rate
    modifier updateExchangeRates() {
        exchangeRateStored = _getCurrentExchangeRate();
        lastUpdateTimestamp = block.timestamp;
        _;
    }

    /// @dev Address zero check modifier
    modifier addressZeroCheck(address _addr) {
        if (_addr == address(0)) revert InvalidAddressZero();
        _;
    }

    /// @dev Valid amount check modifier
    modifier validAmount(uint256 _amount) {
        if (_amount == 0) revert InvalidAmount();
        _;
    }

    /**
     * @notice Construct a new VToken vault
     * @param _asset Underlying asset (use WETH address for ETH vaults)
     * @param _name Name of the vault token
     * @param _symbol Symbol of the vault token
     * @param _diamond Diamond contract address
     */
    constructor(
        address _asset,
        string memory _name,
        string memory _symbol,
        address _diamond
    )
        ERC4626(IERC20(_asset))
        ERC20(_name, _symbol)
        addressZeroCheck(_asset)
        addressZeroCheck(_diamond)
    {
        diamond = _diamond;
        exchangeRateStored = 1e18; // Initialize at 1:1
        lastUpdateTimestamp = block.timestamp;
    }

    /**
     * @notice Set pause state (only diamond)
     * @param _paused New pause state
     */
    function setPaused(bool _paused) external onlyDiamond {
        paused = _paused;
        emit PausedStateChanged(_paused);
    }

    /**
     * @notice Update exchange rate (only diamond)
     * @param _newExchangeRate New exchange rate
     */
    function updateExchangeRate(uint256 _newExchangeRate) external onlyDiamond {
        if (_newExchangeRate < exchangeRateStored)
            revert InvalidRateCanOnlyIncrease();
        exchangeRateStored = _newExchangeRate;
        lastUpdateTimestamp = block.timestamp;
        emit ExchangeRateUpdated(_newExchangeRate);
    }

    /**
     * @notice Calculate current exchange rate with interest accrual
     * @return Current exchange rate (assets per share)
     */
    function _getCurrentExchangeRate() internal view returns (uint256) {
        return ILendbitProtocol(diamond).getVaultExchangeRate(asset());
    }

    /**
     * @notice Get total assets managed by the vault
     * @return Total amount of underlying assets
     */
    function totalAssets() public view override returns (uint256) {
        return ILendbitProtocol(diamond).getVaultTotalAssets(asset());
    }

    /**
     * @notice Convert assets to shares based on current exchange rate
     * @param assets Amount of assets
     * @return shares Amount of shares
     */
    function convertToShares(
        uint256 assets
    ) public view override returns (uint256 shares) {
        uint256 supply = totalSupply();

        if (supply == 0) {
            return assets; // 1:1 ratio for first deposit
        }

        uint256 rate = _getCurrentExchangeRate();
        return (assets * 1e18) / rate;
    }

    /**
     * @notice Convert shares to assets based on current exchange rate
     * @param shares Amount of shares
     * @return assets Amount of assets
     */
    function convertToAssets(
        uint256 shares
    ) public view override returns (uint256 assets) {
        uint256 rate = _getCurrentExchangeRate();
        return (shares * rate) / 1e18;
    }

    /**
     * @notice Deposit ERC20 assets into the vault
     * @param assets Amount of assets to deposit
     * @param receiver Address receiving the shares
     * @return shares Amount of shares minted
     */
    function deposit(
        uint256 assets,
        address receiver
    )
        public
        override
        nonReentrant
        notPaused
        updateExchangeRates
        addressZeroCheck(receiver)
        validAmount(assets)
        returns (uint256 shares)
    {
        // Calculate shares
        shares = convertToShares(assets);
        if (shares == 0) revert InvalidAmount();

        // Transfer assets from sender to this vault
        IERC20(asset()).safeTransferFrom(msg.sender, address(this), assets);

        // Transfer assets to diamond for lending
        IERC20(asset()).safeTransfer(diamond, assets);

        // Notify diamond about deposit
        ILendbitProtocol(diamond).notifyVaultDeposit(
            asset(),
            assets,
            receiver,
            false
        );

        // Mint shares to receiver
        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);
        return shares;
    }

    /**
     * @notice Deposit ETH and receive shares (only for WETH vaults)
     * @param receiver Address receiving the shares
     * @return shares Amount of shares minted
     */
    function depositETH(
        address receiver
    )
        external
        payable
        nonReentrant
        notPaused
        updateExchangeRates
        addressZeroCheck(receiver)
        returns (uint256 shares)
    {
        if (asset() != Constants.WETH) revert NotWETHVault();
        if (msg.value == 0) revert InvalidAmount();

        // Wrap ETH to WETH
        IWeth(Constants.WETH).deposit{value: msg.value}();

        // Calculate shares
        shares = convertToShares(msg.value);
        if (shares == 0) revert InvalidAmount();

        // Transfer WETH to diamond
        IERC20(Constants.WETH).safeTransfer(diamond, msg.value);

        // Notify diamond about deposit
        ILendbitProtocol(diamond).notifyVaultDeposit(
            asset(),
            msg.value,
            receiver,
            false
        );

        // Mint shares
        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, msg.value, shares);
        return shares;
    }

    /**
     * @notice Withdraw ERC20 assets from the vault
     * @param assets Amount of assets to withdraw
     * @param receiver Address receiving the assets
     * @param owner Owner of the shares
     * @return shares Amount of shares burned
     */
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    )
        public
        override
        nonReentrant
        updateExchangeRates
        addressZeroCheck(receiver)
        addressZeroCheck(owner)
        validAmount(assets)
        returns (uint256 shares)
    {
        // Calculate shares needed
        shares = convertToShares(assets);
        if (shares == 0) revert InvalidAmount();

        // Check allowance if not owner
        if (msg.sender != owner) {
            _spendAllowance(owner, msg.sender, shares);
        }

        // Check if owner has enough shares
        if (balanceOf(owner) < shares) revert InsufficientShares();

        // Burn shares first
        _burn(owner, shares);

        // Notify diamond about withdrawal - diamond will transfer assets to receiver
        ILendbitProtocol(diamond).notifyVaultWithdrawal(
            asset(),
            assets,
            receiver,
            true
        );

        emit Withdraw(msg.sender, receiver, owner, assets, shares);
        return shares;
    }

    /**
     * @notice Withdraw ETH from WETH vault
     * @param assets Amount of assets to withdraw
     * @param receiver Address receiving the ETH
     * @param owner Owner of the shares
     * @return shares Amount of shares burned
     */
    function withdrawETH(
        uint256 assets,
        address payable receiver,
        address owner
    )
        external
        nonReentrant
        updateExchangeRates
        addressZeroCheck(receiver)
        addressZeroCheck(owner)
        validAmount(assets)
        returns (uint256 shares)
    {
        if (asset() != Constants.WETH) revert NotWETHVault();

        // Calculate shares
        shares = convertToShares(assets);
        if (shares == 0) revert InvalidAmount();

        // Check allowance
        if (msg.sender != owner) {
            _spendAllowance(owner, msg.sender, shares);
        }

        // Check balance
        if (balanceOf(owner) < shares) revert InsufficientShares();

        // Burn shares
        _burn(owner, shares);

        // Notify diamond - diamond will transfer WETH back to this vault
        ILendbitProtocol(diamond).notifyVaultWithdrawal(
            asset(),
            assets,
            address(this),
            true
        );

        // Unwrap WETH to ETH and send to receiver
        IWeth(Constants.WETH).withdraw(assets);
        (bool success, ) = receiver.call{value: assets}("");
        if (!success) revert ETHTransferFailed();

        emit Withdraw(msg.sender, receiver, owner, assets, shares);
        return shares;
    }

    /**
     * @notice Mint shares for a user (only diamond)
     * @param receiver Address to mint shares for
     * @param shares Amount of shares to mint
     */
    function mintFor(
        address receiver,
        uint256 shares
    ) external onlyDiamond addressZeroCheck(receiver) validAmount(shares) {
        _mint(receiver, shares);
    }

    /**
     * @notice Burn shares from a user (only diamond)
     * @param owner Address to burn shares from
     * @param shares Amount of shares to burn
     */
    function burnFor(
        address owner,
        uint256 shares
    ) external onlyDiamond addressZeroCheck(owner) validAmount(shares) {
        if (balanceOf(owner) < shares) revert InsufficientShares();
        _burn(owner, shares);
    }

    /**
     * @notice Override transfer to notify protocol
     * @param to Recipient address
     * @param amount Amount to transfer
     * @return success Whether transfer was successful
     */
    function transfer(
        address to,
        uint256 amount
    )
        public
        override(ERC20, IERC20)
        nonReentrant
        addressZeroCheck(to)
        validAmount(amount)
        returns (bool)
    {
        // Convert shares to asset amount for notification
        uint256 assetAmount = convertToAssets(amount);

        // Notify protocol about transfer
        if (
            !ILendbitProtocol(diamond).notifyVaultTransfer(
                asset(),
                assetAmount,
                msg.sender,
                to
            )
        ) {
            revert TransferNotAllowed();
        }

        return super.transfer(to, amount);
    }

    /**
     * @notice Override transferFrom to notify protocol
     * @param from Sender address
     * @param to Recipient address
     * @param amount Amount to transfer
     * @return success Whether transfer was successful
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    )
        public
        override(ERC20, IERC20)
        nonReentrant
        addressZeroCheck(from)
        addressZeroCheck(to)
        validAmount(amount)
        returns (bool)
    {
        // Convert shares to asset amount for notification
        uint256 assetAmount = convertToAssets(amount);

        // Notify protocol about transfer
        if (
            !ILendbitProtocol(diamond).notifyVaultTransfer(
                asset(),
                assetAmount,
                from,
                to
            )
        ) {
            revert TransferNotAllowed();
        }

        return super.transferFrom(from, to, amount);
    }

    /**
     * @notice Check if this is a WETH vault
     * @return isWETH True if this vault handles WETH/ETH
     */
    function isWETHVault() external view returns (bool) {
        return asset() == Constants.WETH;
    }

    /**
     * @notice Get current exchange rate
     * @return rate Current exchange rate
     */
    function getCurrentExchangeRate() external view returns (uint256) {
        return _getCurrentExchangeRate();
    }

    /**
     * @dev Receive function to handle ETH (only for WETH vaults and only from WETH contract)
     */
    receive() external payable {
        if (asset() != Constants.WETH) revert NotWETHVault();
        if (msg.sender != Constants.WETH) revert OnlyWETHContract();
    }

    // Events
    event PausedStateChanged(bool paused);
    event ExchangeRateUpdated(uint256 newRate);
}

/**
 * @notice Interface for Lendbit Protocol Diamond
 */
interface ILendbitProtocol {
    function notifyVaultDeposit(
        address asset,
        uint256 amount,
        address depositor,
        bool transferAssets
    ) external;
    function notifyVaultWithdrawal(
        address asset,
        uint256 amount,
        address receiver,
        bool transferAssets
    ) external;
    function notifyVaultTransfer(
        address asset,
        uint256 amount,
        address sender,
        address receiver
    ) external returns (bool);
    function getVaultExchangeRate(
        address asset
    ) external view returns (uint256);
    function getVaultTotalAssets(address asset) external view returns (uint256);
}
