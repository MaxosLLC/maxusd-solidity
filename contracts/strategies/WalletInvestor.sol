//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "../interfaces/IAddressManager.sol";
import "../interfaces/IStrategyAssetValue.sol";

/**
 * @title WalletInvestor contract
 * @author Maxos
 */
contract WalletInvestor is IStrategyAssetValue, Initializable {
  /*** Storage Properties ***/

  // Asset value of the strategy
  uint256 public override strategyAssetValue;

  // Address manager
  address public addressManager;

  // USDC token
  ERC20 public usdc;

  /*** Contract Logic Starts Here */

  modifier onlyInvestor() {
    require(msg.sender == IAddressManager(addressManager).investor(), "No investor");
    _;
  }

  function initialize(address _addressManager) public initializer {
    addressManager = _addressManager;

    usdc = ERC20(IAddressManager(addressManager).USDC());
  }

  /**
   * @notice Update asset value of the strategy
   * @param _strategyAssetValue Asset value of the strategy in USD, scaled by 10e2, Ex: 100 USD is represented by 10,000
   */
  function updateStrategyAssetValue(uint256 _strategyAssetValue) external onlyInvestor {
    strategyAssetValue = _strategyAssetValue;
  }

  /**
   * @notice Returns the available amount in the strategy
   * @return (uint256) available amount in USDC
   */
  function strategyAvailableAmount() external view override returns (uint256) {
    uint256 availableAmount = usdc.balanceOf(address(this));

    return availableAmount;
  }
}
