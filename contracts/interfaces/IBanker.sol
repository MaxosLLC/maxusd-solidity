//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface IBanker {
  // MaxUSD redemption queue to the strategy
  struct RedemptionRequest {
    address requestor; // redemption requestor
    uint256 redeemAmount; // USD amount to redeem
    uint256 availableAmount; // USD amount available
    uint256 requestedAt; // redemption request time
  }

  function mintDepositPercentage() external view returns (uint256);

  function increaseMaxUSDLiabilities(uint256 _amount) external;

  function addRedemptionRequest(
    address _beneficiary,
    uint256 _redeemAmount,
    uint256 _availableAmount,
    uint256 _reqestedAt
  ) external;

  function getUserMaxUSDLiability(address _maxUSDHolder) external view returns (uint256);
}
