// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import "./IAttestationServiceVerifier.sol";
import "./IPolicy.sol";

/**
 * @title IVLEILegalEntityVerifier
 * @notice vLEI-specific verifier interface layered on the generic party verifier.
 * @dev The implementation checks Legal Entity status from an on-chain oracle registry.
 */
interface IVLEILegalEntityVerifier is IAttestationServiceVerifier {
    /// @notice Checks whether a party satisfies vLEI Legal Entity requirements.
    /// @param party Enriched transaction party whose `identityRef` should be an AID-derived CCID.
    /// @return True when the party's Legal Entity evidence is valid and allowlisted.
    function validateLegalEntity(IPolicy.PartyPacket calldata party) external view returns (bool);
}
