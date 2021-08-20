// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "../interfaces/IAddressManager.sol";
import "../interfaces/IStrategyBase.sol";
import "../interfaces/IStrategyAssetValue.sol";
import "../interfaces/IAnchorConversionPool.sol";
import "../interfaces/IAnchorRouter.sol";
import "../interfaces/IAnchorExchangeRateFeeder.sol";

/**
 * @title AnchorStrategy contract
 * @author Maxos
 */
contract AnchorStrategy is IStrategyBase, IStrategyAssetValue, ReentrancyGuardUpgradeable {
  using SafeERC20 for IERC20;

  /*** Events ***/
  event InvestAnchorStrategy(uint256 amount);
  event RedeemAnchorStrategy(address indexed beneficiary, uint256 amount);

  /*** Constants ***/

  // USDC Anchor Conversion Pool
  IAnchorConversionPool public constant ANCHOR_CONVERSIONPOOL = IAnchorConversionPool(0x53fD7e8fEc0ac80cf93aA872026EadF50cB925f3);

  // Anchor Router
  IAnchorRouter public constant ANCHOR_ROUTER = IAnchorRouter(0xcEF9E167d3f8806771e9bac1d4a0d568c39a9388);

  // Anchor ExchangeRateFeeder
  IAnchorExchangeRateFeeder public constant ANCHOR_EXCHANGERATEFEEDER = IAnchorExchangeRateFeeder(0xd7c4f5903De8A256a1f535AC71CeCe5750d5197a);

  // USDC token interacted with the strategy
  IERC20 public constant USDC_TOKEN = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

  // Decimal number for total shares
  uint256 public constant DECIMALS = 2;

  // Total shares for the investment of Anchor vault
  uint256 public totalShares;

  // Address manager
  address public addressManager;

  modifier onlyBanker() {
    require(msg.sender == IAddressManager(addressManager).bankerContract(), "No banker");
    _;
  } 

  function initialize(address _addressManager) public initializer {
    __ReentrancyGuard_init();

    totalShares = 0;
    addressManager = _addressManager;
  }

  /**
   * @notice Invest token into Anchor USDC vault
   * @dev Token is transferred from the banker
   * @param _amount {uint256} USD amount to invest
   */
  function invest(uint256 _amount) external override nonReentrant onlyBanker {
    require(_amount > 0 && _amount <= USDC_TOKEN.balanceOf(address(this)), "Invalid amount");

    ANCHOR_CONVERSIONPOOL.deposit(_amount);
    totalShares += _amount;

    emit InvestAnchorStrategy(_amount);
  }

  /**
   * @notice Redeem token from Anchor vault and return it to "beneficiary"
   * @dev Transfer min(strategy balance, redemption amount) amount to requestor
   * @param _beneficiary {address} Redemption requestor
   * @param _amount {uint256} USD amount to redeem
   */
  function redeem(address _beneficiary, uint256 _amount) external override nonReentrant onlyBanker {


    emit RedeemAnchorStrategy(_beneficiary, _amount);
  }

  /**
   * @notice Returns asset value of the strategy form ANCHOR_EXCHANGERATEFEEDER contract
   * @return (uint256) asset value of the strategy in USD
   */
  function strategyAssetValue() external view override returns (uint256) {
    uint256 exchangeRate = ANCHOR_EXCHANGERATEFEEDER.exchangeRateOf(address(USDC_TOKEN), false);

    return 0;
  }
}
