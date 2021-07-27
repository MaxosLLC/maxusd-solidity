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
  mapping(string => address) public override tokenAddress;

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
   * @notice Register token address
   * @param _token Token symbol
   * @param _address Token address
   */
  function registerToken(string calldata _token, address _address) external onlyOwner {
    tokenAddress[_token] = _address;
  }
}
