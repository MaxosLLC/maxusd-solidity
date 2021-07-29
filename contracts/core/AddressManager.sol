//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "../interfaces/IAddressManager.sol";

/**
 * @title Address Manager contract
 * @author Maxos
 */
contract AddressManager is IAddressManager, OwnableUpgradeable {
  /*** Storage Properties ***/

  // Maxos manager address
  address public override manager;

  // Maxos contracts
  address public override bankerContract;
  address public override treasuryContract;

  // Maxos tokens
  address public override maxUSD;
  address public override maxBanker;

  /*** Contract Logic Starts Here */

  function initialize(address _manager) public initializer {
    __Ownable_init();

    manager = _manager;
  }

  /**
   * @notice Set manager
   * @param _manager Manager address
   */
  function setManager(address _manager) external onlyOwner {
    manager = _manager;
  }

  /**
   * @notice Set banker contract address
   * @param _bankerContract Banker contract address
   */
  function setBankerContract(address _bankerContract) external onlyOwner {
    bankerContract = _bankerContract;
  }

  /**
   * @notice Set treasury contract address
   * @param _treasuryContract Treasury contract address
   */
  function setTreasuryContract(address _treasuryContract) external onlyOwner {
    treasuryContract = _treasuryContract;
  }

  /**
   * @notice Set MaxUSD token address
   * @param _address MaxUSD token address
   */
  function setMaxUSD(address _address) external onlyOwner {
    maxUSD = _address;
  }

  /**
   * @notice Set MaxBanker token address
   * @param _address MaxBanker token address
   */
  function setMaxBanker(address _address) external onlyOwner {
    maxBanker = _address;
  }
}
