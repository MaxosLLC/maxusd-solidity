//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface IStrategy {
  function getAssetValue() external returns (uint256);

  function invest(uint256 amount) external;

  function redeem(address beneficiary, uint256 amount) external;
}
