// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import "../admin/AdminControls.sol";
import "./IVLEIOracleRegistry.sol";

/// @notice Records the authorized oracle's current wallet association endorsement.
/// @dev KERI, credential status, signatures and account type are verified off-chain.
/// The deployment supplies chain scope. Consuming this result trusts the oracle.
/// Updates flow from verifier status through the oracle's durable delivery phases.
/// Transaction receipts report execution results; success alone does not prove
/// a particular application effect or token movement. Check the relevant state and events.
/// These records do not send authority back to off-chain services or trigger
/// automatic repair of independent writes.
contract VLEIOracleRegistry is IVLEIOracleRegistry {
    struct Endorsement {
        bytes32 identityRef;
        string associationSaid;
    }

    AdminControls public immutable adminControls;
    mapping(address wallet => Endorsement) private _endorsements;

    event EndorsementPublished(address indexed wallet, bytes32 indexed identityRef, string associationSaid);
    event EndorsementWithdrawn(address indexed wallet, bytes32 indexed identityRef, string associationSaid);

    modifier onlyOracleWriter() {
        require(adminControls.hasRole(adminControls.COMPLIANCE_ADMIN_ROLE(), msg.sender), "Not compliance admin");
        _;
    }

    constructor(address _adminControls) {
        require(_adminControls != address(0), "Invalid admin controls");
        adminControls = AdminControls(_adminControls);
    }

    /// @notice Publish or replace the current endorsement for one wallet.
    function publishEndorsement(address wallet, bytes32 identityRef, string calldata associationSaid)
        external onlyOracleWriter
    {
        require(wallet != address(0), "Wallet required");
        require(identityRef != bytes32(0), "Identity required");
        require(bytes(associationSaid).length != 0, "Association required");
        _endorsements[wallet] = Endorsement(identityRef, associationSaid);
        emit EndorsementPublished(wallet, identityRef, associationSaid);
    }

    /// @notice Withdraw this exact association; late withdrawal cannot clear its replacement.
    function withdrawEndorsement(address wallet, string calldata associationSaid)
        external onlyOracleWriter returns (bool)
    {
        Endorsement storage current = _endorsements[wallet];
        if (current.identityRef == bytes32(0) ||
            keccak256(bytes(current.associationSaid)) != keccak256(bytes(associationSaid))) return false;
        bytes32 identityRef = current.identityRef;
        delete _endorsements[wallet];
        emit EndorsementWithdrawn(wallet, identityRef, associationSaid);
        return true;
    }

    function getEndorsement(address wallet) external view returns (Endorsement memory) {
        return _endorsements[wallet];
    }

    function isEndorsed(address wallet, bytes32 identityRef) external view override returns (bool) {
        return identityRef != bytes32(0) && _endorsements[wallet].identityRef == identityRef;
    }
}
