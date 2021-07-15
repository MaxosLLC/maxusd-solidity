//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface ITreasury {
  function deposit(address token, uint256 amount) external;

  function withdraw(address token, uint256 amount) external;

  function allowToken(address token) external;

  function disallowToken(address token) external;
}
