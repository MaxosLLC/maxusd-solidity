//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "../interfaces/IAddressManager.sol";
import "../interfaces/IStrategyBase.sol";
import "../interfaces/IStrategyAssetValue.sol";

/**
 * @title Strategy contract
 * @author Maxos
 */
contract Strategy is IStrategyBase, IStrategyAssetValue, ReentrancyGuardUpgradeable {
  /*** Events ***/
  event Withdraw(address indexed beneficiary, uint256 amount);
  event EmergencyWithdraw(address indexed beneficiary, address indexed token, uint256 amount);

  /*** Storage Properties ***/

  // Vault address the strategy interacts with
  address public vault;

  // Address manager
  address public addressManager;

  // USDC token
  ERC20 public usdc;

  /*** Contract Logic Starts Here */

  modifier onlyBanker() {
    require(msg.sender == IAddressManager(addressManager).bankerContract(), "No banker");
    _;
  }

  modifier onlyManager() {
    require(msg.sender == IAddressManager(addressManager).manager(), "No manager");
    _;
  }

  function __Strategy_init(address _addressManager, address _vault) public initializer {
    __ReentrancyGuard_init();

    addressManager = _addressManager;
    vault = _vault;
    usdc = ERC20(IAddressManager(addressManager).USDC());
  }

  /**
   * @notice Invest token in the external pool
   * @dev Token is transferred from the banker
   * @param _amount USDC amount to invest
   */
  function invest(uint256 _amount) external virtual override onlyBanker {}

  /**
   * @notice Redeem token from the external pool and return it to requestor
   * @dev Transfer min(strategy balance, redemption amount) amount to requestor
   * @param _beneficiary Beneficiary address
   * @param _amount USDC amount to return
   */
  function redeem(address _beneficiary, uint256 _amount) external virtual override onlyBanker nonReentrant {}

  /**
   * @notice Withdraw tokens redeemed with the delay
   * @param _beneficiary Beneficiary address
   */
  function withdrawAvailableAmount(address _beneficiary) external override onlyBanker nonReentrant {
    require(usdc.transfer(_beneficiary, usdc.balanceOf(address(this))));

    emit Withdraw(_beneficiary, usdc.balanceOf(address(this)));
  }

  /**
   * @notice Emergency withdraw for ERC20 tokens
   * @param _beneficiary Beneficiary address
   * @param _token Token address to withdraw
   */
  function emergencyWithdraw(address _beneficiary, address _token) external override onlyManager nonReentrant {
    ERC20 token = ERC20(_token);
    require(token.transfer(_beneficiary, token.balanceOf(address(this))));

    emit EmergencyWithdraw(_beneficiary, _token, token.balanceOf(address(this)));
  }
  
  /**
   * @notice Returns asset value of the strategy
   * @return (uint256) asset value of the strategy in USDC
   */
  function strategyAssetValue() external view virtual override returns (uint256) {}

  /**
   * @notice Returns the available amount in the strategy
   * @return (uint256) available amount in USDC
   */
  function strategyAvailableAmount() external view override returns (uint256) {
    uint256 availableAmount = usdc.balanceOf(address(this));

    return availableAmount;
  }
}
