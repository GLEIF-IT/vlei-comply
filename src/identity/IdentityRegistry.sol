// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {IIdentityRegistry} from "./interfaces/IIdentityRegistry.sol";
import {PolicyProtectedUpgradeable} from "@chainlink/policy-management/core/PolicyProtectedUpgradeable.sol";

/**
 * @title IdentityRegistry
 * @notice Chainlink-style registry mapping local wallet accounts to CCIDs.
 * @dev This is proxy-initialized in deployment and protected by the configured policy engine.
 * In the vLEI demo, the CCID is interpreted as `keccak256(bytes(canonicalAidString))`.
 */
contract IdentityRegistry is PolicyProtectedUpgradeable, IIdentityRegistry {
  /// @notice Registry type and semantic version.
  string public constant override typeAndVersion = "IdentityRegistry 1.0.0";

  /// @notice ERC-7201 storage bucket for account-to-CCID mappings.
  /// @custom:storage-location erc7201:chainlink.ace.IdentityRegistry
  struct IdentityRegistryStorage {
    /// @notice Maps a local account to its registered CCID.
    mapping(address account => bytes32 ccid) accountToCcid;
    /// @notice Lists all accounts registered to a CCID.
    mapping(bytes32 ccid => address[] accounts) ccidToAccounts;
    /// @notice Maps ccid/account to index + 1 in `ccidToAccounts`; zero means not registered.
    mapping(bytes32 ccid => mapping(address account => uint256 index)) accountIndex;
  }

  // keccak256(abi.encode(uint256(keccak256("chainlink.ace.IdentityRegistry")) - 1)) &
  // ~bytes32(uint256(0xff))
  // solhint-disable-next-line const-name-snakecase
  bytes32 private constant identityRegistryStorageLocation =
    0x31dacf4de1329b533dc7ad419a7ae424eacaaf799ae802e5d062dea412180200;

  /// @notice Returns the ERC-7201 storage bucket.
  /// @return $ Storage pointer for identity registry state.
  function _identityRegistryStorage() private pure returns (IdentityRegistryStorage storage $) {
    // solhint-disable-next-line no-inline-assembly
    assembly {
      $.slot := identityRegistryStorageLocation
    }
  }

  /**
   * @notice Initializes the identity registry and sets the policy engine.
   * @dev Must be called through the ERC1967 proxy deployment path.
   * @param policyEngine The address of the policy engine contract.
   * @param initialOwner The address that will own the newly created registry contract.
   */
  function initialize(address policyEngine, address initialOwner) public virtual initializer {
    __IdentityRegistry_init(policyEngine, initialOwner);
  }

  /// @notice Internal initializer for inherited storage.
  /// @param policyEngine Policy engine address.
  /// @param initialOwner Initial registry owner.
  function __IdentityRegistry_init(address policyEngine, address initialOwner) internal onlyInitializing {
    __IdentityRegistry_init_unchained();
    __PolicyProtected_init(initialOwner, policyEngine);
  }

  /// @notice Internal unchained initializer reserved for future storage initialization.
  // solhint-disable-next-line no-empty-blocks
  function __IdentityRegistry_init_unchained() internal onlyInitializing {}

  /// @inheritdoc IIdentityRegistry
  function registerIdentity(
    bytes32 ccid,
    address account,
    bytes calldata context
  )
    public
    virtual
    override
    runPolicyWithContext(context)
  {
    _registerIdentity(ccid, account, context);
  }

  /// @inheritdoc IIdentityRegistry
  function registerIdentities(
    bytes32[] calldata ccids,
    address[] calldata accounts,
    bytes calldata context
  )
    public
    virtual
    override
    runPolicyWithContext(context)
  {
    if (ccids.length == 0 || ccids.length != accounts.length) {
      revert InvalidIdentityConfiguration("Invalid input length");
    }
    for (uint256 i = 0; i < ccids.length; i++) {
      _registerIdentity(ccids[i], accounts[i], context);
    }
  }

  /// @notice Internal implementation for wallet-to-CCID registration.
  /// @param ccid Cross-chain identity to register.
  /// @param account Local wallet account to associate with the CCID.
  function _registerIdentity(bytes32 ccid, address account, bytes calldata /*context*/ ) internal {
    if (ccid == bytes32(0)) {
      revert InvalidIdentityConfiguration("CCID cannot be empty");
    }
    if (_identityRegistryStorage().accountToCcid[account] != bytes32(0)) {
      revert IdentityAlreadyRegistered(ccid, account);
    }
    _identityRegistryStorage().accountToCcid[account] = ccid;
    _identityRegistryStorage().ccidToAccounts[ccid].push(account);
    // Store index + 1 (so 0 means not found)
    _identityRegistryStorage().accountIndex[ccid][account] = _identityRegistryStorage().ccidToAccounts[ccid].length;
    emit IdentityRegistered(ccid, account);
  }

  /// @inheritdoc IIdentityRegistry
  function removeIdentity(
    bytes32 ccid,
    address account,
    bytes calldata context
  )
    public
    virtual
    override
    runPolicyWithContext(context)
  {
    uint256 indexPlusOne = _identityRegistryStorage().accountIndex[ccid][account];
    if (indexPlusOne == 0) {
      revert IdentityNotFound(ccid, account);
    }

    uint256 index = indexPlusOne - 1;
    uint256 lastIndex = _identityRegistryStorage().ccidToAccounts[ccid].length - 1;

    if (index != lastIndex) {
      // Move the last element to the position being removed
      address lastAccount = _identityRegistryStorage().ccidToAccounts[ccid][lastIndex];
      _identityRegistryStorage().ccidToAccounts[ccid][index] = lastAccount;
      // Update the moved account's index
      _identityRegistryStorage().accountIndex[ccid][lastAccount] = indexPlusOne;
    }

    // Remove the last element
    _identityRegistryStorage().ccidToAccounts[ccid].pop();
    delete _identityRegistryStorage().accountToCcid[account];
    delete _identityRegistryStorage().accountIndex[ccid][account];

    emit IdentityRemoved(ccid, account);
  }

  /// @inheritdoc IIdentityRegistry
  function getIdentity(address account) public view virtual override returns (bytes32) {
    return _identityRegistryStorage().accountToCcid[account];
  }

  /// @inheritdoc IIdentityRegistry
  function getAccounts(bytes32 ccid) public view virtual override returns (address[] memory) {
    return _identityRegistryStorage().ccidToAccounts[ccid];
  }
}
