//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface IAnchorVault {
  function depositStable(uint256 _amount) external;

  function depositStable(address _operator, uint256 _amount) external;

  function redeemStable(uint256 _amount) external;

  function redeemStable(address _operator, uint256 _amount) external;
}
