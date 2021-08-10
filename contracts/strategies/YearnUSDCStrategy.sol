// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "../interfaces/IStrategyBase.sol";
import "../interfaces/IStrategyAssetValue.sol";
import "../interfaces/IYearnUSDCVault.sol";

contract YearnUSDCStrategy is IStrategyBase, IStrategyAssetValue, ReentrancyGuard {
  using SafeERC20 for IERC20;

  IYearnUSDCVault public yVault;
  IERC20 public baseToken;

  uint256 public totalShares = 0;

  constructor(address _vault, address _token) {
    require(IYearnUSDCVault(_vault).token() == _token, "YUS: vault and base token are not matched");
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
    return totalShares * yVault.pricePerShare();
  }

  function _deposit(uint256 _amount) internal returns (uint256) {
    require(_amount > 0, "YUS: invalid deposit amount - 1");
    require(_amount < yVault.availableDepositLimit(), "YUS: invalid deposit amount - 2");
    require(_amount < baseToken.balanceOf(address(this)), "YUS: invalid deposit amount - 3");

    uint256 _shares = yVault.deposit(_amount);
    totalShares += _shares;

    return _amount;
  }

  function _withdraw(uint256 _shares, address _recipient) internal returns (uint256) {
    require(_shares > 0, "YUS: invalid withdraw amount - 1");
    require(_shares < totalShares, "YUS: invalid withdraw amount - 2");
    uint256 _amount = yVault.withdraw(_shares);
    totalShares -= _shares;
    baseToken.safeTransfer(address(_recipient), _amount);

    return _amount;
  }
}
