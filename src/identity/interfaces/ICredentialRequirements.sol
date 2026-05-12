// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

/**
 * @title ICredentialRequirements
 * @notice Interface for configuring credential requirements and credential sources.
 * @dev This Chainlink-style component can express "N of M" credential requirements for
 * a validator. The first-pass vLEI verifier does not depend on it for pass/fail decisions.
 */
interface ICredentialRequirements {
  /// @notice Reverts when adding a duplicate requirement id.
  /// @param requirementId Requirement id that already exists.
  error RequirementExists(bytes32 requirementId);
  /// @notice Reverts when removing or fetching an unknown requirement id.
  /// @param requirementId Requirement id that was not found.
  error RequirementNotFound(bytes32 requirementId);
  /// @notice Reverts when adding a duplicate source for a credential type.
  /// @param credentialTypeId Credential type already served by the source pair.
  /// @param identityRegistry Identity registry address in the duplicate source.
  /// @param credentialRegistry Credential registry address in the duplicate source.
  error SourceExists(bytes32 credentialTypeId, address identityRegistry, address credentialRegistry);
  /// @notice Reverts when removing an unknown credential source.
  /// @param credentialTypeId Credential type for the missing source.
  /// @param identityRegistry Identity registry address for the missing source.
  /// @param credentialRegistry Credential registry address for the missing source.
  error CredentialSourceNotFound(bytes32 credentialTypeId, address identityRegistry, address credentialRegistry);
  /// @notice Reverts when a requirement/source violates implementation limits or invariants.
  /// @param errorReason Human-readable configuration failure reason.
  error InvalidRequirementConfiguration(string errorReason);

  /// @notice Requirement describing which credential types can satisfy one check.
  struct CredentialRequirement {
    /// @notice Credential type identifiers considered for this requirement.
    bytes32[] credentialTypeIds;
    /// @notice Minimum number of valid credentials required to satisfy the requirement.
    uint256 minValidations;
    /// @notice When true, the requirement is satisfied by absence rather than presence.
    bool invert;
  }

  /// @notice Registry and optional data validator used to check a credential type.
  struct CredentialSource {
    /// @notice Identity registry used to resolve wallet to CCID.
    address identityRegistry;
    /// @notice Credential registry used to validate CCID credential status.
    address credentialRegistry;
    /// @notice Optional validator for inspecting credential payload bytes.
    address dataValidator;
  }

  /// @notice Input shape for creating a credential requirement.
  struct CredentialRequirementInput {
    /// @notice Stable requirement identifier.
    bytes32 requirementId;
    /// @notice Credential type identifiers accepted for the requirement.
    bytes32[] credentialTypeIds;
    /// @notice Minimum number of validations required.
    uint256 minValidations;
    /// @notice Whether absence of matching credentials should satisfy the requirement.
    bool invert;
  }

  /// @notice Input shape for creating a credential source.
  struct CredentialSourceInput {
    /// @notice Credential type served by this source.
    bytes32 credentialTypeId;
    /// @notice Identity registry address used by the source.
    address identityRegistry;
    /// @notice Credential registry address used by the source.
    address credentialRegistry;
    /// @notice Optional credential data validator.
    address dataValidator;
  }

  /// @notice Emitted when a credential requirement is added.
  /// @param requirementId Stable requirement identifier.
  /// @param credentialTypeIds Credential type identifiers accepted by the requirement.
  /// @param minValidations Minimum number of valid credentials required.
  /// @param invert Whether absence satisfies the requirement.
  event CredentialRequirementAdded(
    bytes32 indexed requirementId, bytes32[] credentialTypeIds, uint256 minValidations, bool invert
  );

  /// @notice Emitted when a credential requirement is removed.
  /// @param requirementId Stable requirement identifier.
  /// @param credentialTypeIds Credential type identifiers formerly accepted.
  /// @param minValidations Former minimum number of valid credentials required.
  /// @param invert Former inversion behavior.
  event CredentialRequirementRemoved(
    bytes32 indexed requirementId, bytes32[] credentialTypeIds, uint256 minValidations, bool invert
  );

  /// @notice Emitted when a credential source is added.
  /// @param credentialTypeId Credential type served by the source.
  /// @param identityRegistry Identity registry used to resolve wallet to CCID.
  /// @param credentialRegistry Credential registry used for validation.
  /// @param dataValidator Optional payload validator.
  event CredentialSourceAdded(
    bytes32 indexed credentialTypeId,
    address indexed identityRegistry,
    address indexed credentialRegistry,
    address dataValidator
  );

  /// @notice Emitted when a credential source is removed.
  /// @param credentialTypeId Credential type formerly served by the source.
  /// @param identityRegistry Identity registry used by the removed source.
  /// @param credentialRegistry Credential registry used by the removed source.
  /// @param dataValidator Payload validator used by the removed source.
  event CredentialSourceRemoved(
    bytes32 indexed credentialTypeId,
    address indexed identityRegistry,
    address indexed credentialRegistry,
    address dataValidator
  );

  /// @notice Adds a credential requirement.
  /// @param input Requirement configuration.
  function addCredentialRequirement(CredentialRequirementInput memory input) external;

  /// @notice Removes a credential requirement.
  /// @param requirementId Requirement identifier to remove.
  function removeCredentialRequirement(bytes32 requirementId) external;

  /// @notice Returns a credential requirement.
  /// @param requirementId Requirement identifier to fetch.
  /// @return Credential requirement configuration.
  function getCredentialRequirement(bytes32 requirementId) external view returns (CredentialRequirement memory);

  /// @notice Returns all configured requirement ids.
  /// @return Requirement identifiers.
  function getCredentialRequirementIds() external view returns (bytes32[] memory);

  /// @notice Adds a credential source.
  /// @param input Credential source configuration.
  function addCredentialSource(CredentialSourceInput memory input) external;

  /// @notice Removes a credential source.
  /// @param credentialTypeId Credential type served by the source.
  /// @param identityRegistry Identity registry address.
  /// @param credentialRegistry Credential registry address.
  function removeCredentialSource(bytes32 credentialTypeId, address identityRegistry, address credentialRegistry) external;

  /// @notice Returns credential sources for a credential type.
  /// @param credentialTypeId Credential type identifier.
  /// @return Sources configured for the credential type.
  function getCredentialSources(bytes32 credentialTypeId) external view returns (CredentialSource[] memory);
}
