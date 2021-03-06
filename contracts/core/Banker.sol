//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "../interfaces/IBanker.sol";
import "../interfaces/IAddressManager.sol";
import "../interfaces/IStrategyAssetValue.sol";
import "../interfaces/IStrategyBase.sol";

/**
 * @notice Banker Contract
 * @author Maxos
 */
contract Banker is IBanker, ReentrancyGuardUpgradeable {
  /*** Storage Properties ***/

  // Strategy settings
  struct StrategySettings {
    string name;  // strategy name
    string network; // network
    uint256 insuranceAP; // insurance allocation percentage, scaled by 10e2
    uint256 desiredAssetAP; // desired asset allocation percentage, scaled by 10e2
    uint256 assetValue; // total asset value in strategy
    uint256 availableAmount; // available USD balance in strategy
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
    uint256 nextRateStartTime; // next rate start time
  }

  // MaxUSD redemption queue to the strategy, defined in IBanker like this
  // struct RedemptionRequest {
  //   address beneficiary; // redemption requestor
  //   uint256 redeemAmount; // USD amount to redeem
  //   uint256 availableAmount; // USD amount available
  //   uint256 requestedAt; // redemption request time
  // }

  // Strategy addresses
  address[] public strategies;

  // Returns if strategy is valid
  mapping(address => bool) public isValidStrategy;

  // Information per strategy
  mapping(address => StrategySettings) public strategySettings;

  // MaxUSD Liabilities
  uint256 public override maxUSDLiabilities;

  // Redemption request dealy time
  uint256 public redemptionDelayTime;

  // Redemption request queue
  mapping(uint256 => RedemptionRequest) internal _redemptionRequestQueue;
  uint256 private first;
  uint256 private last;

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
    require(
      isValidStrategy[msg.sender] && msg.sender == IAddressManager(addressManager).treasuryContract(),
      "No treasury"
    );
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
   * @notice Returns strategy array
   */
  function getAllStrategies() external view returns (address[] memory) {
    return strategies;
  }

  /**
   * @notice Add a new strategy
   * @dev Set isValidStrategy to true
   * @param _name Strategy name
   * @param _network Strategy network
   * @param _strategy Strategy address
   * @param _insuranceAP Insurance allocation percentage, scaled by 10e2
   * @param _desiredAssetAP Desired asset allocation percentage, scaled by 10e2
   * @param _availableAmount USD balance available in strategy
   */
  function addStrategy(
    string memory _name,
    string memory _network,
    address _strategy,
    uint256 _insuranceAP,
    uint256 _desiredAssetAP,
    uint256 _availableAmount
  ) external onlyManager {
    require(!isValidStrategy[_strategy], "Already exists");
    require(_insuranceAP <= 10000, "InsuranceAP overflow");
    require(_desiredAssetAP <= 10000, "DesiredAssetAP overflow");
    isValidStrategy[_strategy] = true;

    strategies.push(_strategy);
    strategySettings[_strategy].name = _name;
    strategySettings[_strategy].network = _network;
    strategySettings[_strategy].insuranceAP = _insuranceAP;
    strategySettings[_strategy].desiredAssetAP = _desiredAssetAP;
    strategySettings[_strategy].availableAmount = _availableAmount;
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
   * @notice Set strategy name
   * @param _strategy Strategy address
   * @param _name Strategy name
   */
  function setStrategyName(address _strategy, string memory _name) external onlyManager {
    strategySettings[_strategy].name = _name;
  }

  /**
   * @notice Set strategy network
   * @param _strategy Strategy address
   * @param _network Strategy network
   */
  function setStrategyNetwork(address _strategy, string memory _network) external onlyManager {
    strategySettings[_strategy].network = _network;
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
    nonReentrant
  {
    require(_strategies.length == _insuranceAPs.length, "Data error");

    // set insuranceAP
    for (uint256 i; i < _strategies.length; i++) {
      require(isValidStrategy[_strategies[i]], "Invalid strategy");
      strategySettings[_strategies[i]].insuranceAP = _insuranceAPs[i];
    }

    // check if insuranceAP isn't overflowed
    uint256 sumInsuranceAP;
    for (uint256 j; j < strategies.length; j++) {
      sumInsuranceAP += strategySettings[strategies[j]].insuranceAP;
    }
    require(sumInsuranceAP <= 10000, "InsuranceAP overflow");
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
    require(_strategies.length == _desiredAssetAPs.length, "Data error");

    // set desiredAssetAP
    for (uint256 i; i < _strategies.length; i++) {
      require(isValidStrategy[_strategies[i]], "Invalid strategy");
      strategySettings[_strategies[i]].desiredAssetAP = _desiredAssetAPs[i];
    }

    // check if desiredAssetAP isn't overflowed
    uint256 sumDesiredAssetAP;
    for (uint256 j; j < strategies.length; j++) {
      sumDesiredAssetAP += strategySettings[strategies[j]].desiredAssetAP;
    }
    require(sumDesiredAssetAP <= 10000, "DesiredAssetAP overflow");
  }

  /**
   * @notice Invest/redeem funds in/from strategies
   * @dev Invest/redeem funds in/from the strategy based on the desiredAssetAP
   */
  function allocate() external onlyManager onlyTurnOn nonReentrant {
    uint256 totalAssetValue = getTotalAssetValue();
    address treasury = IAddressManager(addressManager).treasuryContract();
    ERC20 usdc = ERC20(IAddressManager(addressManager).USDC());

    // redeem to Treasury
    int256 diffAmount;
    for (uint256 i; i < strategies.length; i++) {
      // ignore Treasury
      if (strategies[i] != treasury) {
        diffAmount =
          int256(strategySettings[strategies[i]].assetValue) - int256(totalAssetValue * strategySettings[strategies[i]].desiredAssetAP / 10000);
        if (diffAmount > 0) {
          IStrategyBase(strategies[i]).redeem(treasury, uint256(diffAmount));
        }
      }
    }

    // calculate total amount to invest
    int256 totalAmountToAllocate = int256(strategySettings[treasury].assetValue) - int256(totalAssetValue * strategySettings[treasury].desiredAssetAP / 10000);

    // invest
    uint256 strategyAmountToAllocate;
    for (uint256 j = 0; j < strategies.length; j++) {
      // investment done
      if (totalAmountToAllocate == 0) break;

      // transfer funds from treasury to strategies
      if (strategies[j] != treasury) {
        diffAmount =
          int256(totalAssetValue * strategySettings[strategies[j]].desiredAssetAP / 10000) - int256(strategySettings[strategies[j]].assetValue);
        if (diffAmount > 0) {
          strategyAmountToAllocate = uint256(totalAmountToAllocate > diffAmount ? diffAmount : totalAmountToAllocate);
          totalAmountToAllocate -= int256(strategyAmountToAllocate);
          require(totalAmountToAllocate >= 0, "Allocation failure");
          require(usdc.transferFrom(treasury, address(this), strategyAmountToAllocate), "Investment failure");
          require(usdc.transfer(strategies[j], strategyAmountToAllocate), "Investment failure");

          // invest in the strategy
          IStrategyBase(strategies[j]).invest(strategyAmountToAllocate);
        }
      }
    }
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
   * @notice Increase MaxUSDLiabilities
   * @param _amount USD amount to deposit
   */
  function increaseMaxUSDLiabilities(uint256 _amount) external override onlyTreasuryContract onlyTurnOn {
    maxUSDLiabilities += _amount;
  }

  /**
   * @notice Add redemption request to the queue
   * @param _requestor redemption requestor
   * @param _redeemAmount USD amount to redeem
   * @param _availableAmount USD amount available
   * @param _requestedAt requested time
   */
  function addRedemptionRequest(
    address _requestor,
    uint256 _redeemAmount,
    uint256 _availableAmount,
    uint256 _requestedAt
  ) external override onlyTreasuryContract onlyTurnOn {
    last++;
    _redemptionRequestQueue[last] = RedemptionRequest({
      requestor: _requestor,
      redeemAmount: _redeemAmount,
      availableAmount: _availableAmount,
      requestedAt: _requestedAt
    });
  }

  // /**
  //  * @notice Get the MaxUSD holder's current MaxUSDLiability
  //  * @param _maxUSDHolder MaxUSD holder
  //  */
  // function getUserMaxUSDLiability(address _maxUSDHolder) external view override returns (uint256) {
  //   // address maxUSD = IAddressManager(addressManager).maxUSD();
  //   // uint256 totalShare = IERC20Upgradeable(maxUSD).totalSupply();
  //   // uint256 holderShare = IERC20Upgradeable(maxUSD).balanceOf(_maxUSDHolder);

  //   // return maxUSDLiabilities / totalShare * holderShare;

  //   // Assume that only one user(manager) deposits
  //   return maxUSDLiabilities;
  // }

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
   * @notice Get total asset values across the strategies
   * @dev Set the asset value and update time of each strategy
   * @dev Asset value includes the available amount
   * @return (uint256) Total asset value
   */
  function getTotalAssetValue() public returns (uint256) {
    uint256 totalAssetValue;
    uint256 strategyAssetValue;
    uint256 strategyAvailableAmount;

    for (uint256 i; i < strategies.length; i++) {
      strategyAssetValue = IStrategyAssetValue(strategies[i]).strategyAssetValue();
      strategyAvailableAmount = IStrategyAssetValue(strategies[i]).strategyAvailableAmount();

      totalAssetValue += strategyAssetValue;

      strategySettings[strategies[i]].assetValue = strategyAssetValue;
      strategySettings[strategies[i]].availableAmount = strategyAvailableAmount;
      strategySettings[strategies[i]].reportedAt = block.timestamp;
    }

    return totalAssetValue;
  }

  /**
   * @notice Get insurance amount
   * @return (int256) Returns insurance amount
   */
  function getInsurance() public returns (int256) {
    int256 insurnace = int256(getTotalAssetValue() - maxUSDLiabilities);

    return insurnace;
  }

  /**
   * @notice Calculate MaxUSDLiabilities with the interest rate given
   * @param _interestRate Interest rate scaled by 10e2
   * @return (uint256) MaxUSDLiabilities
   */
  function calculateMaxUSDLiabilities(uint256 _interestRate) public view returns (uint256) {
    uint256 passedDays = (block.timestamp - maxUSDInterestRate.lastInterestPaymentTime) / 1 days;
    return maxUSDLiabilities * (1 + _interestRate / 10000)**(passedDays / 365);
  }

  /**
   * @notice Decrease MaxUSDLiabilities
   * @param _amount USD amount to redeem
   */
  function decreaseMaxUSDLiabilities(uint256 _amount) internal onlyTurnOn {
    maxUSDLiabilities -= _amount;
  }

  /**
   * @notice Remove redemption request from the queue
   * @return (address, uint256, uint256) requestor, amount, requestedAt
   */
  function _removeRedemptionRequest()
    internal
    onlyTurnOn
    returns (
      address,
      uint256,
      uint256,
      uint256
    )
  {
    require(last >= first, "Empty redemption queue");

    address requestor = _redemptionRequestQueue[first].requestor;
    uint256 redeemAmount = _redemptionRequestQueue[first].redeemAmount;
    uint256 availableAmount = _redemptionRequestQueue[first].availableAmount;
    uint256 requestedAt = _redemptionRequestQueue[first].requestedAt;

    delete _redemptionRequestQueue[first];
    first++;

    return (requestor, redeemAmount, availableAmount, requestedAt);
  }
}
