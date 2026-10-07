// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IGL1IdentityRegistry.sol";
import "./interfaces/IIdentityRegistry.sol";
import "./interfaces/ICredentialRegistry.sol";
import "./interfaces/ICredentialValidator.sol";

/**
 * @title ChainlinkCCIDIdentityAdapter (CHAINLINK_CCI)
 * @notice Adapts GL1 policy enrichment calls to Chainlink CCID registries.
 * @dev The vLEI path treats a Chainlink CCID as the AID-derived identity reference:
 * `ccid = keccak256(bytes(canonicalAidString))`. Credential-based KYC/jurisdiction helpers are
 * compatibility enrichment fields and are not authoritative for Legal Entity pass/fail decisions.
 */
contract ChainlinkCCIDIdentityAdapter is IGL1IdentityRegistry {
    /// @notice Chainlink-style wallet-to-CCID identity registry.
    IIdentityRegistry public immutable identityRegistry;

    /// @notice Chainlink-style credential validator/registry used for optional enrichment fields.
    ICredentialValidator public immutable credentialValidator;
    
    /// @notice Creates the GL1 identity adapter.
    /// @param _identityRegistry Chainlink-style identity registry address.
    /// @param _credentialValidator Credential validator address; usually the credential registry.
    constructor(address _identityRegistry, address _credentialValidator) {
        require(_identityRegistry != address(0), "Invalid identity registry");
        require(_credentialValidator != address(0), "Invalid credential validator");
        identityRegistry = IIdentityRegistry(_identityRegistry);
        credentialValidator = ICredentialValidator(_credentialValidator);
    }

    /// @notice Returns numeric KYC level for a wallet.
    /// @dev The Chainlink CCID compatibility adapter does not currently model KYC levels.
    /// @return Always zero.
    function kycLevel(address) external view override returns (uint256) {
        return 0;
    }

    /// @notice Returns numeric KYC level for an abstract identity id.
    /// @dev The Chainlink CCID compatibility adapter does not currently model KYC levels.
    /// @return Always zero.
    function kycLevelById(bytes32) external view override returns (uint256) {
        return 0;
    }

    /// @notice Returns whether a wallet has a valid VASP credential.
    /// @param account Wallet address to resolve and validate.
    /// @return True when the wallet resolves to a CCID with a valid `VASP` credential.
    function hasVASPLicense(address account) external view override returns (bool) {
        bytes32 idRef = identityRegistry.getIdentity(account);
        if (idRef == bytes32(0)) return false;
        return credentialValidator.validate(idRef, keccak256("VASP"), "");
    }

    /// @notice Returns whether an abstract identity id has a valid VASP credential.
    /// @param beneficiaryId Abstract identity id/CCID.
    /// @return True when the id has a valid `VASP` credential.
    function hasVASPLicenseById(bytes32 beneficiaryId) external view override returns (bool) {
        if (beneficiaryId == bytes32(0)) return false;
        return credentialValidator.validate(beneficiaryId, keccak256("VASP"), "");
    }

    /// @notice Resolves a wallet to its Chainlink CCID.
    /// @param wallet Wallet address to resolve.
    /// @return CCID registered for the wallet, or zero when none exists.
    function getBeneficiaryId(address wallet) external view override returns (bytes32) {
        return identityRegistry.getIdentity(wallet);
    }

    /// @notice Resolves a wallet to its identity reference.
    /// @param account Wallet address to resolve.
    /// @return CCID registered for the wallet, or zero when none exists.
    function identityRef(address account) external view override returns (bytes32) {
        return identityRegistry.getIdentity(account);
    }

    /// @notice Returns an already supplied abstract identity id as the identity reference.
    /// @param beneficiaryId Abstract identity id/CCID.
    /// @return The supplied id.
    function identityRefById(bytes32 beneficiaryId) external view override returns (bytes32) {
        return beneficiaryId;
    }

    /// @notice Returns optional KYC hash credential data for a wallet.
    /// @param account Wallet address to resolve.
    /// @return Decoded bytes32 credential data for `KYC_HASH`, or zero when unavailable.
    function kycHash(address account) external view override returns (bytes32) {
        bytes32 ccid = identityRegistry.getIdentity(account);
        if (ccid == bytes32(0)) return bytes32(0);
        return _getCredentialData(ccid, keccak256("KYC_HASH"));
    }

    /// @notice Returns optional KYC hash credential data for an abstract identity id.
    /// @param beneficiaryId Abstract identity id/CCID.
    /// @return Decoded bytes32 credential data for `KYC_HASH`, or zero when unavailable.
    function kycHashById(bytes32 beneficiaryId) external view override returns (bytes32) {
        return _getCredentialData(beneficiaryId, keccak256("KYC_HASH"));
    }

    /// @notice Returns an account reference for a wallet.
    /// @dev Current compatibility behavior derives the reference from the wallet address.
    /// @param account Wallet address.
    /// @return Wallet address left-padded into bytes32.
    function accountRef(address account) external view override returns (bytes32) {
        return bytes32(uint256(uint160(account)));
    }

    /// @notice Returns an account reference for an abstract identity id.
    /// @dev Account references are not currently modeled for AID-only parties.
    /// @return Always zero.
    function accountRefById(bytes32) external view override returns (bytes32) {
        return bytes32(0);
    }

    /// @notice Returns optional jurisdiction credential data for a wallet.
    /// @param account Wallet address to resolve.
    /// @return Decoded bytes32 credential data for `JURISDICTION`, or zero when unavailable.
    function jurisdiction(address account) external view override returns (bytes32) {
        bytes32 ccid = identityRegistry.getIdentity(account);
        if (ccid == bytes32(0)) return bytes32(0);
        return _getCredentialData(ccid, keccak256("JURISDICTION"));
    }

    /// @notice Returns optional jurisdiction credential data for an abstract identity id.
    /// @param beneficiaryId Abstract identity id/CCID.
    /// @return Decoded bytes32 credential data for `JURISDICTION`, or zero when unavailable.
    function jurisdictionById(bytes32 beneficiaryId) external view override returns (bytes32) {
        return _getCredentialData(beneficiaryId, keccak256("JURISDICTION"));
    }

    /**
     * @notice Fetches and decodes bytes32 credential data from the credential registry.
     * @dev Returns zero when the CCID is empty, the credential is invalid/expired, or the
     * credential payload is shorter than 32 bytes.
     * @param ccid Chainlink CCID to inspect.
     * @param typeId Credential type identifier.
     * @return Decoded bytes32 credential data, or zero.
     */
    function _getCredentialData(bytes32 ccid, bytes32 typeId) internal view returns (bytes32) {
        if (ccid == bytes32(0)) return bytes32(0);
        
        // 1. Check if credential is expired
        if (credentialValidator.validate(ccid, typeId, "")) {
            // 2. Fetch the credential data
            ICredentialRegistry registry = ICredentialRegistry(address(credentialValidator));
            ICredentialRegistry.Credential memory cred = registry.getCredential(ccid, typeId);
            
            if (cred.credentialData.length >= 32) {
                return abi.decode(cred.credentialData, (bytes32));
            }
        }
        
        return bytes32(0);
    }
}
