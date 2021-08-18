//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface IOwnerOnlyApprover {
  function checkTransfer(address _from, address _to) external view returns (bool);
}
