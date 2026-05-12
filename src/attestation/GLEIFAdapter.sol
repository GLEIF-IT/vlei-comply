// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import "../interfaces/IPolicy.sol";
import "../interfaces/IAttestationServiceVerifier.sol";
import "../identity/interfaces/IIdentityRegistry.sol";
import "../identity/interfaces/ICredentialRegistry.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title GLEIFAdapter
 * @notice Legacy/generated adapter for a future GLEIF attestation service.
 * @dev This contract is retained for compatibility with the generated GL1 surface. It is not the
 * active vLEI verifier path. Current transfer policy uses `vLEIAttestationVerifier` backed by
 * `vLEIOracleRegistry`; this adapter still fails closed from `validate`.
 * @custom:prototype Do not wire this contract as the production verifier without replacing the
 * placeholder validation and defining oracle authorization, proof format, and revocation behavior.
 */
contract GLEIFAdapter is IAttestationServiceVerifier, Ownable {
    /// @notice Chainlink-style identity registry used by the legacy provisioning helpers.
    IIdentityRegistry public immutable identityRegistry;

    /// @notice Chainlink-style credential registry used by the legacy provisioning helpers.
    ICredentialRegistry public immutable credentialRegistry;

    // Legacy placeholder: active oracle evidence is stored in vLEIOracleRegistry.

    /// @notice Emitted when the owner provisions a wallet to identity mapping through this adapter.
    /// @param wallet Wallet address associated with the identity.
    /// @param identityId Identity id registered for the wallet.
    event IdentityProvisioned(address indexed wallet, bytes32 indexed identityId);

    /// @notice Emitted when the owner provisions a credential through this adapter.
    /// @param identityId Identity id receiving the credential.
    /// @param credentialType Credential type identifier registered.
    event CredentialProvisioned(bytes32 indexed identityId, bytes32 indexed credentialType);

    /// @notice Creates the legacy adapter.
    /// @param _identityRegistry Chainlink-style identity registry address.
    /// @param _credentialRegistry Chainlink-style credential registry address.
    constructor(address _identityRegistry, address _credentialRegistry) Ownable(msg.sender) {
        require(_identityRegistry != address(0), "Invalid identity registry");
        require(_credentialRegistry != address(0), "Invalid credential registry");
        identityRegistry = IIdentityRegistry(_identityRegistry);
        credentialRegistry = ICredentialRegistry(_credentialRegistry);
    }

    /**
     * @notice Provisions a new identity in the Identity Registry.
     * @dev Placeholder owner-only helper. Production use would need an authenticated oracle/relayer
     * and should not rely on this method as written.
     * @param wallet The address to associate with the identity.
     * @param identityId The unique identifier for this identity (e.g., LEI hash).
     */
    function addIdentity(address wallet, bytes32 identityId) external onlyOwner {
        // Legacy provisioning path; no external GLEIF proof is verified here.
        
        address[] memory accounts = new address[](1);
        accounts[0] = wallet;
        identityRegistry.registerIdentity(identityId, wallet, "");
        emit IdentityProvisioned(wallet, identityId);
    }

    /**
     * @notice Adds a verifiable credential to an identity.
     * @dev Placeholder owner-only helper that writes opaque credential data with a one-year expiry.
     * Production use requires externally verified GLEIF/vLEI proof material and revocation semantics.
     * @param identityId The unique identifier for the identity.
     * @param credentialType The type of credential to add (e.g., LEI status, entity type).
     * @param data The credential payload/data.
     */
    function addVerificationToIdentity(bytes32 identityId, bytes32 credentialType, bytes calldata data) external onlyOwner {
        // Legacy provisioning path; credential payloads are trusted owner input.
        uint40 expiresAt = uint40(block.timestamp + 365 days);
        credentialRegistry.registerCredential(identityId, credentialType, expiresAt, data, "");
        emit CredentialProvisioned(identityId, credentialType);
    }

    /**
     * @notice Fails closed for generated compatibility.
     * @dev This placeholder intentionally returns false until a real GLEIF/vLEI proof verifier is
     * implemented. Use `vLEIAttestationVerifier` for the current oracle-registry path.
     * @param party The full enriched party packet from the transaction envelope.
     * @return Always false in this compatibility implementation.
     */
    function validate(IPolicy.PartyPacket calldata party) external view override returns (bool) {
        // Compatibility implementation intentionally fails closed.
        if (party.wallet == address(0)) {}
        return false;
    }
}
