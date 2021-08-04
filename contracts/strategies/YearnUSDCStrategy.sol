//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "../interfaces/IYearnUSDCVault.sol";
import "./Strategy.sol";

contract YearnUSDCStrategy is Strategy {
  address public constant YV_USDC_VAULT = 0x5f18C75AbDAe578b483E5F43f12a39cF75b973a9;

  function initialize(address _addressManager) public initializer {
    super.initialize(_addressManager, YV_USDC_VAULT);
  }

  function invest(uint256 _amount) external override {
    IYearnUSDCVault yvVault = IYearnUSDCVault(vault);
    require(_amount > 0 && _amount <= yvVault.availableDepositLimit(), "invalid invest amount");
    yvVault.deposit(_amount, msg.sender);
  }

  function redeem(address beneficiary, uint256 amount) external override {
    IYearnUSDCVault yvVault = IYearnUSDCVault(vault);
    require(amount > 0 && amount <= yvVault.balanceOf(msg.sender), "invalid redeem amount");
    yvVault.withdraw(amount, beneficiary);
  }
}