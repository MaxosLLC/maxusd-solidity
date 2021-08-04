//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

// MaxUSD redemption queue to the strategy
struct RedemptionRequest {
    address beneficiary; // redemption requestor
    uint256 amount; // MaxUSD amount to redeem
    uint256 requestedAt; // redemption request time
}

interface IBanker {
  function mintDepositPercentage() external view returns (uint256);
  function addRedemptionRequest(RedemptionRequest memory _redemptionRequest) external;
  function getUserMaxUSDLiability(address _maxUSDHolder) external view returns (uint256);
}
