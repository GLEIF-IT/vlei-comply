// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

/**
 * @title ITrustedIssuerRegistry
 * @dev Interface for managing trusted issuers in the system.
 */
interface ITrustedIssuerRegistry {
  event TrustedIssuerAdded(bytes32 indexed issuerIdHash, string issuerId);
  event TrustedIssuerRemoved(bytes32 indexed issuerIdHash, string issuerId);

  function typeAndVersion() external pure returns (string memory);
  function addTrustedIssuer(string memory issuerId, bytes calldata context) external;
  function removeTrustedIssuer(string memory issuerId, bytes calldata context) external;
  function isTrustedIssuer(string memory issuerId) external view returns (bool);
  function getTrustedIssuers() external view returns (bytes32[] memory);
}
