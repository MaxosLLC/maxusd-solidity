//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "../interfaces/IAddressManager.sol";

/**
 * @notice Banker Contract
 * @author Maxos
 */
contract Banker is ReentrancyGuardUpgradeable {
    /*** Events ***/
    // event Mint(address indexed to, uint256 amount);
    // event Burn(address indexed from, uint256 amount);


    /*** Storage Properties ***/

    // Strategy settings
    struct StrategySettings {
        uint256 insuranceAP;                // insurance allocation percentage
        uint256 desiredAssetAP;             // desired asset allocation percentage
        uint256 value;                      // asset value in strategy
        uint256 reportedAt;                 // last reported time
        bool isTreasury;                    // Represent if strategy is cash one
    }

    // MaxUSD interest index state
    // interestIndex increases as interest is earned from the strategy
    struct MaxUSDInterestIndex {
        uint256 updatedAt;                  // last updated time
        uint256 interestIndex;              // last interest index scaled by 10e18
    }

    // MaxUSD redemption queue to the strategy
    struct RedemptionRequest {
        address beneficiary;                // redemption requestor
        uint256 amount;                     // MaxUSD amount to redeem
        uint256 requestedAt;                // redemption request time
    }

    // Strategy addresses
    address[] public strategies;

    // Returns if strategy is valid
    mapping(address => bool) public isValidStrategy;

    // Information per strategy
    mapping(address => StrategySettings) public strategySettings;

    // MaxUSD interest index
    MaxUSDInterestIndex public maxUSDInterestIndex;

    // Mint percentage of MaxUSD and MaxBanker
    // If mintDepositPercentage is 80, we mint 80% of MaxUSD and 20% of MaxBanker
    uint256 public mintDepositPercentage;

    // Redemption request dealy time
    uint256 public redemptionDelayTime;

    // Redemption request queue
    RedemptionRequest[] internal _redemptionRequestQueue;

    // Total values
    uint256 totalValues;

    // Turnoff option
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
     * @param _addressManager Address manager contract
     * @param _mintDepositPercentage Mint percentage of MaxUSD and MaxBanker, if mintDepositPercentage is 80, we mint 80% of MaxUSD and 20% of MaxBanker
     * @param _redemptionDelayTime Delay time for the redemption request
     */
    function initialize(address _addressManager, uint256 _mintDepositPercentage, uint256 _redemptionDelayTime) public initializer {
        __ReentrancyGuard_init();
        
        addressManager = _addressManager;

        require(_mintDepositPercentage <= 100, "Invalid percentage");
        mintDepositPercentage = _mintDepositPercentage;

        maxUSDInterestIndex.updatedAt = block.timestamp;
        maxUSDInterestIndex.interestIndex = 10**18;
        redemptionDelayTime = _redemptionDelayTime;
    }

    /**
     * @notice Set `turnoff` switch to true
     * @dev Turn off all activities except for redeeming from strategies (except treasury) and redeeming MaxUSD from the treasury
     */
    function turnOff() external onlyManager {
        isTurnOff = true;
    }

    /**
     * @notice Set `turnoff` switch to false
     * @dev Turn on all activities
     */
    function turnOn() external onlyManager {
        isTurnOff = false;
    }

    /**
     * @notice Add a new strategy
     * @dev Set isValidStrategy to true
     * @param _strategy Strategy address
     * @param _insuranceAP Insurance allocation percentage
     * @param _desiredAssetAP Desired asset allocation percentage
     * @param _isTreasury Represent if strategy is cash one
     */
    function addStrategy(address _strategy, uint256 _insuranceAP, uint256 _desiredAssetAP, bool _isTreasury) external onlyManager {

    }

    /**
     * @notice Remove strategy
     * @dev Set isValidStrategy to false
     * @param _strategy Strategy address
     */
    function removeStrategy(address _strategy) external onlyManager {

    }

    /**
     * @notice Set insurance allocation percentage to the strategy
     * @param _strategies Strategy addresses
     * @param _insuranceAPs Insurance allocation percentages
     */
    function setStrategyInsuranceAPs(address[] memory _strategies, uint256[] memory _insuranceAPs) external onlyManager onlyTurnOn {
        require(_strategies.length == _insuranceAPs.length, "data error");

        for (uint i; i < _strategies.length; i++) {
            require(isValidStrategy[_strategies[i]], "Invalid strategy");
            strategySettings[_strategies[i]].insuranceAP = _insuranceAPs[i];
        }
    }

    /**
     * @notice Set desired asset allocation percentage to the strategy
     * @dev Invest/redeem token in/from the strategy based on the new allocation percentage
     * @param _strategies Strategy addresses
     * @param _desiredAssetAPs Desired asset allocation percentages
     */
    function setStrategyDesiredAssetAPs(address[] memory _strategies, uint256[] memory _desiredAssetAPs) external onlyManager onlyTurnOn nonReentrant {
        // invest()
        // redeem()
    }

    /**
     * @notice Batch set of the insurance and desired asset allocation percentage
     * @dev Invest/redeem token in/from the strategy based on the new allocation
     * @param _strategies Strategy addresses
     * @param _insuranceAPs Insurance allocation percentages
     * @param _desiredAssetAPs Desired asset allocation percentages
     */
    function batchAllocation(address[] memory _strategies, uint256[] memory _insuranceAPs, uint256[] memory _desiredAssetAPs) external onlyManager onlyTurnOn nonReentrant {
        // invest()
        // redeem()
    }

    /**
     * @notice Set strategy value
     * @dev Update report time
     * @param _strategy Strategy address
     * @param _value Strategy value
     */
    function setStrategyValue(address _strategy, uint256 _value) external onlyStrategy onlyTurnOn {
        _setStrategyValue(_strategy, _value);
    }

    /**
     * @notice Update maxUSD interest index
     * @dev Interest index is scaled by 10e18 and _interestPercentage is scaled by 10e8
     * @param _interestPercentage Interest percentage earned since the last recored interest index
     */
    function updateInterestIndex(uint256 _interestPercentage) external onlyManager {
        maxUSDInterestIndex.updatedAt = block.timestamp;
        maxUSDInterestIndex.interestIndex *= (1 + _interestPercentage / 10**8);
    }

    /**
     * @notice Set mint percentage of maxUSD and maxBanker
     * @dev mint percentage is scaled by 10e2
     * @param _mintDepositPercentage mint percentage of maxUSD and maxBanker
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
    function addRedemptionRequest(RedemptionRequest memory _redemptionRequest) external onlyStrategy onlyTurnOn {

    }

    /**
     * @notice Get total asset values across the strategies
     * @dev Set every strategy value and update time
     * @return (uint256) Total asset value
     */
    function getTotalAssetValues() external returns (uint256) {

    }

    /**
     * @notice Remove redemption request to the queue
     * @param _redemptionRequest redemption request
     */
    function _removeRedemptionRequest(RedemptionRequest memory _redemptionRequest) internal onlyTurnOn {

    }

    /**
     * @notice Set strategy value
     * @dev Update report time
     * @param _strategy Strategy address
     * @param _value Strategy value
     */
    function _setStrategyValue(address _strategy, uint256 _value) internal {
        require(isValidStrategy[_strategy], "Invalid strategy");

        totalValues = totalValues - strategySettings[_strategy].value + _value;
        strategySettings[_strategy].value = _value;
        strategySettings[_strategy].reportedAt = block.timestamp;
    }

    /**
     * @notice Invest token in the strategy
     * @param _strategy Strategy address to invest
     * @param _amount Token amount
     */
    function invest(address _strategy, uint256 _amount) internal onlyTurnOn {

    }

    /**
     * @notice Redeem token from the strategy
     * @param _strategy Strategy address to redeem
     * @param _amount Token amount
     */
    function redeem(address _strategy, uint256 _amount) internal onlyTurnOn {

    }
}
