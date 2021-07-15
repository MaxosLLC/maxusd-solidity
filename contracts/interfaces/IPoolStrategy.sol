//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface IPoolStrategy {
  function getAssetValue() external returns (uint256);

  function invest(uint256 amount) external;

  function redeem(address beneficiary, uint256 amount) external;
}
