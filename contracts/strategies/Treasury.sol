//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "../interfaces/IAddressManager.sol";

/**
 * @notice Treasury Contract
 * @author Maxos
 */
contract Treasury is ReentrancyGuardUpgradeable {
  /*** Events ***/

  event AllowToken(address indexed token);
  event DisallowToken(address indexed token);

  /*** Storage Properties ***/

  // Token list allowed in treasury
  address[] public allowedTokens;

  // Returns if token is allowed
  mapping(address => bool) internal _isAllowedToken;

  // MaxUSD scaled balance
  // userScaledBalance = userBalance / currentInterestIndex
  // This essentially `marks` when a user has deposited in the treasury and can be used to calculate the users current redeemable balance
  mapping(address => uint256) internal _userScaledBalance;

  // Address manager
  address public addressManager;

  /*** Contract Logic Starts Here */

  modifier onlyManager() {
    require(msg.sender == IAddressManager(addressManager).manager(), "No manager");
    _;
  }

  function initialize(address _addressManager) public initializer {
    __ReentrancyGuard_init();

    addressManager = _addressManager;
  }

  /**
   * @notice Deposit token to the protocol
   * @dev Mint MaxUSD and MaxBanker according to mintDepositPercentage
   * @dev Increase user's insurance if mintDepositPercentage is [0, 100)
   * @param _token token address
   * @param _amount token amount
   */
  function deposit(address _token, uint256 _amount) external {}

  /**
   * @notice Withdraw token from the protocol
   * @dev Decrease user's insurance if _token is MaxBanker
   * @param _token token address
   * @param _amount token amount
   */
  function withdraw(address _token, uint256 _amount) external nonReentrant {}

  /**
   * @notice Add a new token into the allowed token list
   * @param _token Token address
   */
  function allowToken(address _token) external onlyManager {
    require(!_isAllowedToken[_token], "Already allowed");

    _isAllowedToken[_token] = true;
    allowedTokens.push(_token);

    emit AllowToken(_token);
  }

  /**
   * @notice Remove token from the allowed token list
   * @param _token Token index in the allowed token list
   */
  function disallowToken(address _token) external onlyManager {
    require(_isAllowedToken[_token], "Already disallowed");
    _isAllowedToken[_token] = false;

    for (uint256 i; i < allowedTokens.length; i++) {
      if (allowedTokens[i] == _token) {
        allowedTokens[i] = allowedTokens[allowedTokens.length - 1];
        allowedTokens.pop();
        break;
      }
    }

    emit DisallowToken(_token);
  }
}
