// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "../interfaces/IYearnUSDCVault.sol";
import "./Collateral.sol";

contract CollateralSingleYearnVaultStrategy is Ownable, Pausable, ReentrancyGuard {
  using SafeERC20 for IERC20;

  IYearnUSDCVault public yVault;
  Collateral public collateral;

  uint256 public totalShares = 0;

  modifier onlyCollateral() {
    require(msg.sender == address(collateral), "CSYVS: caller should be collateral");
    _;
  }

  constructor(address _vault, address _collateral) {
    require(
      IYearnUSDCVault(_vault).token() == address(Collateral(_collateral).baseToken()),
      "CSYVS: vault and collateral are not matched"
    );
    yVault = IYearnUSDCVault(_vault);
    collateral = Collateral(_collateral);
    totalShares = 0;
  }

  function deposit(uint256 _amount) external nonReentrant whenNotPaused returns (uint256) {
    uint256 deposited = _deposit(_amount);
    return deposited;
  }

  function withdraw(uint256 _amount) external onlyCollateral nonReentrant returns (uint256) {
    uint256 withdrawal = _withdraw(_amount);
    return withdrawal;
  }

  function pause() external {
    _pause();
  }

  function unpause() external {
    _unpause();
  }

  function withdrawAll() external onlyOwner {
    yVault.withdraw(totalShares);
    totalShares = 0;
  }

  function migrate(address _vault) external onlyOwner {
    require(_vault != address(0), "CSYVS: invalid new vault");
    require(IYearnUSDCVault(_vault).token() == address(currency()), "CSYVS: vault not matched");

    uint256 _before = currency().balanceOf(address(this));
    yVault.withdraw(totalShares);
    uint256 _after = currency().balanceOf(address(this));
    yVault = IYearnUSDCVault(_vault);
    yVault.deposit(_after - _before);
  }

  function totalValue() external view returns (uint256) {
    // TODO Need to declare total value
  }

  function currency() public view returns (IERC20) {
    return collateral.baseToken();
  }

  function _deposit(uint256 _amount) internal returns (uint256) {
    require(_amount > 0 && _amount <= yVault.availableDepositLimit(), "CSYVS: invalid deposit amount");
    uint256 _before = currency().balanceOf(address(this));
    currency().safeTransferFrom(msg.sender, address(this), _amount);
    uint256 _after = currency().balanceOf(address(this));
    _amount = _after - _before;

    yVault.deposit(_amount);
    totalShares += _amount;

    return _amount;
  }

  function _withdraw(uint256 _amount) internal returns (uint256) {
    require(_amount > 0 && _amount <= yVault.balanceOf(msg.sender), "CSYVS: invalid withdraw amount");
    uint256 _before = currency().balanceOf(address(this));
    yVault.withdraw(_amount);
    uint256 _after = currency().balanceOf(address(this));
    _amount = _after - _before;
    currency().safeTransfer(address(collateral), _amount);
    totalShares -= _amount;

    return _amount;
  }
}
