//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "../interfaces/IBanker.sol";
import "../interfaces/IAddressManager.sol";
import "../interfaces/IStrategyAssetValue.sol";

/**
 * @notice Banker Contract
 * @author Maxos
 */
contract Banker is IBanker, ReentrancyGuardUpgradeable {
  /*** Storage Properties ***/

  // Strategy settings
  struct StrategySettings {
    uint256 insuranceAP; // insurance allocation percentage, scaled by 10e2
    uint256 desiredAssetAP; // desired asset allocation percentage, scaled by 10e2
    uint256 assetValue; // asset value in strategy
    uint256 reportedAt; // last reported time
  }

  // Interest rate
  struct InterestRate {
    uint256 interestRate; // current annual interest rate, scaled by 10e2
    uint256 lastInterestPaymentTime; // last time that we paid interest
  }

  // Next interest rate
  struct NextInterestRate {
    uint256 interestRate; // next interest rate
    uint256 nextRateStartTime;  // next rate start time
  }

  // MaxUSD redemption queue to the strategy, defined in IBanker like this
  // struct RedemptionRequest {
  //   address beneficiary; // redemption requestor
  //   uint256 amount; // MaxUSD amount to redeem
  //   uint256 requestedAt; // redemption request time
  // }

  // Strategy addresses
  address[] public strategies;

  // Returns if strategy is valid
  mapping(address => bool) public isValidStrategy;

  // Information per strategy
  mapping(address => StrategySettings) public strategySettings;

  // MaxUSD Liabilities
  uint256 public maxUSDLiabilities;

  // Redemption request dealy time
  uint256 public redemptionDelayTime;

  // Redemption request queue
  mapping(uint256 => RedemptionRequest) internal _redemptionRequestQueue;
  uint256 first;
  uint256 last;

  // Turn on/off option
  bool public isTurnOff;

  // Address manager
  address public addressManager;


  /*** Banker Settings Here */

  // MaxUSD annual interest rate
  InterestRate public maxUSDInterestRate;
  
  // MaxUSD next annual interest rate
  NextInterestRate public maxUSDNextInterestRate;

  // Mint percentage of MaxUSD and MaxBanker, scaled by 10e2
  // If mintDepositPercentage is 8000, we mint 80% of MaxUSD and 20% of MaxBanker
  uint256 public override mintDepositPercentage;

  // MaxBanker price, scaled by 10e18
  uint256 public maxBankerPrice;

  // Celling MaxSD price, scaled by 10e18
  uint256 public cellingMaxUSDPrice;

  // MaxBanker per stake
  uint256 public maxBankerPerStake;

  // Staking available
  uint256 public stakingAvailable;

  // Stake strike price, scaled by 10e18
  uint256 public stakeStrikePrice;

  // Stake lockup time
  uint256 public stakeLockupTime;

  /*** Contract Logic Starts Here */

  modifier onlyManager() {
    require(msg.sender == IAddressManager(addressManager).manager(), "No manager");
    _;
  }

  modifier onlyTreasuryContract() {
    require(isValidStrategy[msg.sender] && msg.sender == IAddressManager(addressManager).treasuryContract(), "No treasury");
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
    maxUSDInterestRate.interestRate = 0;
    maxUSDInterestRate.lastInterestPaymentTime = block.timestamp;

    // set redemptionDelayTime
    redemptionDelayTime = _redemptionDelayTime;

    // initialize redemption request queue parameters
    first = 1;
    last = 0;
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
  ) external onlyManager {
    require(!isValidStrategy[_strategy], "Already exists");
    isValidStrategy[_strategy] = true;

    strategies.push(_strategy);
    strategySettings[_strategy].insuranceAP = _insuranceAP;
    strategySettings[_strategy].desiredAssetAP = _desiredAssetAP;
  }

  /**
   * @notice Remove strategy
   * @dev Set isValidStrategy to false
   * @param _strategy Strategy address
   */
  function removeStrategy(address _strategy) external onlyManager {
    require(isValidStrategy[_strategy], "Not exist");
    isValidStrategy[_strategy] = false;

    for (uint256 i; i < strategies.length; i++) {
      if (strategies[i] == _strategy) {
        strategies[i] = strategies[strategies.length - 1];
        strategies.pop();

        break;
      }
    }
  }

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
    maxUSDInterestRate.interestRate = _interestRate;
    maxUSDInterestRate.lastInterestPaymentTime = block.timestamp;

    // update MaxUSDLiabilities
    maxUSDLiabilities = calculateMaxUSDLiabilities(_interestRate);
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
   * @notice Increase MaxUSDLiabilities
   * @param _amount USD amount to deposit
   */
  function increaseMaxUSDLiabilities(uint256 _amount) external override onlyTreasuryContract onlyTurnOn {
    maxUSDLiabilities += _amount;
  }

  /**
   * @notice Add redemption request to the queue
   * @param _requestor redemption requestor
   * @param _amount USD amount to redeem
   * @param _requestedAt requested time
   */
  function addRedemptionRequest(address _requestor, uint256 _amount, uint256 _requestedAt) external override onlyTreasuryContract onlyTurnOn {
    last++;
    _redemptionRequestQueue[last] = RedemptionRequest({ requestor: _requestor, amount: _amount, requestedAt: _requestedAt });
  }

  /**
   * @notice Get the MaxUSD holder's current MaxUSDLiablity
   * @param _maxUSDHolder MaxUSD holder
   */
  function getUserMaxUSDLiability(address _maxUSDHolder) external view override returns (uint256) {
    // address maxUSD = IAddressManager(addressManager).maxUSD();
    // uint256 totalShare = IERC20Upgradeable(maxUSD).totalSupply();
    // uint256 holderShare = IERC20Upgradeable(maxUSD).balanceOf(_maxUSDHolder);

    // return maxUSDLiabilities / totalShare * holderShare;

    // Assume that only one user(manager) deposits
    return maxUSDLiabilities;
  }

  /**
   * @notice Get total asset values across the strategies
   * @dev Set every strategy value and update time
   * @return (uint256) Total asset value scaled by 10e2, Ex: 100 USD is represented by 10,000
   */
  function getTotalAssetValue() external returns (uint256) {
    uint256 totalAssetValue;
    uint256 strategyAssetValue;
    for (uint256 i; i < strategies.length; i++) {
      strategyAssetValue = IStrategyAssetValue(strategies[i]).strategyAssetValue();
      totalAssetValue += strategyAssetValue;
      strategySettings[strategies[i]].assetValue = strategyAssetValue;
      strategySettings[strategies[i]].reportedAt = block.timestamp;
    }

    return totalAssetValue;
  }

  /**
   * @notice Set next interest rate and start time
   * @param _interestRate next interest rate
   * @param _startTime next rate start time
   */
  function setNextInterestRateAndTime(uint256 _interestRate, uint256 _startTime) external onlyManager {
    maxUSDNextInterestRate.interestRate = _interestRate;
    maxUSDNextInterestRate.nextRateStartTime = _startTime;
  }

  /**
   * @notice Calculate MaxUSDLiabilities with the interest rate given
   * @param _interestRate Interest rate scaled by 10e2
   * @return (uint256) MaxUSDLiabilities
   */
  function calculateMaxUSDLiabilities(uint256 _interestRate) public view returns (uint256) {
    uint256 passedDays = (block.timestamp - maxUSDInterestRate.lastInterestPaymentTime) / 1 days;
    return maxUSDLiabilities * (1 + _interestRate/10000) ** (passedDays / 365);
  }

  /**
   * @notice Decrease MaxUSDLiabilities
   * @param _amount USD amount to redeem
   */
  function decreaseMaxUSDLiabilities(uint256 _amount) internal onlyTurnOn {
    maxUSDLiabilities -= _amount;
  }

  /**
   * @notice Remove redemption requet from the queue
   * @return (address, uint256, uint256) requestor, amount, requestedAt
   */
  function _removeRedemptionRequest() internal onlyTurnOn returns (address, uint256, uint256) {
    require(last >= first, "Empty queue");

    address requestor = _redemptionRequestQueue[first].requestor;
    uint256 amount = _redemptionRequestQueue[first].amount;
    uint256 requestedAt = _redemptionRequestQueue[first].requestedAt;

    delete _redemptionRequestQueue[first];
    first++;

    return (requestor, amount, requestedAt);
  }

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
