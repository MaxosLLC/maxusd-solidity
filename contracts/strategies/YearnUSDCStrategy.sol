// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "../interfaces/IAddressManager.sol";
import "../interfaces/IStrategyBase.sol";
import "../interfaces/IStrategyAssetValue.sol";
import "../interfaces/IYearnUSDCVault.sol";

/**
 * @title YearnUSDCStrategy contract
 * @author Maxos
 */
contract YearnUSDCStrategy is IStrategyBase, IStrategyAssetValue, ReentrancyGuardUpgradeable {
  /*** Events ***/
  event InvestYearnUSDCStrategy(uint256 amount);
  event RedeemYearnUSDCStrategy(address indexed beneficiary, uint256 amount);

  /*** Constants ***/

  // Yearn USDC vault
  IYearnUSDCVault public constant USDC_VAULT = IYearnUSDCVault(0x5f18C75AbDAe578b483E5F43f12a39cF75b973a9);

  /*** Storage Properties ***/

  // Total shares for the investment of Yearn USDC vault
  uint256 public totalShares;

  // Address manager
  address public addressManager;

  /*** Contract Logic Starts Here */

  modifier onlyBanker() {
    require(msg.sender == IAddressManager(addressManager).bankerContract(), "No banker");
    _;
  }

  function initialize(address _addressManager) public initializer {
    __ReentrancyGuard_init();

    addressManager = _addressManager;
  }

  /**
   * @notice Invest token in Yearn USDC vault
   * @param _amount USD amount to invest
   */
  function invest(uint256 _amount) external override nonReentrant onlyBanker {
    ERC20 usdc = ERC20(IAddressManager(addressManager).USDC());

    require(_amount <= USDC_VAULT.availableDepositLimit(), "Limit overflow");
    require(_amount > 0 && _amount <= usdc.balanceOf(address(this)), "Invalid amount");

    usdc.approve(address(USDC_VAULT), _amount);
    uint256 shares = USDC_VAULT.deposit(_amount);
    totalShares += shares;

    emit InvestYearnUSDCStrategy(_amount);
  }

  /**
   * @notice Redeem token from Yearn USDC vault and return it to "beneficiary"
   * @param _beneficiary Redemption requestor
   * @param _amount USD amount to redeem
   */
  function redeem(address _beneficiary, uint256 _amount) external override nonReentrant onlyBanker {
    ERC20 usdc = ERC20(IAddressManager(addressManager).USDC());

    uint256 _shares = (_amount * 10**USDC_VAULT.decimals()) / USDC_VAULT.pricePerShare();
    require(_shares > 0 && _shares <= totalShares, "Invalid amount");

    uint256 amount = USDC_VAULT.withdraw(_shares);
    totalShares -= _shares;
    require(usdc.transfer(_beneficiary, amount));

    emit RedeemYearnUSDCStrategy(_beneficiary, amount);
  }

  /**
   * @notice Returns asset value of the strategy
   * @return (uint256) asset value of the strategy in USD, scaled by 10e2, Ex: 100 USD is represented by 10,000
   */
  function strategyAssetValue() external view override returns (uint256) {
    return (totalShares * USDC_VAULT.pricePerShare() * 100) / 10**USDC_VAULT.decimals();
  }
}
