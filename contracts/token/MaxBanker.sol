//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

/**
 * @notice MaxBanker Contract
 * @author Maxos
 */
contract MaxBanker is PausableUpgradeable, OwnableUpgradeable, ERC20Upgradeable {
  /*** Events ***/
  event Mint(address indexed to, uint256 amount);
  event Burn(address indexed from, uint256 amount);
  event TransferFailed(address indexed from, address indexed to, uint256 _amount, uint256 indexed transferControl);

  /*** Constants ***/

  /*** Storage Properties ***/
  address public mintContract;
  uint256 public transferControl;
  mapping(address => bool) public whiteList;

  /*** Contract Logic Starts Here */

  modifier onlyMinter() {
    require(msg.sender == super.owner() || msg.sender == mintContract, "No minter");
    _;
  }

  function initialize(string memory name, string memory symbol) public initializer {
    __ERC20_init_unchained(name, symbol);
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
    super._pause();
  }

  /**
   * @notice Unpause MaxBaner
   */
  function unpause() external onlyOwner whenPaused {
    super._unpause();
  }

  /**
   * @notice Set mintable/burnable contract address
   * @param _mintContract contract address to mint/burn tokens
   */
  function setMintContract(address _mintContract) external onlyOwner {
    mintContract = _mintContract;
  }

  /**
   * @notice Add address into the white list
   * @param _addAddress address to add
   */
   function addWhiteList(address _addAddress) external onlyOwner {
       require(!whiteList[_addAddress], "Already exists");
       whiteList[_addAddress] = true;
   }

   /**
   * @notice Remove address from the white list
   * @param _removeAddress address to remove
   */
   function removeWhiteList(address _removeAddress) external onlyOwner {
       require(whiteList[_removeAddress], "No exists");
       whiteList[_removeAddress] = false;
   }

  /**
   * @notice Set token transfer restriction
   *    0 - No restriction,
   *    1 - Only owner can send/receive tokens,
   *    2 - Only addresses in the white list can receive tokens,
   *    3 - The addressess in the white list can't receive tokens.
   *    4+ - No restriction
   * @param _transferControl transferring restriction
   */
    function setTransferCondtion(uint256 _transferControl) external onlyOwner {
        transferControl = _transferControl;
    }
    
    /**
     * @notice Determine if token transfer is approved
     * @param _from sender address
     * @param _to beneficiary address
     * @param _amount token amount
     * @return (bool) approved or not
     */
     function _transferApprover(address _from, address _to, uint256 _amount) internal returns (bool) {
        if (transferControl == 1) {
            if (_from != super.owner() && _to != super.owner()) {
                emit TransferFailed(_from, _to, _amount, transferControl);
                return false;
            }
        } else if (transferControl == 2) {
            if (!whiteList[_to]) {
                emit TransferFailed(_from, _to, _amount, transferControl);
                return false;
            }
        } else if (transferControl == 3) {
            if (whiteList[_to]) {
                emit TransferFailed(_from, _to, _amount, transferControl);
                return false;
            }
        }

        return true;
     }

  /**
   * @notice Hook that is called before any transfer of Tokens
   * @param from sender address
   * @param to beneficiary address
   * @param amount token amount
   */
    function _beforeTokenTransfer(address from, address to, uint256 amount ) internal override {
        require(_transferApprover(from, to, amount));
    }

}
