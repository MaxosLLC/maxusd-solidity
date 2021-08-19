// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "../interfaces/IStrategyBase.sol";
import "../interfaces/IStrategyAssetValue.sol";
import "../interfaces/IAnchorVault.sol";
import "../interfaces/IAnchorExchangeRateFeeder.sol";

/**
 * @title AnchorStrategy contract
 * @author Maxos
 */
contract AnchorStrategy is IStrategyBase, IStrategyAssetValue, ReentrancyGuardUpgradeable {
  using SafeERC20 for IERC20;

  // Total shares for the investment of Anchor vault
  uint256 public totalShares;

  // Anchor Router
  IAnchorVault public constant ANCHOR_ROUTER = IAnchorVault(0xcEF9E167d3f8806771e9bac1d4a0d568c39a9388 );

  // Anchor ExchangeRateFeeder
  IAnchorExchangeRateFeeder public constant ANCHOR_EXCHANGERATEFEEDER = IAnchorExchangeRateFeeder(0xd7c4f5903De8A256a1f535AC71CeCe5750d5197a );

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
   * @notice Redeem token from Anchor vault and return it to "beneficiary"
   * @dev Transfer min(strategy balance, redemption amount) amount to requestor
   * @param beneficiary {address} Redemption requestor
   * @param amount {uint256} USD amount to redeem
   */
  function redeem(address beneficiary, uint256 amount) external override nonReentrant {
    _withdraw(amount, beneficiary);
  }

  /**
   * @notice Returns asset value of the strategy form ANCHOR_EXCHANGERATEFEEDER contract
   * @return (uint256) asset value of the strategy in USD, scaled by 10e2, Ex: 100 USD is represented by 10,000
   */
  function strategyAssetValue() external view override returns (uint256) {
    return 0;
  }

  function _deposit(uint256 _amount) internal returns (uint256) {

    return _amount;
  }

  function _withdraw(uint256 _amount, address _beneficiary) internal returns (uint256) {

    return _amount;
  }
}
