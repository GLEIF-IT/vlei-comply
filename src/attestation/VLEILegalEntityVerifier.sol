// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import "../interfaces/IPolicy.sol";
import "../interfaces/IVLEILegalEntityVerifier.sol";
import "../interfaces/IVLEIOracleRegistry.sol";

/// @notice Fail-closed consumer of the oracle registry read boundary.
/// @dev This consumer supplies no association-bound party input.
contract VLEILegalEntityVerifier is IVLEILegalEntityVerifier {
    /// @notice Oracle/admin-posted evidence registry used for Legal Entity checks.
    IVLEIOracleRegistry public immutable oracleRegistry;

    /// @notice Creates the verifier.
    /// @param _oracleRegistry Address of the `VLEIOracleRegistry` instance.
    constructor(address _oracleRegistry) {
        require(_oracleRegistry != address(0), "Invalid oracle registry");
        oracleRegistry = IVLEIOracleRegistry(_oracleRegistry);
    }

    /// @notice Reject unbound party input.
    /// @dev Implements the generic verifier interface used by generated policies.
    /// @param party Enriched party whose `identityRef` should be an AID-derived CCID.
    /// @return False for unbound input.
    function validate(IPolicy.PartyPacket calldata party) external view override returns (bool) {
        return _validateLegalEntity(party);
    }

    /// @notice Reject unbound Legal Entity input.
    /// @param party Enriched party whose `identityRef` should be an AID-derived CCID.
    /// @return False for unbound input.
    function validateLegalEntity(IPolicy.PartyPacket calldata party) external view override returns (bool) {
        return _validateLegalEntity(party);
    }

    /// @notice Fail closed without an association-bound party input.
    function _validateLegalEntity(IPolicy.PartyPacket calldata) internal pure returns (bool) {
        return false;
    }
}
