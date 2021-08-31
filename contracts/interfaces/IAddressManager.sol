//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface IAddressManager {
  function manager() external view returns (address);

  function bankerContract() external view returns (address);

  function treasuryContract() external view returns (address);

  function maxUSD() external view returns (address);

  function maxBanker() external view returns (address);

  function USDC() external view returns (address);

  function investor() external view returns (address);

  function anchorContract() external view returns (address);
  
  function yearnUSDCStrategy() external view returns (address);
}
