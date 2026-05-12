// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IPolicy
 * @notice Common transaction envelope and evaluation interface for compliance policies.
 * @dev Wrappers construct a `TransactionEnvelope`, `PolicyManager` enriches it, and
 * each policy returns one `PolicyStatus` plus policy-specific proof bytes.
 */
interface IPolicy {
    /// @notice High-level policy evaluation result.
    enum PolicyStatus {
        /// @notice Uninitialized or unexpected policy state.
        Unknown,
        /// @notice Policy requirements passed.
        Pass,
        /// @notice Policy requirements failed and the transfer must not execute.
        Fail,
        /// @notice Policy requires an external or manual resolution step.
        Pending
    }
    
    /// @notice Logical role of a party in a transaction envelope.
    enum PartyRole {
        /// @notice Role was not supplied.
        Unknown,
        /// @notice Sending end-user or legal entity customer.
        OriginatorCustomer,
        /// @notice Receiving end-user or legal entity customer.
        BeneficiaryCustomer,
        /// @notice Sending VASP or financial intermediary.
        OriginatingVASP,
        /// @notice Receiving VASP or financial intermediary.
        BeneficiaryVASP,
        /// @notice Intermediary VASP in a multi-hop transfer.
        IntermediaryVASP
    }
    
    /// @notice Party packet carrying wallet, identity, KYC, account, and role metadata.
    /// @dev `identityRef` is opaque to generic policies. In the vLEI path it is interpreted
    /// as a Chainlink CCID derived from `keccak256(bytes(canonicalAidString))`.
    struct PartyPacket {
        /// @notice Logical role in the transaction.
        PartyRole role;
        /// @notice On-chain wallet address, or zero when the party is identified only by `identityRef`.
        address wallet;
        /// @notice Opaque identity reference resolved by the identity registry.
        bytes32 identityRef;
        /// @notice Hash or registry reference for KYC evidence.
        bytes32 kycHash;
        /// @notice Account or customer reference assigned by an upstream system.
        bytes32 accountRef;
        /// @notice Jurisdiction identifier encoded by the identity registry.
        bytes32 jurisdiction;
        /// @notice Numeric KYC assurance level supplied by registry enrichment.
        uint256 kycLevel;
        /// @notice True when registry enrichment indicates the party has a VASP license.
        bool hasVASPLicense;
    }
    
    /// @notice Transaction envelope passed through the compliance pipeline.
    /// @dev Policy implementations should treat `extraData` as operation-specific context and
    /// preserve backwards compatibility when decoding it.
    struct TransactionEnvelope {
        /// @notice Underlying asset token address.
        address token;
        /// @notice Transfer amount in token base units.
        uint256 amount;
        /// @notice Timestamp supplied by the wrapper, normally `block.timestamp`.
        uint256 timestamp;
        /// @notice Optional payload for IVMS101, credential SAIDs, operation intent, or future constraints.
        bytes extraData;
        /// @notice Dynamic list of transaction parties.
        PartyPacket[] parties;
    }
    
    /// @notice Per-policy evaluation record.
    struct PolicyResult {
        /// @notice Stable policy identifier.
        bytes32 policyId;
        /// @notice Policy version reported by the policy contract.
        uint64 policyVersion;
        /// @notice Status returned by this policy.
        PolicyStatus status;
        /// @notice Timestamp at which the manager recorded the evaluation.
        uint256 evaluatedAt;
        /// @notice Policy-specific evidence, reason code, or proof bytes.
        bytes attestationProof;
    }
    
    /// @notice Aggregated compliance attestation for an enriched envelope.
    struct ComplianceAttestation {
        /// @notice Hash of the enriched transaction envelope evaluated by policies.
        bytes32 envelopeHash;
        /// @notice Aggregate status using manager precedence, currently Fail > Pending > Pass.
        PolicyStatus overallStatus;
        /// @notice Per-policy results in manager evaluation order.
        PolicyResult[] policyResults;
    }
    
    /// @notice Returns the stable policy identifier.
    /// @return Stable policy id used by wrappers, logs, and off-chain indexing.
    function policyId() external view returns (bytes32);

    /// @notice Returns the policy version.
    /// @return Version number assigned by deployment or implementation.
    function policyVersion() external view returns (uint64);
    
    /**
     * @notice Evaluates this policy against a transaction envelope.
     * @dev Implementations should fail closed on missing required identity or evidence.
     * @param envelope Transaction envelope, normally enriched by `PolicyManager` before evaluation.
     * @return status Pass, Fail, or Pending status for this policy.
     * @return proof Policy-specific proof or reason bytes.
     */
    function evaluate(TransactionEnvelope calldata envelope) 
        external view returns (PolicyStatus status, bytes memory proof);
}
