//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "../interfaces/IAddressManager.sol";
import "../interfaces/IStrategyAssetValue.sol";

/**
 * @notice Banker Contract
 * @author Maxos
 */
contract Banker is ReentrancyGuardUpgradeable {
  /*** Storage Properties ***/

  // Strategy settings
  struct StrategySettings {
    uint256 insuranceAP; // insurance allocation percentage, scaled by 10e2
    uint256 desiredAssetAP; // desired asset allocation percentage, scaled by 10e2
    uint256 assetValue; // asset value in strategy, scaled by 10e2
    uint256 reportedAt; // last reported time
  }

  // Interest rate
  struct InterestRate {
    uint256 interestRate; // current annual interest rate, scaled by 10e2
    uint256 lastInterestPaymentTime; // last time that we paid interest
  }

  // MaxUSD redemption queue to the strategy
  struct RedemptionRequest {
    address beneficiary; // redemption requestor
    uint256 amount; // MaxUSD amount to redeem
    uint256 requestedAt; // redemption request time
  }

  // Strategy addresses
  address[] public strategies;

  // Returns if strategy is valid
  mapping(address => bool) public isValidStrategy;

  // Information per strategy
  mapping(address => StrategySettings) public strategySettings;

  // MaxUSD annual interest rate
  // Annual interest rate is increased as the interest is earned from the strategy
  InterestRate public maxUSDinterestRate;

  // MaxUSD Liabilities
  uint256 public maxUSDLiabilities;

  // Mint percentage of MaxUSD and MaxBanker, scaled by 10e2
  // If mintDepositPercentage is 8000, we mint 80% of MaxUSD and 20% of MaxBanker
  uint256 public mintDepositPercentage;

  // Redemption request dealy time
  uint256 public redemptionDelayTime;

  // Redemption request queue
  RedemptionRequest[] internal _redemptionRequestQueue;

  // Turn on/off option
  bool public isTurnOff;

  // Address manager
  address public addressManager;

  /*** Contract Logic Starts Here */

  modifier onlyManager() {
    require(msg.sender == IAddressManager(addressManager).manager(), "No manager");
    _;
  }

  modifier onlyStrategy() {
    require(isValidStrategy[msg.sender], "No strategy");
    _;
  }

  modifier onlyTurnOn() {
    require(!isTurnOff, "Turn off");
    _;
  }

  /**
   * @notice Initialize the banker contract
   * @dev If mintDepositPercentage is 8000, we mint 80% of MaxUSD and 20% of MaxBanker
   * @param _addressManager Address manager contract
   * @param _mintDepositPercentage Mint percentage of MaxUSD and MaxBanker, scaled by 10e2
   * @param _redemptionDelayTime Delay time for the redemption request
   */
  function initialize(
    address _addressManager,
    uint256 _mintDepositPercentage,
    uint256 _redemptionDelayTime
  ) public initializer {
    __ReentrancyGuard_init();

    addressManager = _addressManager;

    // set mintDepositPercentage
    require(_mintDepositPercentage <= 10000, "Invalid percentage");
    mintDepositPercentage = _mintDepositPercentage;

    // set initial interest rate
    maxUSDinterestRate.interestRate = 0;
    maxUSDinterestRate.lastInterestPaymentTime = block.timestamp;

    // set redemptionDelayTime
    redemptionDelayTime = _redemptionDelayTime;
  }

  /**
   * @notice Set `turnoff` switch to true
   * @dev Turn off all activities except for redeeming from strategies (except treasury) and redeeming MaxUSD from the treasury
   */
  function turnOff() external onlyManager {
    require(!isTurnOff, "Already turn off");
    isTurnOff = true;
  }

  /**
   * @notice Set `turnoff` switch to false
   * @dev Turn on all activities
   */
  function turnOn() external onlyManager {
    require(isTurnOff, "Already turn on");
    isTurnOff = false;
  }

  /**
   * @notice Add a new strategy
   * @dev Set isValidStrategy to true
   * @param _strategy Strategy address
   * @param _insuranceAP Insurance allocation percentage, scaled by 10e2
   * @param _desiredAssetAP Desired asset allocation percentage, scaled by 10e2
   */
  function addStrategy(
    address _strategy,
    uint256 _insuranceAP,
    uint256 _desiredAssetAP
  ) external onlyManager {}

  /**
   * @notice Remove strategy
   * @dev Set isValidStrategy to false
   * @param _strategy Strategy address
   */
  function removeStrategy(address _strategy) external onlyManager {}

  /**
   * @notice Set insurance allocation percentage to the strategy
   * @param _strategies Strategy addresses
   * @param _insuranceAPs Insurance allocation percentages, scaled by 10e2
   */
  function setStrategyInsuranceAPs(address[] memory _strategies, uint256[] memory _insuranceAPs)
    external
    onlyManager
    onlyTurnOn
  {
    require(_strategies.length == _insuranceAPs.length, "data error");

    for (uint256 i; i < _strategies.length; i++) {
      require(isValidStrategy[_strategies[i]], "Invalid strategy");
      strategySettings[_strategies[i]].insuranceAP = _insuranceAPs[i];
    }
  }

  /**
   * @notice Set desired asset allocation percentage to the strategy
   * @dev Invest/redeem token in/from the strategy based on the new allocation percentage
   * @param _strategies Strategy addresses
   * @param _desiredAssetAPs Desired asset allocation percentages, scaled by 10e2
   */
  function setStrategyDesiredAssetAPs(address[] memory _strategies, uint256[] memory _desiredAssetAPs)
    external
    onlyManager
    onlyTurnOn
    nonReentrant
  {
    // invest()
    // redeem()
  }

  /**
   * @notice Batch set of the insurance and desired asset allocation percentages
   * @dev Invest/redeem token in/from the strategy based on the new allocation
   * @param _strategies Strategy addresses
   * @param _insuranceAPs Insurance allocation percentages, scaled by 10e2
   * @param _desiredAssetAPs Desired asset allocation percentages, scaled by 10e2
   */
  function batchAllocation(
    address[] memory _strategies,
    uint256[] memory _insuranceAPs,
    uint256[] memory _desiredAssetAPs
  ) external onlyManager onlyTurnOn nonReentrant {
    // invest()
    // redeem()
  }

  /**
   * @notice Update annual interest rate and MaxUSDLiabilities for MaxUSD holders
   * @param _interestRate Interest rate earned since the last recored one, scaled by 10e2
   */
  function payInterest(uint256 _interestRate) external onlyManager onlyTurnOn {
    // update interest rate
    maxUSDinterestRate.interestRate = _interestRate;
    maxUSDinterestRate.lastInterestPaymentTime = block.timestamp;

    // update MaxUSDLiabilities
    uint256 passedDays = (block.timestamp - maxUSDinterestRate.lastInterestPaymentTime) / 1 days;
    maxUSDLiabilities *= (1 + _interestRate/10000) ** (passedDays / 365);
  }

  /**
   * @notice Set mint percentage of MaxUSD and MaxBanker
   * @dev mint percentage is scaled by 10e2
   * @param _mintDepositPercentage mint percentage of MaxUSD and MaxBanker
   */
  function setMintDepositPercentage(uint256 _mintDepositPercentage) external onlyManager {
    mintDepositPercentage = _mintDepositPercentage;
  }

  /**
   * @notice Set redemption request delay time
   * @param _redemptionDelayTime Redemption request dealy time
   */
  function setRedemptionDelayTime(uint256 _redemptionDelayTime) external onlyManager {
    redemptionDelayTime = _redemptionDelayTime;
  }

  /**
   * @notice Add redemption request to the queue
   * @param _redemptionRequest redemption request
   */
  function addRedemptionRequest(RedemptionRequest memory _redemptionRequest) external onlyStrategy onlyTurnOn {}

  /**
   * @notice Get the MaxUSD holder's current MaxUSDLiablity
   * @param _maxUSDHolder MaxUSD holder
   */
  function getUserMaxUSDLiability(address _maxUSDHolder) external view returns (uint256) {
    address maxUSD = IAddressManager(addressManager).maxUSD();
    uint256 totalShare = IERC20Upgradeable(maxUSD).totalSupply();
    uint256 holderShare = IERC20Upgradeable(maxUSD).balanceOf(_maxUSDHolder);

    return maxUSDLiabilities / totalShare * holderShare;
  }

  /**
   * @notice Get total asset values across the strategies
   * @dev Set every strategy value and update time
   * @return (uint256) Total asset value
   */
  function getTotalAssetValue() external view returns (uint256) {
    uint256 totalAssetValue;
    for (uint256 i; i < strategies.length; i++) {
      totalAssetValue += IStrategyAssetValue(strategies[i]).strategyAssetValue();
    }

    return totalAssetValue;
  }

  /**
   * @notice Remove redemption request to the queue
   * @param _redemptionRequest redemption request
   */
  function _removeRedemptionRequest(RedemptionRequest memory _redemptionRequest) internal onlyTurnOn {}

  /**
   * @notice Invest token in the strategy
   * @param _strategy Strategy address to invest
   * @param _amount Token amount
   */
  function _invest(address _strategy, uint256 _amount) internal onlyTurnOn {}

  /**
   * @notice Redeem token from the strategy
   * @param _strategy Strategy address to redeem
   * @param _amount Token amount
   */
  function _redeem(address _strategy, uint256 _amount) internal onlyTurnOn {}
}
