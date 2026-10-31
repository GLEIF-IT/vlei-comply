// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import "../policy/IPolicy.sol";
import "../policy/IAttestationServiceVerifier.sol";
import "./IVLEIOracleRegistry.sol";

/// @notice Consumes exact-wallet endorsements; it does not verify vLEI evidence.
contract VLEIEndorsementChecker is IAttestationServiceVerifier {
    IVLEIOracleRegistry public immutable oracleRegistry;

    constructor(address registry) {
        require(registry != address(0), "Invalid oracle registry");
        oracleRegistry = IVLEIOracleRegistry(registry);
    }

    function validate(IPolicy.PartyPacket calldata party) external view override returns (bool) {
        return _isEndorsed(party);
    }

    function _isEndorsed(IPolicy.PartyPacket calldata party) internal view returns (bool) {
        if (party.wallet == address(0) || party.identityRef == bytes32(0)) return false;
        return oracleRegistry.isEndorsed(party.wallet, party.identityRef);
    }
}
