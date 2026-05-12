// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {ITrustedIssuerRegistry} from "./interfaces/ITrustedIssuerRegistry.sol";
import {PolicyProtectedUpgradeable} from "@chainlink/policy-management/core/PolicyProtectedUpgradeable.sol";

/**
 * @title TrustedIssuerRegistry
 * @notice Chainlink-style registry of trusted issuer identifiers.
 * @dev Implementation of `ITrustedIssuerRegistry` using ERC-7201 storage and policy-engine
 * protection. The current vLEI Legal Entity path does not consult this registry at transfer time.
 */
contract TrustedIssuerRegistry is PolicyProtectedUpgradeable, ITrustedIssuerRegistry {
  /// @notice Registry type and semantic version.
  string public constant override typeAndVersion = "TrustedIssuerRegistry 1.0.0";

  /// @notice ERC-7201 storage bucket for trusted issuer state.
  /// @custom:storage-location erc7201:chainlink.ace.TrustedIssuerRegistry
  struct TrustedIssuerRegistryStorage {
    /// @notice Trust flag by issuer id hash.
    mapping(bytes32 issuerIdHash => bool isTrusted) trustedIssuers;
    /// @notice Enumerable list of trusted issuer id hashes.
    bytes32[] issuerList;
  }

  // keccak256(abi.encode(uint256(keccak256("chainlink.ace.TrustedIssuerRegistry")) - 1)) &
  // ~bytes32(uint256(0xff))
  // solhint-disable-next-line const-name-snakecase
  bytes32 private constant trustedIssuerRegistryStorageLocation =
    0x24368af76f28f75e0d3c893af5175655a9b97a18e82e58c43f9152ef16421900;

  /// @notice Returns the ERC-7201 storage bucket.
  /// @return $ Storage pointer for trusted issuer state.
  function _trustedIssuerRegistryStorage() private pure returns (TrustedIssuerRegistryStorage storage $) {
    assembly {
      $.slot := trustedIssuerRegistryStorageLocation
    }
  }

  /// @notice Disables initialization on the implementation contract.
  constructor() {
    _disableInitializers();
  }

  /**
   * @notice Initializes the trusted issuer registry and sets the policy engine.
   * @dev Must be called through the ERC1967 proxy deployment path.
   * @param policyEngine The address of the policy engine contract.
   * @param initialOwner The address that will own the newly created registry contract.
   */
  function initialize(address policyEngine, address initialOwner) public virtual initializer {
    __TrustedIssuerRegistry_init(policyEngine, initialOwner);
  }

  /// @notice Internal initializer for inherited policy-protected storage.
  /// @param policyEngine Policy engine address.
  /// @param initialOwner Initial registry owner.
  function __TrustedIssuerRegistry_init(address policyEngine, address initialOwner) internal onlyInitializing {
    __TrustedIssuerRegistry_init_unchained();
    __PolicyProtected_init(initialOwner, policyEngine);
  }

  /// @notice Internal unchained initializer reserved for future storage initialization.
  function __TrustedIssuerRegistry_init_unchained() internal onlyInitializing {}

  // ------------------------------------------------------------------------
  // Externals
  // ------------------------------------------------------------------------

  /// @inheritdoc ITrustedIssuerRegistry
  function addTrustedIssuer(
    string memory issuerId,
    bytes calldata context
  )
    external
    override
    runPolicyWithContext(context)
  {
    _addTrustedIssuer(issuerId, context);
  }

  /// @inheritdoc ITrustedIssuerRegistry
  function removeTrustedIssuer(
    string memory issuerId,
    bytes calldata context
  )
    external
    override
    runPolicyWithContext(context)
  {
    _removeTrustedIssuer(issuerId, context);
  }

  // ------------------------------------------------------------------------
  // internals
  // ------------------------------------------------------------------------

  /// @notice Internal implementation for adding a trusted issuer.
  /// @param issuerId Plain issuer identifier to trust.
  /// @param context Policy context passed through by the external function; currently unused.
  function _addTrustedIssuer(string memory issuerId, bytes calldata context) internal {
    if (bytes(issuerId).length == 0) {
      revert("issuerId cannot be empty");
    }

    bytes32 issuerIdHash = keccak256(abi.encodePacked(issuerId));

    TrustedIssuerRegistryStorage storage $ = _trustedIssuerRegistryStorage();
    if ($.trustedIssuers[issuerIdHash]) {
      revert("Issuer already trusted");
    }

    $.trustedIssuers[issuerIdHash] = true;
    $.issuerList.push(issuerIdHash);

    emit TrustedIssuerAdded(issuerIdHash, issuerId);
  }

  /// @notice Internal implementation for removing a trusted issuer.
  /// @param issuerId Plain issuer identifier to remove.
  /// @param context Policy context passed through by the external function; currently unused.
  function _removeTrustedIssuer(string memory issuerId, bytes calldata context) internal {
    if (bytes(issuerId).length == 0) {
      revert("issuerId cannot be empty");
    }

    bytes32 issuerIdHash = keccak256(abi.encodePacked(issuerId));

    TrustedIssuerRegistryStorage storage $ = _trustedIssuerRegistryStorage();
    if (!$.trustedIssuers[issuerIdHash]) {
      revert("Issuer not trusted");
    }

    $.trustedIssuers[issuerIdHash] = false;

    uint256 length = $.issuerList.length;
    for (uint256 i = 0; i < length; i++) {
      if ($.issuerList[i] == issuerIdHash) {
        $.issuerList[i] = $.issuerList[length - 1];
        $.issuerList.pop();
        break;
      }
    }

    emit TrustedIssuerRemoved(issuerIdHash, issuerId);
  }

  /// @notice Checks trust status from an issuer id hash.
  /// @param issuerIdHash Keccak256 hash of the issuer identifier string.
  /// @return True when the issuer id hash is trusted.
  function _isTrustedIssuer(bytes32 issuerIdHash) internal view returns (bool) {
    return _trustedIssuerRegistryStorage().trustedIssuers[issuerIdHash];
  }

  // ------------------------------------------------------------------------
  // View
  // ------------------------------------------------------------------------

  /// @inheritdoc ITrustedIssuerRegistry
  function getTrustedIssuers() public view virtual override returns (bytes32[] memory) {
    return _trustedIssuerRegistryStorage().issuerList;
  }

  /// @inheritdoc ITrustedIssuerRegistry
  function isTrustedIssuer(string memory issuerId) external view override returns (bool) {
    bytes32 issuerIdHash = keccak256(abi.encodePacked(issuerId));
    return _isTrustedIssuer(issuerIdHash);
  }
}
