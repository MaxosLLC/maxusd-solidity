// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./Strategy.sol";
import "../interfaces/IYearnUSDCVault.sol";

/**
 * @title YearnUSDCStrategy contract
 * @author Maxos
 */
contract YearnUSDCStrategy is Strategy {
  /*** Events ***/
  event InvestYearnUSDCStrategy(uint256 amount);
  event RedeemYearnUSDCStrategy(address indexed beneficiary, uint256 amount);

  /*** Constants ***/

  // Yearn USDC vault
  IYearnUSDCVault private yearnUSDCVault;

  /*** Storage Properties ***/

  // Total shares for the investment of Yearn USDC vault
  uint256 public totalShares;

  function initialize(address _addressManager) public initializer {
    __Strategy_init(_addressManager, 0x5f18C75AbDAe578b483E5F43f12a39cF75b973a9);

    yearnUSDCVault = IYearnUSDCVault(vault);
  }

  /**
   * @notice Invest token in Yearn USDC vault
   * @param _amount USDC amount to invest
   */
  function invest(uint256 _amount) external override nonReentrant onlyBanker {
    require(_amount <= yearnUSDCVault.availableDepositLimit(), "Limit overflow");
    require(_amount > 0 && _amount <= usdc.balanceOf(address(this)), "Invalid amount");

    usdc.approve(address(yearnUSDCVault), 0);
    usdc.approve(address(yearnUSDCVault), _amount);
    uint256 shares = yearnUSDCVault.deposit(_amount);
    totalShares += shares;

    emit InvestYearnUSDCStrategy(_amount);
  }

  /**
   * @notice Redeem token from Yearn USDC vault and return it to beneficiary
   * @param _beneficiary Beneficiary address
   * @param _amount USDC amount to redeem
   */
  function redeem(address _beneficiary, uint256 _amount) external override nonReentrant onlyBanker {
    uint256 _shares = (_amount * 10**yearnUSDCVault.decimals()) / yearnUSDCVault.pricePerShare();
    require(_shares > 0 && _shares <= totalShares, "Invalid amount");

    uint256 amount = yearnUSDCVault.withdraw(_shares);
    totalShares -= _shares;
    require(usdc.transfer(_beneficiary, amount));

    emit RedeemYearnUSDCStrategy(_beneficiary, amount);
  }

  /**
   * @notice Returns asset value of the strategy
   * @dev total asset value = available amount + invested amount
   * @return (uint256) total asset value of the strategy in USDC
   */
  function strategyAssetValue() external view override returns (uint256) {
    uint256 availableAmount = usdc.balanceOf(address(this));
    uint256 investedAmount = totalShares * yearnUSDCVault.pricePerShare() / 10**yearnUSDCVault.decimals();

    return availableAmount + investedAmount;
  }
}
