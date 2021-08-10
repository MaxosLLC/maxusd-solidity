// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import "../interfaces/IStrategyBase.sol";
import "../interfaces/IStrategyAssetValue.sol";
import "../interfaces/IYearnUSDCVault.sol";

contract YearnUSDCStrategy is IStrategyBase, IStrategyAssetValue, Ownable, Pausable, ReentrancyGuard {
  using SafeERC20 for IERC20;

  IYearnUSDCVault public yVault;
  IERC20 public baseToken;
  AggregatorV3Interface internal priceFeed;

  uint256 public totalDeposits = 0;

  address public constant CHAINLINK_USDC_USD = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;

  constructor(address _vault, address _token) {
    require(IYearnUSDCVault(_vault).token() == _token, "YUS: vault and base token are not matched");
    yVault = IYearnUSDCVault(_vault);
    baseToken = IERC20(_token);
    priceFeed = AggregatorV3Interface(CHAINLINK_USDC_USD);
    totalDeposits = 0;
  }

  function invest(uint256 amount) external override nonReentrant whenNotPaused {
    _deposit(amount);
  }

  function redeem(address beneficiary, uint256 amount) external override nonReentrant whenNotPaused {
    _withdraw(amount, beneficiary);
  }

  function strategyAssetValue() external view override returns (uint256) {
    return (totalDeposits * uint256(_getThePrice())) / 8;
  }

  function pause() external {
    _pause();
  }

  function unpause() external {
    _unpause();
  }

  function migrate(address _vault) external onlyOwner {
    require(_vault != address(0), "CSYVS: invalid new vault");
    require(IYearnUSDCVault(_vault).token() == address(baseToken), "YUS: vault not matched");

    uint256 _before = baseToken.balanceOf(address(this));
    yVault.withdraw(totalDeposits);
    uint256 _after = baseToken.balanceOf(address(this));
    yVault = IYearnUSDCVault(_vault);
    yVault.deposit(_after - _before);
  }

  function _deposit(uint256 _amount) internal returns (uint256) {
    require(_amount > 0 && _amount <= yVault.availableDepositLimit(), "YUS: invalid deposit amount");
    uint256 _before = baseToken.balanceOf(address(this));
    baseToken.safeTransferFrom(msg.sender, address(this), _amount);
    uint256 _after = baseToken.balanceOf(address(this));
    _amount = _after - _before;

    yVault.deposit(_amount);
    totalDeposits += _amount;

    return _amount;
  }

  function _withdraw(uint256 _amount, address _recipient) internal returns (uint256) {
    require(_amount > 0 && _amount <= yVault.balanceOf(msg.sender), "YUS: invalid withdraw amount");
    uint256 _before = baseToken.balanceOf(address(this));
    yVault.withdraw(_amount);
    uint256 _after = baseToken.balanceOf(address(this));
    _amount = _after - _before;
    baseToken.safeTransfer(address(_recipient), _amount);
    totalDeposits -= _amount;

    return _amount;
  }

  function _getThePrice() internal view returns (int256) {
    (, int256 price, , , ) = priceFeed.latestRoundData();
    return price;
  }
}
