// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";

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
  using SafeMath for uint256;

  /*** Events ***/
  event InvestAnchorStrategy(uint256 amount);
  event RedeemAnchorStrategy(address indexed beneficiary, uint256 amount);

  /*** Constants ***/

  // USDC Anchor Conversion Pool
  IAnchorConversionPool public constant ANCHOR_CONVERSIONPOOL =
    IAnchorConversionPool(0x53fD7e8fEc0ac80cf93aA872026EadF50cB925f3);

  // Anchor Router
  IAnchorRouter public constant ANCHOR_ROUTER = IAnchorRouter(0xcEF9E167d3f8806771e9bac1d4a0d568c39a9388);

  // Anchor ExchangeRateFeeder
  IAnchorExchangeRateFeeder public constant ANCHOR_EXCHANGERATEFEEDER =
    IAnchorExchangeRateFeeder(0xd7c4f5903De8A256a1f535AC71CeCe5750d5197a);

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
   * @param _amount USD amount to invest
   */
  function invest(uint256 _amount) external override nonReentrant onlyBanker {
    ERC20 usdc = ERC20(IAddressManager(addressManager).USDC());

    require(_amount > 0 && _amount <= usdc.balanceOf(address(this)), "Invalid amount");

    usdc.approve(address(ANCHOR_CONVERSIONPOOL), _amount);
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
    ERC20 aUsdc = ERC20(IAddressManager(addressManager).aUSDC());

    require(_amount > 0 && _amount <= totalShares, "Invalid amount");

    uint256 _shares = _amount.mul(1e12);
    aUsdc.approve(address(ANCHOR_CONVERSIONPOOL), _shares);

    ANCHOR_CONVERSIONPOOL.redeem(_shares);
    totalShares -= _amount;

    emit RedeemAnchorStrategy(_beneficiary, _amount);
  }

  /**
   * @notice Returns asset value of the strategy
   * @return (uint256) asset value of the strategy in USD
   */
  function strategyAssetValue() external view override returns (uint256) {
    ERC20 usdc = ERC20(IAddressManager(addressManager).USDC());

    uint256 exchangeRate = ANCHOR_EXCHANGERATEFEEDER.exchangeRateOf(address(usdc), false);
    return (totalShares * exchangeRate) / 10**18;
  }
}
