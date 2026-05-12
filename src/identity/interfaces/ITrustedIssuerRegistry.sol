// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

/**
 * @title ITrustedIssuerRegistry
 * @notice Interface for managing trusted issuer identifiers.
 * @dev This registry is a Chainlink-style compatibility component. The first-pass vLEI oracle
 * path does not currently consult trusted issuer state for transfer pass/fail decisions.
 */
interface ITrustedIssuerRegistry {
  /// @notice Emitted when an issuer identifier is trusted.
  /// @param issuerIdHash Keccak256 hash of the issuer identifier string.
  /// @param issuerId Plain issuer identifier supplied to the registry.
  event TrustedIssuerAdded(bytes32 indexed issuerIdHash, string issuerId);

  /// @notice Emitted when an issuer identifier is removed from the trusted set.
  /// @param issuerIdHash Keccak256 hash of the issuer identifier string.
  /// @param issuerId Plain issuer identifier supplied to the registry.
  event TrustedIssuerRemoved(bytes32 indexed issuerIdHash, string issuerId);

  /// @notice Returns the registry type and semantic version.
  /// @return Type/version string used by Chainlink-style integrations.
  function typeAndVersion() external pure returns (string memory);

  /// @notice Adds an issuer identifier to the trusted set.
  /// @param issuerId Plain issuer identifier to trust.
  /// @param context Policy engine context bytes.
  function addTrustedIssuer(string memory issuerId, bytes calldata context) external;

  /// @notice Removes an issuer identifier from the trusted set.
  /// @param issuerId Plain issuer identifier to remove.
  /// @param context Policy engine context bytes.
  function removeTrustedIssuer(string memory issuerId, bytes calldata context) external;

  /// @notice Checks whether an issuer identifier is trusted.
  /// @param issuerId Plain issuer identifier to check.
  /// @return True when the issuer identifier is trusted.
  function isTrustedIssuer(string memory issuerId) external view returns (bool);

  /// @notice Returns the hashes of all trusted issuer identifiers.
  /// @return Issuer identifier hashes.
  function getTrustedIssuers() external view returns (bytes32[] memory);
}
