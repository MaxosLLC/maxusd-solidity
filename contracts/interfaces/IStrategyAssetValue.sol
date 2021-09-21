//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface IStrategyAssetValue {
  function strategyAssetValue() external view returns (uint256);
  
  function strategyAvailableAmount() external view returns (uint256);
}
