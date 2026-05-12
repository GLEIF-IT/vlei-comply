// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {ICredentialValidator} from "./ICredentialValidator.sol";

/**
 * @title ICredentialRegistry
 * @notice Registry interface for credentials attached to Chainlink CCIDs.
 * @dev The vLEI first-pass compliance path deploys this registry for compatibility and
 * future credential-layer expansion; current vLEI pass/fail decisions use `VLEIOracleRegistry`.
 */
interface ICredentialRegistry is ICredentialValidator {
  /// @notice Error emitted when a credential type identifier is already registered to the ccid.
  /// @param ccid Cross-chain identity that already has the credential.
  /// @param credentialTypeId Credential type identifier already registered.
  error CredentialAlreadyRegistered(bytes32 ccid, bytes32 credentialTypeId);
  /// @notice Error emitted when a credential type identifier is not found to be associated to the ccid.
  /// @param ccid Cross-chain identity missing the credential.
  /// @param credentialTypeId Credential type identifier not found.
  error CredentialNotFound(bytes32 ccid, bytes32 credentialTypeId);
  /// @notice Error emitted when an invalid credential configuration was attempted.
  /// @param errorReason Human-readable configuration failure reason.
  error InvalidCredentialConfiguration(string errorReason);

  /// @notice Credential data and expiration attached to a CCID and credential type.
  struct Credential {
    /// @notice Expiration timestamp. A zero value means no expiration.
    uint40 expiresAt;
    /// @notice Opaque credential payload interpreted by higher-level validators.
    bytes credentialData;
  }

  /// @notice Emitted when a credential is registered for a CCID.
  /// @param ccid Cross-chain identity receiving the credential.
  /// @param credentialTypeId Credential type identifier.
  /// @param expiresAt Expiration timestamp, or zero for non-expiring.
  /// @param credentialData Opaque credential payload.
  event CredentialRegistered(
    bytes32 indexed ccid, bytes32 indexed credentialTypeId, uint40 expiresAt, bytes credentialData
  );

  /// @notice Emitted when a credential is removed from a CCID.
  /// @param ccid Cross-chain identity losing the credential.
  /// @param credentialTypeId Credential type identifier removed.
  event CredentialRemoved(bytes32 indexed ccid, bytes32 indexed credentialTypeId);

  /// @notice Emitted when an existing credential expiration is changed.
  /// @param ccid Cross-chain identity whose credential was renewed.
  /// @param credentialTypeId Credential type identifier renewed.
  /// @param previousExpiresAt Previous expiration timestamp.
  /// @param expiresAt New expiration timestamp.
  event CredentialRenewed(
    bytes32 indexed ccid, bytes32 indexed credentialTypeId, uint40 previousExpiresAt, uint40 expiresAt
  );

  /// @notice Returns the registry type and semantic version.
  /// @return Type/version string used by Chainlink-style integrations.
  function typeAndVersion() external pure returns (string memory);

  /// @notice Registers a credential for a CCID.
  /// @dev Implementations should run policy checks before mutation and reject expired timestamps.
  /// @param ccid Cross-chain identity receiving the credential.
  /// @param credentialTypeId Credential type identifier.
  /// @param expiresAt Expiration timestamp, or zero for non-expiring.
  /// @param credentialData Opaque credential payload.
  /// @param context Policy engine context bytes.
  function registerCredential(
    bytes32 ccid,
    bytes32 credentialTypeId,
    uint40 expiresAt,
    bytes calldata credentialData,
    bytes calldata context
  )
    external;

  /// @notice Registers multiple credentials for the same CCID.
  /// @param ccid Cross-chain identity receiving the credentials.
  /// @param credentialTypeIds Credential type identifiers.
  /// @param expiresAt Shared expiration timestamp, or zero for non-expiring.
  /// @param credentialDatas Opaque credential payloads aligned with `credentialTypeIds`.
  /// @param context Policy engine context bytes.
  function registerCredentials(
    bytes32 ccid,
    bytes32[] calldata credentialTypeIds,
    uint40 expiresAt,
    bytes[] calldata credentialDatas,
    bytes calldata context
  )
    external;

  /// @notice Removes a credential from a CCID.
  /// @param ccid Cross-chain identity whose credential is removed.
  /// @param credentialTypeId Credential type identifier.
  /// @param context Policy engine context bytes.
  function removeCredential(bytes32 ccid, bytes32 credentialTypeId, bytes calldata context) external;

  /// @notice Updates an existing credential expiration.
  /// @param ccid Cross-chain identity whose credential is renewed.
  /// @param credentialTypeId Credential type identifier.
  /// @param expiresAt New expiration timestamp, or zero for non-expiring.
  /// @param context Policy engine context bytes.
  function renewCredential(bytes32 ccid, bytes32 credentialTypeId, uint40 expiresAt, bytes calldata context) external;

  /// @notice Returns whether a registered credential is expired.
  /// @param ccid Cross-chain identity to check.
  /// @param credentialTypeId Credential type identifier to check.
  /// @return True when the credential has a nonzero expiration at or before the current block timestamp.
  function isCredentialExpired(bytes32 ccid, bytes32 credentialTypeId) external view returns (bool);

  /// @notice Returns all credential types registered for a CCID.
  /// @param ccid Cross-chain identity to inspect.
  /// @return Credential type identifiers associated with the CCID.
  function getCredentialTypes(bytes32 ccid) external view returns (bytes32[] memory);

  /// @notice Returns one credential payload.
  /// @param ccid Cross-chain identity to inspect.
  /// @param credentialTypeId Credential type identifier to fetch.
  /// @return Credential record for the CCID and type.
  function getCredential(bytes32 ccid, bytes32 credentialTypeId) external view returns (Credential memory);

  /// @notice Returns multiple credential payloads.
  /// @param ccid Cross-chain identity to inspect.
  /// @param credentialTypeIds Credential type identifiers to fetch.
  /// @return Credential records aligned with `credentialTypeIds`.
  function getCredentials(
    bytes32 ccid,
    bytes32[] calldata credentialTypeIds
  )
    external
    view
    returns (Credential[] memory);
}
