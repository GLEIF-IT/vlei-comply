// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import "../interfaces/IPolicy.sol";
import "../interfaces/IVLEILegalEntityVerifier.sol";
import "../interfaces/IVLEIOracleRegistry.sol";

/**
 * @title VLEILegalEntityVerifier
 * @notice Verifies vLEI Legal Entity status against an on-chain oracle registry.
 * @dev This verifier expects `party.identityRef` to already be enriched to the AID-derived
 * Chainlink CCID. It performs no wallet lookup itself and fails closed when the identity ref is zero.
 * @dev The verifier validates only Legal Entity AID, LEI match, ACDC presence,
 * allowlist, expiry, and revocation. OOR and authority-specific checks are not performed.
 */
contract VLEILegalEntityVerifier is IVLEILegalEntityVerifier {
    /// @notice Oracle/admin-posted evidence registry used for Legal Entity checks.
    IVLEIOracleRegistry public immutable oracleRegistry;

    /// @notice Creates the verifier.
    /// @param _oracleRegistry Address of the `VLEIOracleRegistry` instance.
    constructor(address _oracleRegistry) {
        require(_oracleRegistry != address(0), "Invalid oracle registry");
        oracleRegistry = IVLEIOracleRegistry(_oracleRegistry);
    }

    /// @notice Validates whether a party has valid vLEI Legal Entity evidence.
    /// @dev Implements the generic verifier interface used by generated policies.
    /// @param party Enriched party whose `identityRef` should be an AID-derived CCID.
    /// @return True when the party's AID CCID has a valid oracle registry record.
    function validate(IPolicy.PartyPacket calldata party) external view override returns (bool) {
        return _validateLegalEntity(party);
    }

    /// @notice Validates Legal Entity status for a party.
    /// @param party Enriched party whose `identityRef` should be an AID-derived CCID.
    /// @return True when the party's AID CCID has a valid oracle registry record.
    function validateLegalEntity(IPolicy.PartyPacket calldata party) external view override returns (bool) {
        return _validateLegalEntity(party);
    }

    /// @notice Shared validation implementation for the generic and vLEI-specific entry points.
    /// @param party Enriched party whose identity reference is checked.
    /// @return True when the oracle registry accepts the party's identity reference.
    function _validateLegalEntity(IPolicy.PartyPacket calldata party) internal view returns (bool) {
        bytes32 identityRef = _identityRef(party);
        if (identityRef == bytes32(0)) {
            return false;
        }

        return oracleRegistry.isLegalEntityValid(identityRef);
    }
    /// @notice Select the party input before querying the registry.
    function _identityRef(IPolicy.PartyPacket calldata party) internal pure returns (bytes32) {
        return party.identityRef;
    }
}
