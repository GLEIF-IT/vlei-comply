// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IPolicy
 * @notice Common types and interface for all compliance policies
 * @dev Based on Transaction Envelope architecture for attestation-based compliance
 */
interface IPolicy {
    /// @notice High-level policy evaluation result
    enum PolicyStatus {
        Unknown,    // Uninitialized or error state
        Pass,       // Policy check passed
        Fail,       // Policy check failed
        Pending     // Awaiting external verification/manual resolution
    }
    
    /// @notice Logical role of a party in the transaction
    enum PartyRole {
        Unknown,
        OriginatorCustomer,     // Sending end-user/customer
        BeneficiaryCustomer,    // Receiving end-user/customer
        OriginatingVASP,        // Sending VASP/financial institution
        BeneficiaryVASP,        // Receiving VASP/financial institution
        IntermediaryVASP        // Intermediary in multi-hop transfers
    }
    
    /// @notice Party packet: role + wallet + opaque identity references
    struct PartyPacket {
        PartyRole role;         // Logical role in the transaction
        address wallet;         // On-chain wallet address
        bytes32 identityRef; // Opaque identity reference
        bytes32 kycHash; // KYC data hash
        bytes32 accountRef; // Account/customer reference
        bytes32 jurisdiction; // Jurisdiction code
        uint256 kycLevel; // KYC level threshold
        bool hasVASPLicense; // VASP license status
    }
    
    /// @notice Transaction Envelope passed into the compliance pipeline
    struct TransactionEnvelope {
        address token;          // Underlying asset token address
        uint256 amount;         // Transfer amount
        uint256 timestamp;      // Transaction timestamp (block.timestamp)
        bytes extraData;        // Optional payload (IVMS101, attestation refs, etc.)
        PartyPacket[] parties;  // Dynamic array of transaction parties
    }
    
    /// @notice Per-policy evaluation record
    struct PolicyResult {
        bytes32 policyId;           // Unique policy identifier
        uint64 policyVersion;       // Policy version number
        PolicyStatus status;        // Pass/Fail/Pending
        uint256 evaluatedAt;        // Evaluation timestamp
        bytes attestationProof;     // Policy-specific proof/evidence (free-form)
    }
    
    /// @notice Aggregated compliance attestation for a given envelope
    struct ComplianceAttestation {
        bytes32 envelopeHash;
        PolicyStatus overallStatus;
        PolicyResult[] policyResults;
    }
    
    function policyId() external view returns (bytes32);
    function policyVersion() external view returns (uint64);
    
    /**
     * @notice Evaluate this policy on a given Transaction Envelope
     * @param envelope TransactionEnvelope with enriched party data
     * @return status Pass/Fail/Pending
     * @return proof Policy-specific proof blob
     */
    function evaluate(TransactionEnvelope calldata envelope) 
        external view returns (PolicyStatus status, bytes memory proof);
}
