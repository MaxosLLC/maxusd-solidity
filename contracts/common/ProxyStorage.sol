// SPDX-License-Identifier: MIT
pragma solidity 0.6.10;

// solhint-disable max-states-count, var-name-mixedcase

/**
 * Defines the storage layout of the token implementation contract. Any
 * newly declared state variables in future upgrades should be appended
 * to the bottom. Never remove state variables from this list, however variables
 * can be renamed. Please add _Deprecated to deprecated variables.
 */
contract ProxyStorage {
  address public owner;
  address public pendingOwner;

  bool internal initialized;

  address internal balances_Deprecated;
  address internal allowances_Deprecated;

  uint256 internal _totalSupply;

  bool internal paused_Deprecated = false;
  address internal globalPause_Deprecated;

  uint256 public burnMin = 0;
  uint256 public burnMax = 0;

  address internal registry_Deprecated;

  string internal name_Deprecated;
  string internal symbol_Deprecated;

  uint256[] internal gasRefundPool_Deprecated;
  uint256 internal redemptionAddressCount_Deprecated;
  uint256 internal minimumGasPriceForFutureRefunds_Deprecated;

  mapping(address => uint256) internal _balances;
  mapping(address => mapping(address => uint256)) internal _allowances;
  mapping(bytes32 => mapping(address => uint256)) internal attributes_Deprecated;

  // reward token storage
  mapping(address => address) internal finOps_Deprecated;
  mapping(address => mapping(address => uint256)) internal finOpBalances_Deprecated;
  mapping(address => uint256) internal finOpSupply_Deprecated;

  // max reward allocation
  // proportion: 1000 = 100%
  struct RewardAllocation {
    uint256 proportion;
    address finOp;
  }
  mapping(address => RewardAllocation[]) internal _rewardDistribution_Deprecated;
  uint256 internal maxRewardProportion_Deprecated = 1000;

  mapping(address => bool) internal isBlacklisted;
  mapping(address => bool) public canBurn;

  /* Additionally, we have several keccak-based storage locations.
   * If you add more keccak-based storage mappings, such as mappings, you must document them here.
   * If the length of the keccak input is the same as an existing mapping, it is possible there could be a preimage collision.
   * A preimage collision can be used to attack the contract by treating one storage location as another,
   * which would always be a critical issue.
   * Carefully examine future keccak-based storage to ensure there can be no preimage collisions.
   *******************************************************************************************************
   ** length     input                                                         usage
   *******************************************************************************************************
   ** 18         "maxXXX.proxy.owner"                                         Proxy Owner
   ** 26         "maxXXX.pending.proxy.owner"                                 Pending Proxy Owner
   ** 27         "maxXXX.proxy.implementation"                                Proxy Implementation
   ** 32         uint256(11)                                                   gasRefundPool_Deprecated
   ** 64         uint256(address),uint256(14)                                  balanceOf
   ** 64         uint256(address),keccak256(uint256(address),uint256(15))      allowance
   ** 64         uint256(address),keccak256(bytes32,uint256(16))               attributes
   **/
}
