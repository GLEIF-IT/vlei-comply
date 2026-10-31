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
        Fail
    }
    
    /// @notice Logical role of a party in a transaction envelope.
    enum PartyRole {
        /// @notice Role was not supplied.
        Unknown,
        /// @notice Sending end-user or legal entity customer.
        OriginatorCustomer,
        /// @notice Receiving end-user or legal entity customer.
        BeneficiaryCustomer
    }
    
    /// @notice Wallet party and its registry-resolved entity identity.
    /// @dev `identityRef` is opaque to generic policies. In the vLEI path it is interpreted
    /// as a Chainlink CCID derived from `keccak256(bytes(canonicalAidString))`.
    struct PartyPacket {
        /// @notice Logical role in the transaction.
        PartyRole role;
        /// @notice On-chain wallet address; zero cannot satisfy the association policy.
        address wallet;
        /// @notice Opaque identity reference resolved by the identity registry.
        bytes32 identityRef;
    }
    
    /// @notice Transaction envelope passed through the compliance pipeline.
    struct TransactionEnvelope {
        /// @notice Underlying asset token address.
        address token;
        /// @notice Transfer amount in token base units.
        uint256 amount;
        /// @notice Timestamp supplied by the wrapper, normally `block.timestamp`.
        uint256 timestamp;
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
        /// @notice Pass only when every configured policy returns Pass; otherwise Fail.
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
     * @return status Pass or a non-passing status for this policy.
     * @return proof Policy-specific proof or reason bytes.
     */
    function evaluate(TransactionEnvelope calldata envelope) 
        external view returns (PolicyStatus status, bytes memory proof);
}
