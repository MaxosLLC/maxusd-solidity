//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "../interfaces/IBanker.sol";
import "../interfaces/IERC20Extended.sol";
import "../interfaces/IAddressManager.sol";
import "../interfaces/ITreasury.sol";
import "../interfaces/IStrategyAssetValue.sol";

/**
 * @notice Treasury Contract
 * @author Maxos
 */
contract Treasury is ITreasury, IStrategyAssetValue, ReentrancyGuardUpgradeable {
  /*** Events ***/
  event BuyDeposit(address indexed depositor, uint256 amount);
  event RedeemDeposit(address indexed requestor, uint256 amount);
  event Withdraw(address indexed beneficiary, uint256 amount);
  event EmergencyWithdraw(address indexed beneficiary, address indexed token, uint256 amount);

  /*** Storage Properties ***/

  // Address manager
  address public addressManager;

  // USDC token
  ERC20 public usdc;

  /*** Contract Logic Starts Here */

  modifier onlyManager() {
    require(msg.sender == IAddressManager(addressManager).manager(), "No manager");
    _;
  }

  function initialize(address _addressManager) public initializer {
    __ReentrancyGuard_init();

    addressManager = _addressManager;
    usdc = ERC20(IAddressManager(addressManager).USDC());

    // approve infinit amount of USDC to banker contract
    usdc.approve(IAddressManager(addressManager).bankerContract(), type(uint256).max);
  }

  /**
   * @notice Deposit token to the protocol
   * @dev Only allowed token can be deposited
   * @dev Mint MaxUSD and MaxBanker according to mintDepositPercentage
   * @dev Increase user's insurance if mintDepositPercentage is [0, 100)
   * @dev Increase MaxUSDLiaibility if mintDepositPercentage is (0, 100]
   * @param _amount token amount
   */
  function buyDeposit(uint256 _amount) external override onlyManager {
    // transfer token
    require(usdc.transferFrom(msg.sender, address(this), _amount));

    emit BuyDeposit(msg.sender, _amount);
  }

  // /**
  //  * @notice Redeem token
  //  * @param _redeemAmount MaxUSD token amount to redeem
  //  */
  // function redeemDeposit(uint256 _redeemAmount) external override nonReentrant onlyManager {
  //   IBanker(IAddressManager(addressManager).bankerContract()).addRedemptionRequest(
  //     msg.sender,
  //     _redeemAmount,  // update with USDC amount from MaxToken contract
  //     0,
  //     block.timestamp
  //   );

  //   // // transfer token
  //   // require(ERC20(_token).transfer(msg.sender, _redeemAmount));

  //     emit RedeemDeposit(msg.sender, _redeemAmount);
  // }

  /**
   * @notice Withdraw USDC redeemed with the delay
   * @param _beneficiary Beneficiary address
   */
  function withdrawAvailableAmount(address _beneficiary) external onlyManager nonReentrant {
    require(usdc.transfer(_beneficiary, usdc.balanceOf(address(this))));

    emit Withdraw(_beneficiary, usdc.balanceOf(address(this)));
  }

  /**
   * @notice Emergency withdraw for ERC20 tokens
   * @param _beneficiary Beneficiary address
   * @param _token Token address to withdraw
   */
  function emergencyWithdraw(address _beneficiary, address _token) external onlyManager nonReentrant {
    ERC20 token = ERC20(_token);
    require(token.transfer(_beneficiary, token.balanceOf(address(this))));

    emit EmergencyWithdraw(_beneficiary, _token, token.balanceOf(address(this)));
  }

  /**
   * @notice Returns asset value of the Treasury
   * @return (uint256) asset value of the Treasury in USDC
   */
  function strategyAssetValue() external view override returns (uint256) {
    return strategyAvailableAmount();
  }

  /**
   * @notice Returns the available amount in the Treasury
   * @return (uint256) available amount in USDC
   */
  function strategyAvailableAmount() public view override returns (uint256) {
    return usdc.balanceOf(address(this));
  }
}
