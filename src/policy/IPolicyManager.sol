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
    /// @notice Runs every registered policy against a transaction envelope.
    /// @dev Implementations should enrich identity data before evaluation and aggregate results
    /// into one status. This function may emit operational logs and is not necessarily `view`.
    /// @param envelope Transaction envelope with party packets supplied by the wrapper.
    /// @return attestation Aggregated compliance attestation.
    function runPolicies(IPolicy.TransactionEnvelope calldata envelope) 
        external returns (IPolicy.ComplianceAttestation memory attestation);
}
