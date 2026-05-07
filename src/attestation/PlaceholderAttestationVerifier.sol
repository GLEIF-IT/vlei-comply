// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import "../interfaces/IPolicy.sol";
import "../interfaces/IAttestationServiceVerifier.sol";

/**
 * @title PlaceholderAttestationVerifier
 * @notice Placeholder for WIP attestation services
 * @dev TODO: Replace with actual service integrations before production
 */
contract PlaceholderAttestationVerifier is IAttestationServiceVerifier {
    /**
     * @notice Placeholder validation that always returns true
     * @dev Used for testing when actual attestation service is not deployed.
     *      
     *      The PartyPacket contains:
     *      - role: The role of the party in the transaction (OriginatorCustomer, BeneficiaryCustomer, etc.)
     *      - wallet: The on-chain address of the party (if known)
     *      - Dynamically enriched fields: identityRef, kycHash, jurisdiction, accountRef, etc.
     *        (These are populated by the PolicyManager via IGL1IdentityRegistry before calling validate)
     *
     * @param party The full enriched party data to validate
     * @return true Always returns true
     */
    function validate(IPolicy.PartyPacket calldata party) external pure override returns (bool) {
        if (party.wallet == address(0)) {}
        return true;
    }
}
