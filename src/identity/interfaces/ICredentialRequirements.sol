// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

/**
 * @title ICredentialRequirements
 * @dev The interface for specifying the required credentials of an application/token.
 */
interface ICredentialRequirements {
  error RequirementExists(bytes32 requirementId);
  error RequirementNotFound(bytes32 requirementId);
  error SourceExists(bytes32 credentialTypeId, address identityRegistry, address credentialRegistry);
  error CredentialSourceNotFound(bytes32 credentialTypeId, address identityRegistry, address credentialRegistry);
  error InvalidRequirementConfiguration(string errorReason);

  struct CredentialRequirement {
    bytes32[] credentialTypeIds;
    uint256 minValidations;
    bool invert;
  }

  struct CredentialSource {
    address identityRegistry;
    address credentialRegistry;
    address dataValidator;
  }

  struct CredentialRequirementInput {
    bytes32 requirementId;
    bytes32[] credentialTypeIds;
    uint256 minValidations;
    bool invert;
  }

  struct CredentialSourceInput {
    bytes32 credentialTypeId;
    address identityRegistry;
    address credentialRegistry;
    address dataValidator;
  }

  event CredentialRequirementAdded(
    bytes32 indexed requirementId, bytes32[] credentialTypeIds, uint256 minValidations, bool invert
  );

  event CredentialRequirementRemoved(
    bytes32 indexed requirementId, bytes32[] credentialTypeIds, uint256 minValidations, bool invert
  );

  event CredentialSourceAdded(
    bytes32 indexed credentialTypeId,
    address indexed identityRegistry,
    address indexed credentialRegistry,
    address dataValidator
  );

  event CredentialSourceRemoved(
    bytes32 indexed credentialTypeId,
    address indexed identityRegistry,
    address indexed credentialRegistry,
    address dataValidator
  );

  function addCredentialRequirement(CredentialRequirementInput memory input) external;
  function removeCredentialRequirement(bytes32 requirementId) external;
  function getCredentialRequirement(bytes32 requirementId) external view returns (CredentialRequirement memory);
  function getCredentialRequirementIds() external view returns (bytes32[] memory);
  function addCredentialSource(CredentialSourceInput memory input) external;
  function removeCredentialSource(bytes32 credentialTypeId, address identityRegistry, address credentialRegistry) external;
  function getCredentialSources(bytes32 credentialTypeId) external view returns (CredentialSource[] memory);
}
