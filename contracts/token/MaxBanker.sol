//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesCompUpgradeable.sol";

import "../interfaces/ITransferApprover.sol";

/**
 * @notice MaxBanker Contract
 * @author Maxos
 */
contract MaxBanker is PausableUpgradeable, OwnableUpgradeable, ERC20VotesCompUpgradeable {
  /*** Events ***/
  event Mint(address indexed to, uint256 amount);
  event Burn(address indexed from, uint256 amount);

  /*** Constants ***/

  /*** Storage Properties ***/
  address public mintContract;
  address public ownerOnlyApprover;

  /*** Contract Logic Starts Here */

  modifier onlyMinter() {
    require(msg.sender == owner() || msg.sender == mintContract, "No minter");
    _;
  }

  function initialize(string memory name, string memory symbol) public initializer {
    __ERC20_init_unchained(name, symbol);
    __ERC20VotesComp_init_unchained();
    __Ownable_init_unchained();
    __Pausable_init();
  }

  /**
   * @notice Mint the token
   * @dev caller must have the minter role
   * @param to address to receive the token minted
   * @param amount token amount to be minted
   */
  function mint(address to, uint256 amount) external onlyMinter whenNotPaused {
    _mint(to, amount);

    emit Mint(to, amount);
  }

  /**
   * @notice Burn `amount` tokens from the caller
   * @param amount token amount to burn
   */
  function burn(uint256 amount) external whenNotPaused {
    _burn(msg.sender, amount);

    emit Burn(address(this), amount);
  }

  /**
   * @notice Pause MaxBaner
   */
  function pause() external onlyOwner whenNotPaused {
    _pause();
  }

  /**
   * @notice Unpause MaxBaner
   */
  function unpause() external onlyOwner whenPaused {
    _unpause();
  }

  /**
   * @notice Set mintable/burnable contract address
   * @param _mintContract contract address to mint/burn tokens
   */
  function setMintContract(address _mintContract) external onlyOwner {
    mintContract = _mintContract;
  }

  /**
   * @notice Set TransferApprovr contract address
   * @param _ownerOnlyApprover OnlyOnwerApprover contract address
   */
  function setOwnerOnlyApprover(address _ownerOnlyApprover) external onlyOwner {
    ownerOnlyApprover = _ownerOnlyApprover;
  }

  /**
   * @notice Hook that is called before any transfer of Tokens
   * @param from sender address
   * @param to beneficiary address
   * @param amount token amount
   */
  function _beforeTokenTransfer(address from, address to, uint256 amount) internal view override whenNotPaused {
    if (ownerOnlyApprover != address(0)) {
      require(ITransferApprover(ownerOnlyApprover).checkTransfer(from, to));
    }
  }
}
