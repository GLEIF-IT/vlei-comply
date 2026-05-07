// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IGL1IdentityRegistry
 * @notice Interface for identity verification
 */
interface IGL1IdentityRegistry {
    function identityRef(address account) external view returns (bytes32);
    function kycHash(address account) external view returns (bytes32);
    function accountRef(address account) external view returns (bytes32);
    function jurisdiction(address account) external view returns (bytes32);
    function kycLevel(address account) external view returns (uint256);
    function hasVASPLicense(address account) external view returns (bool);

    // Beneficiary ID-based getters (VASP support)
    function identityRefById(bytes32 beneficiaryId) external view returns (bytes32);
    function kycHashById(bytes32 beneficiaryId) external view returns (bytes32);
    function accountRefById(bytes32 beneficiaryId) external view returns (bytes32);
    function jurisdictionById(bytes32 beneficiaryId) external view returns (bytes32);
    function kycLevelById(bytes32 beneficiaryId) external view returns (uint256);
    function hasVASPLicenseById(bytes32 beneficiaryId) external view returns (bool);

    // Standard Identity Enrichment Getters
    function getBeneficiaryId(address wallet) external view returns (bytes32);
}
