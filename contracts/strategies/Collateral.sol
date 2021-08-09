// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

contract Collateral is ERC20Upgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
  using SafeERC20 for IERC20;

  // Strategy currently in use by the Collateral
  address public strategy;

  // Treasury address
  address public treasury;

  // Fee factors
  uint256 public mintingFeeFactor;
  uint256 public redemptionFeeFactor;
  uint256 public constant FEE_DENOMINATOR = 10000;

  // Maximum allowed deposited amount of tokens
  uint256 public depositCap;

  uint256 public totalAmountDeposited;

  // Collateral token
  IERC20 public baseToken;

  function initialize(
    address _tokenAddress,
    address _treasury,
    string memory _tokenSymbol
  ) public initializer {
    __Ownable_init();
    __ReentrancyGuard_init();
    __ERC20_init(string(abi.encodePacked("Collateral ", _tokenSymbol)), string(abi.encodePacked("c", _tokenSymbol)));
    baseToken = IERC20(_tokenAddress);
    mintingFeeFactor = 10;
    redemptionFeeFactor = 10;
    treasury = _treasury;
    depositCap = 0;
  }

  function setStrategyController(address _strategy) external onlyOwner {
    require(_strategy != address(0), "invalid strategy controller");
    strategy = _strategy;
  }

  function setDepositCap(uint256 _depositCap) external onlyOwner {
    depositCap = _depositCap;
  }

  function setMintingFeeFactor(uint256 _mintingFeeFactor) external onlyOwner {
    require(_mintingFeeFactor > 0 && _mintingFeeFactor < FEE_DENOMINATOR, "invalid minting fee factor");
    mintingFeeFactor = _mintingFeeFactor;
  }

  function setRedemptionFeeFactor(uint256 _redemptionFeeFactor) external onlyOwner {
    require(_redemptionFeeFactor > 0 && _redemptionFeeFactor < FEE_DENOMINATOR, "invalid redemption fee factor");
    redemptionFeeFactor = _redemptionFeeFactor;
  }

  /**
   * @dev It calculates the toal underlying value of {token} held by the system.
   * TODO It takes into account the collateral contract balance and the strategy controller contract balance
   */
  function balance() public view returns (uint256) {
    return baseToken.balanceOf(address(this));
  }

  /**
   * @dev Custom logic in here for how much the collateral allows to be borrowed.
   * We return 100% of tokens for now. Under certain conditions we might
   * want to keep some of the system funds at hand in the collateral, instead
   * of putting them to work.
   */
  function available() public view returns (uint256) {
    return baseToken.balanceOf(address(this));
  }

  /**
   * @dev The entrypoint of funds into the system.
   * Tokens can be deposited as collateral with this function.
   * The collateral is then in charge of sending assets into the strategy controller.
   */
  function deposit(uint256 _amount) external nonReentrant {
    require(_amount > 0 && _amount + totalAmountDeposited <= depositCap, "deposit cap exceeded");

    uint256 mintingFee = (_amount * mintingFeeFactor) / FEE_DENOMINATOR;
    baseToken.safeTransferFrom(msg.sender, treasury, mintingFee);

    _amount -= mintingFee;
    uint256 _before = baseToken.balanceOf(address(this));
    baseToken.safeTransferFrom(msg.sender, address(this), _amount);
    uint256 _after = baseToken.balanceOf(address(this));
    _amount = _after - _before;
    totalAmountDeposited += _amount;

    uint256 _shares = 0;
    if (totalSupply() == 0) {
      _shares = _amount;
    } else {
      _shares = (_amount * totalSupply()) / _before;
    }
    _mint(msg.sender, _shares);
  }

  /**
   * @dev Function to send funds into the strategy controller and put them to work.
   *  It's primarily called by deposit() function.
   */
  function earn() external {
    uint256 _bal = available();
    baseToken.safeApprove(strategy, _bal);
    // TODO Deposit {_bal} into the strategy controller
  }

  /**
   * @dev Function to exit the system. The collateral will withdraw the required tokens
   * from the strategy controller and pay up the token holder. A proportional number of IOU
   * tokens are burned in the process.
   */
  function withdraw(uint256 _shares) external nonReentrant {
    uint256 redemptionFee = (_shares * redemptionFeeFactor) / FEE_DENOMINATOR;
    baseToken.safeTransferFrom(msg.sender, treasury, redemptionFee);

    _shares -= redemptionFee;
    uint256 _amount = (balance() * _shares) / totalSupply();
    _burn(msg.sender, _shares);

    uint256 _before = baseToken.balanceOf(address(this));
    if (_before < _amount) {
      uint256 _withdraw = _amount - _before;
      // TODO Withdraw {_withdraw} from the strategy controller
      uint256 _after = baseToken.balanceOf(address(this));
      uint256 _diff = _after - _before;
      if (_diff < _withdraw) {
        _amount = _before + _diff;
      }
    }

    baseToken.safeTransfer(msg.sender, _amount);
  }
}
