//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface ITransferApprover {
  function checkTransfer(address _from, address _to) external view returns (bool);
}
