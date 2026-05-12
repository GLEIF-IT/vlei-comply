// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import "./IPolicy.sol";

/**
 * @title IAttestationServiceVerifier
 * @notice Interface for external attestation service verification
 * @dev Policies use this interface to validate enriched transaction parties without coupling to
 * a specific verifier implementation. Implementations should fail closed for ordinary invalid data.
 */
interface IAttestationServiceVerifier {
    /**
     * @notice Validates whether a transaction party satisfies an attestation requirement.
     * @dev Implementations must fail closed and should avoid reverting for ordinary validation failures.
     * @param party Full enriched party data to validate.
     * @return True when the party satisfies the implementing verifier's requirement.
     */
    function validate(IPolicy.PartyPacket calldata party) external view returns (bool);
}
