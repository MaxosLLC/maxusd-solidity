//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
interface IYearnUSDCVault {
  function deposit(uint256 _amount) external returns(uint256);
  function deposit(uint256 _amount, address recipient) external returns(uint256);
  function withdraw(uint256 _maxShares) external returns(uint256);
  function withdraw(uint256 _maxShares, address recipient) external returns(uint256);

  function balanceOf(address arg0) external view returns(uint256);
  function totalAssets() external view returns(uint256);
  function maxAvailableShares() external view returns(uint256);
  function availableDepositLimit() external view returns(uint256);
}