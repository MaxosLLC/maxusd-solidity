//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface IAnchorConversionPool {
  function deposit(uint256 _amount) external;

  function redeem(uint256 _amount) external;
}
