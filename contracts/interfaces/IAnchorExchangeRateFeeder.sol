//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface IAnchorExchangeRateFeeder {
  function exchangeRateOf(address _token, bool _simulate) external view returns (uint256);
}
