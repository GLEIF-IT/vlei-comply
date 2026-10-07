// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import "./IAttestationServiceVerifier.sol";
import "./IPolicy.sol";

/// @notice Checks the trusted oracle's current endorsement for a transaction party.
interface IVLEIEndorsementChecker is IAttestationServiceVerifier {
    function checkEndorsement(IPolicy.PartyPacket calldata party) external view returns (bool);
}
