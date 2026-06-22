// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./IPolicy.sol";

/**
 * @title IPolicyManager
 * @notice Interface for the policy orchestration layer used by wrapper contracts.
 * @dev `wUSDC` calls this interface with minimally populated party packets. The manager is
 * responsible for identity enrichment and aggregate policy status calculation.
 */
interface IPolicyManager {
    /// @notice Lightweight transaction context from a wrapper.
    /// @dev Retained for generated-wrapper compatibility. The active wrapper path currently
    /// constructs full `IPolicy.TransactionEnvelope` values directly.
    struct TxContext {
        /// @notice Underlying asset token address.
        address token;
        /// @notice Source wallet, which may be a VASP wallet.
        address from;
        /// @notice Destination wallet, which may be a VASP wallet.
        address to;
        /// @notice Transfer amount in token base units.
        uint256 amount;
        /// @notice Optional payload for beneficiary IDs, IVMS101, or policy-specific context.
        bytes extraData;
    }
    
    /// @notice Runs every registered policy against a transaction envelope.
    /// @dev Implementations should enrich identity data before evaluation and aggregate results
    /// into one status. This function may emit operational logs and is not necessarily `view`.
    /// @param envelope Transaction envelope with party packets supplied by the wrapper.
    /// @return attestation Aggregated compliance attestation.
    function runPolicies(IPolicy.TransactionEnvelope calldata envelope) 
        external returns (IPolicy.ComplianceAttestation memory attestation);
}
