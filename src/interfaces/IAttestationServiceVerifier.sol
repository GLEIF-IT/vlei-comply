// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import "./IPolicy.sol";

/**
 * @title IAttestationServiceVerifier
 * @notice Interface for external attestation service verification
 */
interface IAttestationServiceVerifier {
    /**
     * @notice Validate if the address satisfies the attestation requirement
     * @param party The full enriched party data to validate
     * @return true if valid, false otherwise
     */
    function validate(IPolicy.PartyPacket calldata party) external view returns (bool);
}
