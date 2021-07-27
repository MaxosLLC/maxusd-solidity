//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "../interfaces/IAddressManager.sol";
import "../interfaces/ITreasury.sol";

/**
 * @notice Treasury Contract
 * @author Maxos
 */
contract Treasury is ITreasury, ReentrancyGuardUpgradeable {
  /*** Events ***/

  event AllowToken(address indexed token);
  event DisallowToken(address indexed token);

  /*** Storage Properties ***/

  // Token list allowed in treasury
  address[] public allowedTokens;

  // Returns if token is allowed
  mapping(address => bool) public isAllowedToken;

  // MaxUSD scaled balance
  // userScaledBalance = userBalance / currentInterestIndex
  // This essentially `marks` when a user has deposited in the treasury and can be used to calculate the users current redeemable balance
  mapping(address => uint256) public userScaledBalance;

  // Address manager
  address public addressManager;

  /*** Contract Logic Starts Here */

  modifier onlyManager() {
    require(msg.sender == IAddressManager(addressManager).manager(), "No manager");
    _;
  }

  function initialize(address _addressManager, string[] memory _tokens) public initializer {
    __ReentrancyGuard_init();

    addressManager = _addressManager;

    address tokenAddress;
    for (uint256 i; i < _tokens.length; i++) {
      tokenAddress = IAddressManager(_addressManager).tokenAddress(_tokens[i]);
      IERC20Upgradeable(tokenAddress).approve(IAddressManager(addressManager).bankerContract(), type(uint256).max);
    }
  }

  /**
   * @notice Deposit token to the protocol
   * @dev Only allowed token can be deposited
   * @dev Mint MaxUSD and MaxBanker according to mintDepositPercentage
   * @dev Increase user's insurance if mintDepositPercentage is [0, 100)
   * @param _token token address
   * @param _amount token amount
   */
  function deposit(address _token, uint256 _amount) external override {}

  /**
   * @notice Withdraw token from the protocol
   * @dev Only allowed token can be withdrawn
   * @dev Decrease user's insurance if _token is MaxBanker
   * @param _token token address
   * @param _amount token amount
   */
  function withdraw(address _token, uint256 _amount) external override nonReentrant {}

  /**
   * @notice Add a new token into the allowed token list
   * @param _token Token address
   */
  function allowToken(address _token) external override onlyManager {
    require(!isAllowedToken[_token], "Already allowed");

    isAllowedToken[_token] = true;
    allowedTokens.push(_token);

    emit AllowToken(_token);
  }

  /**
   * @notice Remove token from the allowed token list
   * @param _token Token index in the allowed token list
   */
  function disallowToken(address _token) external override onlyManager {
    require(isAllowedToken[_token], "Already disallowed");
    isAllowedToken[_token] = false;

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
