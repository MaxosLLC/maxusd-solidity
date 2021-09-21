//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface IStrategyBase {
  function invest(uint256 amount) external;

  function redeem(address beneficiary, uint256 amount) external;

  function withdrawAvailableAmount(address beneficiary) external;

  function emergencyWithdraw(address beneficiary, address token) external;
}
