// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "../interfaces/IStrategyBase.sol";
import "../interfaces/IStrategyAssetValue.sol";
import "../interfaces/IYearnUSDCVault.sol";

/**
 * @title YearnUSDCStrategy contract
 * @author Maxos
 */
contract YearnUSDCStrategy is IStrategyBase, IStrategyAssetValue, ReentrancyGuardUpgradeable {
  using SafeERC20 for IERC20;

  // Total shares for the investment of Yearn USDC vault
  uint256 public totalShares;

  // Yearn USDC vault interacted with the strategy
  IYearnUSDCVault public constant USDC_VAULT = IYearnUSDCVault(0x5f18C75AbDAe578b483E5F43f12a39cF75b973a9);

  // USDC token interacted with the strategy
  IERC20 public constant USDC_TOKEN = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

  // Decimal number for total shares
  uint256 public constant DECIMALS = 2;

  function initialize() public initializer {
    totalShares = 0;
  }

  /**
   * @notice Invest token into Yearn USDC vault
   * @dev Token is transferred from the banker
   * @param amount {uint256} USD amount to invest
   */
  function invest(uint256 amount) external override nonReentrant {
    _deposit(amount);
  }

  /**
   * @notice Redeem token from Yearn USDC vault and return it to "beneficiary"
   * @dev Transfer min(strategy balance, redemption amount) amount to requestor
   * @param beneficiary {address} Redemption requestor
   * @param amount {uint256} USD amount to redeem
   */
  function redeem(address beneficiary, uint256 amount) external override nonReentrant {
    _withdraw(amount, beneficiary);
  }

  /**
   * @notice Returns asset value of the strategy
   * @return (uint256) asset value of the strategy in USD, scaled by 10e2, Ex: 100 USD is represented by 10,000
   */
  function strategyAssetValue() external view override returns (uint256) {
    return (totalShares * USDC_VAULT.pricePerShare() * 10**DECIMALS) / 10**USDC_VAULT.decimals();
  }

  function _deposit(uint256 _amount) internal returns (uint256) {
    require(_amount > 0, "amount should be above zero");
    require(_amount <= USDC_VAULT.availableDepositLimit(), "amount should be lower than limit");
    require(_amount <= USDC_TOKEN.balanceOf(address(this)), "amount should be lower than balance");

    USDC_TOKEN.approve(address(USDC_VAULT), _amount);
    uint256 _shares = USDC_VAULT.deposit(_amount);
    totalShares += _shares;

    return _amount;
  }

  function _withdraw(uint256 _amount, address _beneficiary) internal returns (uint256) {
    uint256 _shares = (_amount * (10**USDC_VAULT.decimals())) / USDC_VAULT.pricePerShare();
    require(_shares > 0, "shares should be above zero");
    require(_shares <= totalShares, "shares should be lower than total shares");
    _amount = USDC_VAULT.withdraw(_shares);
    totalShares -= _shares;
    USDC_TOKEN.safeTransfer(_beneficiary, _amount);

    return _amount;
  }
}
