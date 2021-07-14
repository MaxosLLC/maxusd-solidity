//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface IAddressManager {
  function manager() external view returns (address);

  function bankerContract() external view returns (address);

  function treasuryContract() external view returns (address);
}
