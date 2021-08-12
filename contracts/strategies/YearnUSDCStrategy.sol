// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "../interfaces/IStrategyBase.sol";
import "../interfaces/IStrategyAssetValue.sol";
import "../interfaces/IYearnUSDCVault.sol";

contract YearnUSDCStrategy is IStrategyBase, IStrategyAssetValue, Initializable, ReentrancyGuardUpgradeable {
  using SafeERC20 for IERC20;

  IYearnUSDCVault public yVault;
  IERC20 public baseToken;

  uint256 public totalShares = 0;

  function initializable(address _vault, address _token) public initializer {
    __ReentrancyGuard_init();
    require(IYearnUSDCVault(_vault).token() == _token, "=> vault and base token should be matched");
    yVault = IYearnUSDCVault(_vault);
    baseToken = IERC20(_token);
    totalShares = 0;
  }

  function invest(uint256 amount) external override nonReentrant {
    _deposit(amount);
  }

  function redeem(address beneficiary, uint256 amount) external override nonReentrant {
    _withdraw(amount, beneficiary);
  }

  function strategyAssetValue() external view override returns (uint256) {
    return (totalShares * yVault.pricePerShare()) / 10**yVault.decimals();
  }

  function _deposit(uint256 _amount) internal returns (uint256) {
    require(_amount > 0, "=> amount should be above zero");
    require(_amount < yVault.availableDepositLimit(), "=> amount should be lower than limit");
    require(_amount < baseToken.balanceOf(address(this)), "=> amout should be lower than balance");

    uint256 _shares = yVault.deposit(_amount);
    totalShares += _shares;

    return _amount;
  }

  function _withdraw(uint256 _amount, address _beneficiary) internal returns (uint256) {
    uint256 _shares = (_amount * (10**yVault.decimals())) / yVault.pricePerShare();
    require(_shares > 0, "=> shares should be above zero");
    require(_shares < totalShares, "=> shares should be lower than total shares");
    _amount = yVault.withdraw(_shares);
    totalShares -= _shares;
    baseToken.safeTransfer(_beneficiary, _amount);

    return _amount;
  }
}
