// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./IPolicy.sol";

/**
 * @title IPolicyManager
 * @notice Interface for the PolicyManager orchestration layer
 * @dev Defines the contract between PolicyWrapper and PolicyManager
 */
interface IPolicyManager {
    /// @notice Lightweight transaction context from caller (e.g., PolicyWrapper)
    /// @dev Minimal data packet sent by wrapper - PolicyManager will enrich
    struct TxContext {
        address token;      // Underlying asset token address
        address from;       // Source wallet (may be VASP)
        address to;         // Destination wallet (may be VASP)
        uint256 amount;     // Transfer amount
        bytes extraData;    // Optional payload (beneficiary IDs, IVMS101, etc.)
    }
    
    /// @notice Run all registered policies on a given Transaction Envelope
    /// @dev Implementation expected to:
    ///      1. Enrich identity via IdentityRegistry for all parties
    ///      2. Evaluate all policies
    ///      3. Aggregate results into ComplianceAttestation
    /// @param envelope Transaction envelope with party packets (partially filled)
    /// @return attestation Aggregated compliance attestation (Pass/Fail/Pending)
    function runPolicies(IPolicy.TransactionEnvelope calldata envelope) 
        external returns (IPolicy.ComplianceAttestation memory attestation);
}
