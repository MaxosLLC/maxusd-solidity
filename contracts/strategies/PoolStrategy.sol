//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "../interfaces/IAddressManager.sol";
import "../interfaces/IPoolStrategy.sol";

/**
 * @title Strategy contract
 * @author Maxos
 */
contract PoolStrategy is IPoolStrategy, ReentrancyGuardUpgradeable {
  /*** Storage Properties ***/

  // Pool address the strategy interacts with
  address public pool;

  // Token amount limit to invest/redeem
  uint256 public amountLimit;

  // Address manager
  address public addressManager;

  /*** Contract Logic Starts Here */

  modifier onlyBanker() {
    require(msg.sender == IAddressManager(addressManager).bankerContract(), "No banker");
    _;
  }

  function initialize(
    address _addressManager,
    address _pool,
    uint256 _amountLimit
  ) public initializer {
    __ReentrancyGuard_init();

    addressManager = _addressManager;
    pool = _pool;
    amountLimit = _amountLimit;
  }

  /**
   * @notice Get asset value of the strategy
   * @return (uint256) asset value in USD
   */
  function getAssetValue() external override returns (uint256) {}

  /**
   * @notice Accept token from banker and transfer it in the external pool
   * @dev Token amount must be less than the limit
   * @param amount Token amount
   */
  function invest(uint256 amount) external override onlyBanker {}

  /**
   * @notice Redeem token from the external pool and return it to requestor
   * @dev Token amount must be less than the limit
   * @dev Transfer min(strategy balance, redemption amount) amount to requestor
   * @param beneficiary Redemption requestor
   * @param amount Token amount
   */
  function redeem(address beneficiary, uint256 amount) external override onlyBanker nonReentrant {}
}
