// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import "../admin/AdminControls.sol";

/**
 * @title VLEIOracleRegistry
 * @notice Admin/oracle-posted registry of vLEI Legal Entity AID and LE ACDC status.
 * @dev The demo treats `keccak256(bytes(canonicalAidString))` as the Chainlink CCID.
 * This contract stores evidence already verified off-chain by an oracle/admin service. It does
 * not query Sally, GLEIF, KERI infrastructure, or any external revocation endpoint at runtime.
 * @custom:security A `COMPLIANCE_ADMIN_ROLE` holder can create, allow, revoke, and expire records.
 * Production deployments need governed oracle posting and operational separation of duties.
 * @custom:prototype Evidence semantics are intentionally narrow: LE AID, entity LEI, credential
 * subject LEI, ACDC SAID hash, proof hash, issuance, expiry, allowlist, and revocation.
 */
contract VLEIOracleRegistry {
    /// @notice Machine-readable result for a Legal Entity validation check.
    enum ValidationResult {
        /// @notice The record exists, is allowlisted, has matching LEI evidence, is unexpired, and is not revoked.
        Valid,
        /// @notice No record exists for the supplied AID CCID.
        MissingRecord,
        /// @notice The AID record exists but is not allowlisted for transfer compliance.
        NotAllowed,
        /// @notice The registered entity LEI string or hash is missing.
        MissingEntityLei,
        /// @notice The credential subject LEI hash is missing.
        MissingCredentialSubjectLei,
        /// @notice The entity LEI and credential subject LEI hashes differ.
        LeiMismatch,
        /// @notice The LE ACDC SAID hash is missing.
        MissingAcdc,
        /// @notice The record has a nonzero expiration at or before the current block timestamp.
        Expired,
        /// @notice The LE ACDC has been marked revoked by the oracle/admin.
        Revoked
    }

    /// @notice On-chain evidence record for one vLEI Legal Entity AID.
    /// @dev `entityLeiHash` and `credentialSubjectLeiHash` deliberately remain separate so the
    /// verifier can fail closed when the credential subject no longer matches the registered entity.
    struct LegalEntityRecord {
        /// @notice Canonical AID string supplied by the oracle/admin.
        string aid;
        /// @notice Plain LEI string for maintainer readability and off-chain indexing.
        string entityLei;
        /// @notice Keccak256 hash of `entityLei`.
        bytes32 entityLeiHash;
        /// @notice Keccak256 hash of the LEI asserted inside the LE credential subject.
        bytes32 credentialSubjectLeiHash;
        /// @notice Keccak256 hash or canonical digest of the LE ACDC SAID.
        bytes32 acdcSaidHash;
        /// @notice Optional hash of off-chain proof material retained by the oracle/admin.
        bytes32 proofHash;
        /// @notice Evidence issuance timestamp. A zero input to posting is replaced with `block.timestamp`.
        uint40 issuedAt;
        /// @notice Evidence expiration timestamp. A zero value means no on-chain expiration.
        uint40 expiresAt;
        /// @notice True after a record has been posted for the AID CCID.
        bool exists;
        /// @notice True when this AID is allowlisted for compliance checks.
        bool allowed;
        /// @notice True when the LE ACDC has been marked revoked.
        bool revoked;
    }

    /// @notice Shared role authority used to gate oracle/admin updates.
    AdminControls public immutable adminControls;

    mapping(bytes32 aidCcid => LegalEntityRecord record) private _records;

    /// @notice Emitted when a Legal Entity AID record is posted or replaced.
    /// @param aidCcid AID-derived CCID, computed as `keccak256(bytes(canonicalAidString))`.
    /// @param aid Canonical AID string supplied to the registry.
    event AidPosted(bytes32 indexed aidCcid, string aid);

    /// @notice Emitted when an AID allowlist status changes.
    /// @param aidCcid AID-derived CCID whose allowlist status changed.
    /// @param allowed True when the AID is allowed to satisfy vLEI compliance.
    event AidAllowlistUpdated(bytes32 indexed aidCcid, bool allowed);

    /// @notice Emitted when Legal Entity credential evidence is posted or expiry changes.
    /// @param aidCcid AID-derived CCID for the record.
    /// @param entityLeiHash Hash of the entity LEI registered for the AID.
    /// @param acdcSaidHash Hash/digest of the LE ACDC SAID.
    /// @param credentialSubjectLeiHash Hash of the LEI asserted by the credential subject.
    /// @param proofHash Optional hash of off-chain proof material.
    /// @param issuedAt Evidence issuance timestamp stored on chain.
    /// @param expiresAt Evidence expiration timestamp, or zero for no expiration.
    event LegalEntityCredentialUpdated(
        bytes32 indexed aidCcid,
        bytes32 indexed entityLeiHash,
        bytes32 indexed acdcSaidHash,
        bytes32 credentialSubjectLeiHash,
        bytes32 proofHash,
        uint40 issuedAt,
        uint40 expiresAt
    );

    /// @notice Emitted when the revocation status for a Legal Entity credential changes.
    /// @param aidCcid AID-derived CCID whose credential revocation status changed.
    /// @param revoked True when the LE ACDC is revoked.
    event LegalEntityRevocationUpdated(bytes32 indexed aidCcid, bool revoked);

    /// @notice Restricts registry updates to compliance administrators.
    /// @dev Reverts when `msg.sender` lacks `AdminControls.COMPLIANCE_ADMIN_ROLE`.
    modifier onlyComplianceAdmin() {
        require(adminControls.hasRole(adminControls.COMPLIANCE_ADMIN_ROLE(), msg.sender), "Not compliance admin");
        _;
    }

    /// @notice Creates the oracle registry using the shared admin controls contract.
    /// @param _adminControls Address of the shared `AdminControls` instance.
    constructor(address _adminControls) {
        require(_adminControls != address(0), "Invalid admin controls");
        adminControls = AdminControls(_adminControls);
    }

    /// @notice Computes the AID-derived CCID used as the registry key.
    /// @dev The AID string must be canonicalized off-chain before calling this helper.
    /// @param aid Canonical AID string.
    /// @return AID-derived CCID.
    function computeAidCcid(string memory aid) public pure returns (bytes32) {
        return keccak256(bytes(aid));
    }

    /**
     * @notice Posts or replaces Legal Entity evidence for one AID.
     * @dev Fails closed on empty AID/LEI/credential-subject LEI/ACDC SAID, and rejects
     * nonzero expirations that are already expired. Emits a full set of indexing events even
     * when replacing an existing record.
     * @param aid Canonical AID string used to compute the CCID.
     * @param entityLei LEI registered for the legal entity.
     * @param credentialSubjectLei LEI asserted by the LE credential subject.
     * @param acdcSaidHash Hash or canonical digest of the LE ACDC SAID.
     * @param proofHash Optional hash of off-chain oracle proof material.
     * @param issuedAt Issuance timestamp, or zero to store the current block timestamp.
     * @param expiresAt Expiration timestamp, or zero for no expiration.
     * @param allowed Initial AID allowlist status.
     * @param revoked Initial revocation status.
     * @return aidCcid Computed AID-derived CCID.
     */
    function postLegalEntityRecord(
        string calldata aid,
        string calldata entityLei,
        string calldata credentialSubjectLei,
        bytes32 acdcSaidHash,
        bytes32 proofHash,
        uint40 issuedAt,
        uint40 expiresAt,
        bool allowed,
        bool revoked
    ) external onlyComplianceAdmin returns (bytes32 aidCcid) {
        require(bytes(aid).length != 0, "AID required");
        require(bytes(entityLei).length != 0, "Entity LEI required");
        require(bytes(credentialSubjectLei).length != 0, "Credential subject LEI required");
        require(acdcSaidHash != bytes32(0), "ACDC SAID required");
        require(expiresAt == 0 || expiresAt > block.timestamp, "Invalid expiration");

        aidCcid = computeAidCcid(aid);
        uint40 effectiveIssuedAt = issuedAt == 0 ? uint40(block.timestamp) : issuedAt;

        _records[aidCcid] = LegalEntityRecord({
            aid: aid,
            entityLei: entityLei,
            entityLeiHash: keccak256(bytes(entityLei)),
            credentialSubjectLeiHash: keccak256(bytes(credentialSubjectLei)),
            acdcSaidHash: acdcSaidHash,
            proofHash: proofHash,
            issuedAt: effectiveIssuedAt,
            expiresAt: expiresAt,
            exists: true,
            allowed: allowed,
            revoked: revoked
        });

        emit AidPosted(aidCcid, aid);
        emit AidAllowlistUpdated(aidCcid, allowed);
        emit LegalEntityCredentialUpdated(
            aidCcid,
            keccak256(bytes(entityLei)),
            acdcSaidHash,
            keccak256(bytes(credentialSubjectLei)),
            proofHash,
            effectiveIssuedAt,
            expiresAt
        );
        emit LegalEntityRevocationUpdated(aidCcid, revoked);
    }

    /// @notice Updates whether an AID can satisfy the vLEI compliance gate.
    /// @param aidCcid AID-derived CCID to update.
    /// @param allowed True to allow the AID; false to fail validation with `NotAllowed`.
    function setAidAllowed(bytes32 aidCcid, bool allowed) external onlyComplianceAdmin {
        LegalEntityRecord storage record = _records[aidCcid];
        require(record.exists, "AID record missing");
        record.allowed = allowed;
        emit AidAllowlistUpdated(aidCcid, allowed);
    }

    /// @notice Updates revocation status for a Legal Entity ACDC.
    /// @param aidCcid AID-derived CCID to update.
    /// @param revoked True to mark revoked; false to mark not revoked.
    function setCredentialRevoked(bytes32 aidCcid, bool revoked) external onlyComplianceAdmin {
        LegalEntityRecord storage record = _records[aidCcid];
        require(record.exists, "AID record missing");
        record.revoked = revoked;
        emit LegalEntityRevocationUpdated(aidCcid, revoked);
    }

    /// @notice Updates the expiration timestamp for a posted Legal Entity record.
    /// @dev Rejects nonzero expirations that are not in the future.
    /// @param aidCcid AID-derived CCID to update.
    /// @param expiresAt New expiration timestamp, or zero for no expiration.
    function setCredentialExpiration(bytes32 aidCcid, uint40 expiresAt) external onlyComplianceAdmin {
        LegalEntityRecord storage record = _records[aidCcid];
        require(record.exists, "AID record missing");
        require(expiresAt == 0 || expiresAt > block.timestamp, "Invalid expiration");
        record.expiresAt = expiresAt;
        emit LegalEntityCredentialUpdated(
            aidCcid,
            record.entityLeiHash,
            record.acdcSaidHash,
            record.credentialSubjectLeiHash,
            record.proofHash,
            record.issuedAt,
            expiresAt
        );
    }

    /// @notice Returns the full Legal Entity record for an AID CCID.
    /// @param aidCcid AID-derived CCID to inspect.
    /// @return Legal Entity record. `exists` is false when no record has been posted.
    function getLegalEntityRecord(bytes32 aidCcid) external view returns (LegalEntityRecord memory) {
        return _records[aidCcid];
    }

    /// @notice Returns the first fail-closed validation result for a Legal Entity CCID.
    /// @dev Check order is stable and should be treated as part of CLI/operator diagnostics.
    /// @param aidCcid Legal Entity AID-derived CCID to validate.
    /// @return Validation result describing success or the first failure.
    function validateLeCcid(bytes32 aidCcid) public view returns (ValidationResult) {
        LegalEntityRecord storage record = _records[aidCcid];

        if (!record.exists) return ValidationResult.MissingRecord;
        if (!record.allowed) return ValidationResult.NotAllowed;
        if (record.entityLeiHash == bytes32(0) || bytes(record.entityLei).length == 0) {
            return ValidationResult.MissingEntityLei;
        }
        if (record.credentialSubjectLeiHash == bytes32(0)) return ValidationResult.MissingCredentialSubjectLei;
        if (record.entityLeiHash != record.credentialSubjectLeiHash) return ValidationResult.LeiMismatch;
        if (record.acdcSaidHash == bytes32(0)) return ValidationResult.MissingAcdc;
        if (record.expiresAt != 0 && record.expiresAt <= block.timestamp) return ValidationResult.Expired;
        if (record.revoked) return ValidationResult.Revoked;

        return ValidationResult.Valid;
    }

    /// @notice Returns whether an AID CCID satisfies vLEI Legal Entity requirements.
    /// @param aidCcid AID-derived CCID to validate.
    /// @return True only when `validateLeCcid(aidCcid) == ValidationResult.Valid`.
    function isLegalEntityValid(bytes32 aidCcid) external view returns (bool) {
        return validateLeCcid(aidCcid) == ValidationResult.Valid;
    }
}
