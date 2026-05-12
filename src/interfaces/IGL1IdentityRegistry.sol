// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IGL1IdentityRegistry
 * @notice GL1 identity enrichment interface consumed by `PolicyManager`.
 * @dev This adapter-facing interface hides the concrete identity backend. The current implementation
 * adapts Chainlink CCID identities and treats CCID as the AID-derived identity reference.
 */
interface IGL1IdentityRegistry {
    /// @notice Resolves the primary identity reference for a wallet.
    /// @param account Wallet address to resolve.
    /// @return Identity reference, or zero when no identity is registered.
    function identityRef(address account) external view returns (bytes32);

    /// @notice Resolves the KYC evidence hash for a wallet.
    /// @param account Wallet address to resolve.
    /// @return KYC evidence hash, or zero when unavailable.
    function kycHash(address account) external view returns (bytes32);

    /// @notice Resolves the account/customer reference for a wallet.
    /// @param account Wallet address to resolve.
    /// @return Account reference, or zero when unavailable.
    function accountRef(address account) external view returns (bytes32);

    /// @notice Resolves the jurisdiction for a wallet.
    /// @param account Wallet address to resolve.
    /// @return Encoded jurisdiction, or zero when unavailable.
    function jurisdiction(address account) external view returns (bytes32);

    /// @notice Resolves the KYC assurance level for a wallet.
    /// @param account Wallet address to resolve.
    /// @return Numeric KYC level, or zero when unavailable.
    function kycLevel(address account) external view returns (uint256);

    /// @notice Resolves whether a wallet has a VASP license credential.
    /// @param account Wallet address to resolve.
    /// @return True when the registry indicates a valid VASP license.
    function hasVASPLicense(address account) external view returns (bool);

    /// @notice Resolves an identity reference from an existing abstract identity id.
    /// @param beneficiaryId Abstract beneficiary id, CCID, or AID-derived reference.
    /// @return Identity reference, or zero when unavailable.
    function identityRefById(bytes32 beneficiaryId) external view returns (bytes32);

    /// @notice Resolves KYC evidence from an existing abstract identity id.
    /// @param beneficiaryId Abstract beneficiary id, CCID, or AID-derived reference.
    /// @return KYC evidence hash, or zero when unavailable.
    function kycHashById(bytes32 beneficiaryId) external view returns (bytes32);

    /// @notice Resolves account/customer reference from an existing abstract identity id.
    /// @param beneficiaryId Abstract beneficiary id, CCID, or AID-derived reference.
    /// @return Account reference, or zero when unavailable.
    function accountRefById(bytes32 beneficiaryId) external view returns (bytes32);

    /// @notice Resolves jurisdiction from an existing abstract identity id.
    /// @param beneficiaryId Abstract beneficiary id, CCID, or AID-derived reference.
    /// @return Encoded jurisdiction, or zero when unavailable.
    function jurisdictionById(bytes32 beneficiaryId) external view returns (bytes32);

    /// @notice Resolves KYC level from an existing abstract identity id.
    /// @param beneficiaryId Abstract beneficiary id, CCID, or AID-derived reference.
    /// @return Numeric KYC level, or zero when unavailable.
    function kycLevelById(bytes32 beneficiaryId) external view returns (uint256);

    /// @notice Resolves VASP license status from an existing abstract identity id.
    /// @param beneficiaryId Abstract beneficiary id, CCID, or AID-derived reference.
    /// @return True when the registry indicates a valid VASP license.
    function hasVASPLicenseById(bytes32 beneficiaryId) external view returns (bool);

    /// @notice Resolves the abstract beneficiary id for a wallet.
    /// @param wallet Wallet address to resolve through the identity registry.
    /// @return Beneficiary id/CCID, or zero when the wallet is not registered.
    function getBeneficiaryId(address wallet) external view returns (bytes32);
}
