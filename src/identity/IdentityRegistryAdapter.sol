// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IGL1IdentityRegistry.sol";
import "./interfaces/IIdentityRegistry.sol";
import "./interfaces/ICredentialRegistry.sol";
import "./interfaces/ICredentialValidator.sol";

/**
 * @title IdentityRegistryAdapter (CHAINLINK_CCI)
 * @notice Adapts GL1's generic policy interface to CHAINLINK_CCI operations
 */
contract IdentityRegistryAdapter is IGL1IdentityRegistry {
    IIdentityRegistry public immutable identityRegistry;
    ICredentialValidator public immutable credentialValidator;
    
    constructor(address _identityRegistry, address _credentialValidator) {
        require(_identityRegistry != address(0), "Invalid identity registry");
        require(_credentialValidator != address(0), "Invalid credential validator");
        identityRegistry = IIdentityRegistry(_identityRegistry);
        credentialValidator = ICredentialValidator(_credentialValidator);
    }

    function kycLevel(address) external view override returns (uint256) {
        return 0;
    }

    function kycLevelById(bytes32) external view override returns (uint256) {
        return 0;
    }

    function hasVASPLicense(address account) external view override returns (bool) {
        bytes32 idRef = identityRegistry.getIdentity(account);
        if (idRef == bytes32(0)) return false;
        return credentialValidator.validate(idRef, keccak256("VASP"), "");
    }

    function hasVASPLicenseById(bytes32 beneficiaryId) external view override returns (bool) {
        if (beneficiaryId == bytes32(0)) return false;
        return credentialValidator.validate(beneficiaryId, keccak256("VASP"), "");
    }

    // --- Standard Identity Enrichment Getters ---
    
    function getBeneficiaryId(address wallet) external view override returns (bytes32) {
        return identityRegistry.getIdentity(wallet);
    }
    
    function identityRef(address account) external view override returns (bytes32) {
        return identityRegistry.getIdentity(account);
    }

    function identityRefById(bytes32 beneficiaryId) external view override returns (bytes32) {
        return beneficiaryId;
    }
    
    function kycHash(address account) external view override returns (bytes32) {
        bytes32 ccid = identityRegistry.getIdentity(account);
        if (ccid == bytes32(0)) return bytes32(0);
        return _getCredentialData(ccid, keccak256("KYC_HASH"));
    }

    function kycHashById(bytes32 beneficiaryId) external view override returns (bytes32) {
        return _getCredentialData(beneficiaryId, keccak256("KYC_HASH"));
    }
    
    function accountRef(address account) external view override returns (bytes32) {
        return bytes32(uint256(uint160(account)));
    }

    function accountRefById(bytes32) external view override returns (bytes32) {
        return bytes32(0);
    }
    
    function jurisdiction(address account) external view override returns (bytes32) {
        bytes32 ccid = identityRegistry.getIdentity(account);
        if (ccid == bytes32(0)) return bytes32(0);
        return _getCredentialData(ccid, keccak256("JURISDICTION"));
    }

    function jurisdictionById(bytes32 beneficiaryId) external view override returns (bytes32) {
        return _getCredentialData(beneficiaryId, keccak256("JURISDICTION"));
    }

    /**
     * @dev Internal helper to fetch bytes32 data from the credential registry
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
