// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {ICredentialValidator} from "./ICredentialValidator.sol";

/**
 * @title ICredentialRegistry
 * @dev Interface for managing the credential registry.
 */
interface ICredentialRegistry is ICredentialValidator {
  /// @notice Error emitted when a credential type identifier is already registered to the ccid.
  error CredentialAlreadyRegistered(bytes32 ccid, bytes32 credentialTypeId);
  /// @notice Error emitted when a credential type identifier is not found to be associated to the ccid.
  error CredentialNotFound(bytes32 ccid, bytes32 credentialTypeId);
  /// @notice Error emitted when an invalid credential configuration was attempted.
  error InvalidCredentialConfiguration(string errorReason);

  struct Credential {
    uint40 expiresAt;
    bytes credentialData;
  }

  event CredentialRegistered(
    bytes32 indexed ccid, bytes32 indexed credentialTypeId, uint40 expiresAt, bytes credentialData
  );

  event CredentialRemoved(bytes32 indexed ccid, bytes32 indexed credentialTypeId);

  event CredentialRenewed(
    bytes32 indexed ccid, bytes32 indexed credentialTypeId, uint40 previousExpiresAt, uint40 expiresAt
  );

  function typeAndVersion() external pure returns (string memory);

  function registerCredential(
    bytes32 ccid,
    bytes32 credentialTypeId,
    uint40 expiresAt,
    bytes calldata credentialData,
    bytes calldata context
  )
    external;

  function registerCredentials(
    bytes32 ccid,
    bytes32[] calldata credentialTypeIds,
    uint40 expiresAt,
    bytes[] calldata credentialDatas,
    bytes calldata context
  )
    external;

  function removeCredential(bytes32 ccid, bytes32 credentialTypeId, bytes calldata context) external;

  function renewCredential(bytes32 ccid, bytes32 credentialTypeId, uint40 expiresAt, bytes calldata context) external;

  function isCredentialExpired(bytes32 ccid, bytes32 credentialTypeId) external view returns (bool);

  function getCredentialTypes(bytes32 ccid) external view returns (bytes32[] memory);

  function getCredential(bytes32 ccid, bytes32 credentialTypeId) external view returns (Credential memory);

  function getCredentials(
    bytes32 ccid,
    bytes32[] calldata credentialTypeIds
  )
    external
    view
    returns (Credential[] memory);
}
