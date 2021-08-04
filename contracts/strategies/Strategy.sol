//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "../interfaces/IAddressManager.sol";
import "../interfaces/IStrategyBase.sol";
import "../interfaces/IStrategyAssetValue.sol";

/**
 * @title Strategy contract
 * @author Maxos
 */
contract Strategy is IStrategyBase, IStrategyAssetValue, ReentrancyGuardUpgradeable {
  /*** Storage Properties ***/

  // Vault address the strategy interacts with
  address public vault;

  // Address manager
  address public addressManager;

  /*** Contract Logic Starts Here */

  modifier onlyBanker() {
    require(msg.sender == IAddressManager(addressManager).bankerContract(), "No banker");
    _;
  }

  function initialize(
    address _addressManager,
    address _vault
  ) public initializer {
    __ReentrancyGuard_init();

    addressManager = _addressManager;
    vault = _vault;
  }

  /**
   * @notice Invest token in the external pool
   * @dev Token is transferred from the banker
   * @param amount USD amount to invest
   */
  function invest(uint256 amount) external override onlyBanker {}

  /**
   * @notice Redeem token from the external pool and return it to requestor
   * @dev Transfer min(strategy balance, redemption amount) amount to requestor
   * @param beneficiary Redemption requestor
   * @param amount USD amount to return
   */
  function redeem(address beneficiary, uint256 amount) external override onlyBanker nonReentrant {}

  /**
   * @notice Returns asset value of the strategy
   * @return (uint256) asset value of the strategy in USD
   */
  function strategyAssetValue() external view override returns (uint256) {}
}
