// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import "../interfaces/IPolicy.sol";
import "../interfaces/IPolicyManager.sol";
import "../interfaces/IGL1IdentityRegistry.sol";
import "../admin/AdminControls.sol";

/**
 * @title PolicyManager
 * @notice Orchestration layer for transaction-envelope policy evaluation.
 * @dev The manager enriches wrapper-supplied party packets from `IGL1IdentityRegistry`,
 * evaluates each registered policy, and aggregates status using Fail > Pending > Pass.
 * It deliberately catches identity-registry read failures during enrichment so missing or
 * unavailable identity data reaches policies as zero values and policies can fail closed.
 */
contract PolicyManager is IPolicyManager {
    /// @notice Shared administrative authority for policy set management.
    AdminControls public immutable adminControls;

    /// @notice Identity enrichment adapter, currently backed by Chainlink CCID registries.
    IGL1IdentityRegistry public immutable identityRegistry;
    
    /// @notice Ordered list of active policy contract addresses.
    address[] public policies;

    /// @notice True when an address is currently registered as an active policy.
    mapping(address => bool) public isPolicy;

    /// @notice True when policy additions/removals are disabled.
    bool public frozen;
    
    /// @notice Emitted when a policy is added to the evaluation set.
    /// @param policy Policy contract address added.
    event PolicyAdded(address indexed policy);

    /// @notice Emitted when a policy is removed from the evaluation set.
    /// @param policy Policy contract address removed.
    event PolicyRemoved(address indexed policy);

    /// @notice Emitted when the policy set is frozen.
    event PolicySetFrozen();

    /// @notice Emitted when the policy set is unfrozen.
    event PolicySetUnfrozen();

    /// @notice Emitted after all active policies are evaluated for an envelope.
    /// @param caller Address that invoked `runPolicies`, normally a wrapper contract.
    /// @param envelopeHash Hash of the enriched envelope that was evaluated.
    /// @param overallStatus Aggregate status returned to the wrapper.
    event PoliciesRun(address indexed caller, bytes32 indexed envelopeHash, IPolicy.PolicyStatus overallStatus);
    
    /// @notice Restricts policy administration to compliance administrators.
    /// @dev Reverts when `msg.sender` lacks `AdminControls.COMPLIANCE_ADMIN_ROLE`.
    modifier onlyAdmin() {
        require(adminControls.hasRole(adminControls.COMPLIANCE_ADMIN_ROLE(), msg.sender), "Not admin");
        _;
    }
    
    /// @notice Restricts policy set mutation while frozen.
    /// @dev Used to lock the policy set after deployment or before production operation.
    modifier notFrozen() {
        require(!frozen, "Policy set frozen");
        _;
    }
    
    /// @notice Creates the policy manager.
    /// @param _adminControls Shared admin controls contract.
    /// @param _identityRegistry GL1 identity registry adapter used for enrichment.
    constructor(address _adminControls, address _identityRegistry) {
        adminControls = AdminControls(_adminControls);
        identityRegistry = IGL1IdentityRegistry(_identityRegistry);
    }
    
    /// @notice Adds a policy to the evaluation set.
    /// @dev Requires the set to be unfrozen and rejects duplicate or zero policy addresses.
    /// @param policy Policy contract address to add.
    function addPolicy(address policy) external onlyAdmin notFrozen {
        require(policy != address(0), "Invalid policy address");
        require(!isPolicy[policy], "Policy already added");
        
        policies.push(policy);
        isPolicy[policy] = true;
        emit PolicyAdded(policy);
    }
    
    /// @notice Removes a policy from the evaluation set.
    /// @dev Uses swap-and-pop, so policy order can change when removing a non-final entry.
    /// @param policy Policy contract address to remove.
    function removePolicy(address policy) external onlyAdmin notFrozen {
        require(isPolicy[policy], "Not a policy");
        
        uint256 len = policies.length;
        for (uint256 i = 0; i < len; i++) {
            if (policies[i] == policy) {
                if (i != len - 1) {
                    policies[i] = policies[len - 1];
                }
                policies.pop();
                break;
            }
        }
        
        isPolicy[policy] = false;
        emit PolicyRemoved(policy);
    }
    
    /// @notice Freezes the policy set against further additions/removals.
    /// @dev Does not pause evaluation of already registered policies.
    function freezePolicies() external onlyAdmin notFrozen {
        frozen = true;
        emit PolicySetFrozen();
    }

    /// @notice Unfreezes the policy set so admins can add or remove policies.
    /// @dev Production deployments should prefer governed change windows around this call.
    function unfreezePolicies() external onlyAdmin {
        frozen = false;
        emit PolicySetUnfrozen();
    }
    
    /**
     * @notice Runs all registered policies on a transaction envelope.
     * @dev Enrichment order is ID-aware:
     * 1. If a wallet exists and `identityRef` is zero, resolve wallet -> CCID via `getBeneficiaryId`.
     * 2. If `identityRef` is nonzero, prefer id-based enrichment for AID-only flows.
     * 3. If a wallet exists, fall back to wallet-based fields for any still-empty values.
     * Missing registry data is left as zero values so policies can fail closed.
     * @param envelope Wrapper-supplied transaction envelope.
     * @return attestation Aggregate compliance result and per-policy records.
     */
    function runPolicies(IPolicy.TransactionEnvelope calldata envelope) 
        external override returns (IPolicy.ComplianceAttestation memory attestation) {
        
        uint256 len = policies.length;
        if (len == 0) {
            attestation.overallStatus = IPolicy.PolicyStatus.Pass;
            return attestation;
        }
        
        // 1. Enrich party packets via IGL1IdentityRegistry
        IPolicy.PartyPacket[] memory enrichedParties = new IPolicy.PartyPacket[](envelope.parties.length);
        
        for (uint256 i = 0; i < envelope.parties.length; i++) {
            enrichedParties[i] = _enrichParty(envelope.parties[i]);
        }
        
        IPolicy.TransactionEnvelope memory enrichedEnvelope = envelope;
        enrichedEnvelope.parties = enrichedParties;
        
        // 2. Evaluate all policies
        IPolicy.PolicyResult[] memory results = new IPolicy.PolicyResult[](len);
        IPolicy.PolicyStatus overall = IPolicy.PolicyStatus.Pass;
        
        for (uint256 i = 0; i < len; i++) {
            address policyAddr = policies[i];
            IPolicy policy = IPolicy(policyAddr);
            
            (IPolicy.PolicyStatus status, bytes memory proof) = policy.evaluate(enrichedEnvelope);
            
            if (status == IPolicy.PolicyStatus.Fail) {
                overall = IPolicy.PolicyStatus.Fail;
            } else if (status == IPolicy.PolicyStatus.Pending && overall != IPolicy.PolicyStatus.Fail) {
                overall = IPolicy.PolicyStatus.Pending;
            }
            
            results[i] = IPolicy.PolicyResult({
                policyId: policy.policyId(),
                policyVersion: policy.policyVersion(),
                status: status,
                evaluatedAt: block.timestamp,
                attestationProof: proof
            });
        }
        
        // 3. Simple aggregation: Fail > Pending > Pass
        bytes32 envHash = keccak256(abi.encode(enrichedEnvelope));
        
        // 4. Build ComplianceAttestation
        attestation = IPolicy.ComplianceAttestation({
            envelopeHash: envHash,
            overallStatus: overall,
            policyResults: results
        });
        
        emit PoliciesRun(msg.sender, envHash, overall);
    }
    
    /// @notice Returns the number of active policies.
    /// @return Number of policy addresses in evaluation order.
    function policyCount() external view returns (uint256) {
        return policies.length;
    }
    
    /// @notice Returns the active policy address list.
    /// @return Policy addresses in current evaluation order.
    function getPolicies() external view returns (address[] memory) {
        return policies;
    }

    /// @notice Enriches one party with available identity registry data.
    /// @dev This function supports wallet-present flows and AID-only flows. External read
    /// failures are ignored to keep policy evaluation deterministic and fail-closed.
    /// @param party Wrapper-supplied party packet.
    /// @return enriched Party packet with best-effort registry enrichment.
    function _enrichParty(IPolicy.PartyPacket calldata party) internal view returns (IPolicy.PartyPacket memory enriched) {
        enriched = party;

        if (address(identityRegistry) == address(0)) {
            return enriched;
        }

        if (enriched.identityRef == bytes32(0) && enriched.wallet != address(0)) {
            try identityRegistry.getBeneficiaryId(enriched.wallet) returns (bytes32 val) {
                if (val != bytes32(0)) {
                    enriched.identityRef = val;
                }
            } catch {}
        }

        if (enriched.identityRef != bytes32(0)) {
            enriched = _enrichById(enriched);
        }

        if (enriched.wallet != address(0)) {
            enriched = _enrichByWallet(enriched);
        }
    }

    /// @notice Enriches a party from id-based registry getters.
    /// @param party Party packet whose `identityRef` is nonzero.
    /// @return enriched Party packet after id-based lookups.
    function _enrichById(IPolicy.PartyPacket memory party) internal view returns (IPolicy.PartyPacket memory enriched) {
        enriched = party;
        bytes32 identityRef = enriched.identityRef;

        try identityRegistry.identityRefById(identityRef) returns (bytes32 val) {
            if (val != bytes32(0)) {
                enriched.identityRef = val;
                identityRef = val;
            }
        } catch {}

        if (enriched.kycHash == bytes32(0)) {
            try identityRegistry.kycHashById(identityRef) returns (bytes32 val) {
                if (val != bytes32(0)) {
                    enriched.kycHash = val;
                }
            } catch {}
        }

        if (enriched.accountRef == bytes32(0)) {
            try identityRegistry.accountRefById(identityRef) returns (bytes32 val) {
                if (val != bytes32(0)) {
                    enriched.accountRef = val;
                }
            } catch {}
        }

        if (enriched.jurisdiction == bytes32(0)) {
            try identityRegistry.jurisdictionById(identityRef) returns (bytes32 val) {
                if (val != bytes32(0)) {
                    enriched.jurisdiction = val;
                }
            } catch {}
        }

        if (enriched.kycLevel == 0) {
            try identityRegistry.kycLevelById(identityRef) returns (uint256 val) {
                if (val != 0) {
                    enriched.kycLevel = val;
                }
            } catch {}
        }

        if (!enriched.hasVASPLicense) {
            try identityRegistry.hasVASPLicenseById(identityRef) returns (bool val) {
                if (val) {
                    enriched.hasVASPLicense = true;
                }
            } catch {}
        }
    }

    /// @notice Enriches a party from wallet-based registry getters.
    /// @param party Party packet whose `wallet` is nonzero.
    /// @return enriched Party packet after wallet-based lookups.
    function _enrichByWallet(IPolicy.PartyPacket memory party) internal view returns (IPolicy.PartyPacket memory enriched) {
        enriched = party;

        if (enriched.kycHash == bytes32(0)) {
            try identityRegistry.kycHash(enriched.wallet) returns (bytes32 val) {
                if (val != bytes32(0)) {
                    enriched.kycHash = val;
                }
            } catch {}
        }

        if (enriched.accountRef == bytes32(0)) {
            try identityRegistry.accountRef(enriched.wallet) returns (bytes32 val) {
                if (val != bytes32(0)) {
                    enriched.accountRef = val;
                }
            } catch {}
        }

        if (enriched.jurisdiction == bytes32(0)) {
            try identityRegistry.jurisdiction(enriched.wallet) returns (bytes32 val) {
                if (val != bytes32(0)) {
                    enriched.jurisdiction = val;
                }
            } catch {}
        }

        if (enriched.kycLevel == 0) {
            try identityRegistry.kycLevel(enriched.wallet) returns (uint256 val) {
                if (val != 0) {
                    enriched.kycLevel = val;
                }
            } catch {}
        }

        if (!enriched.hasVASPLicense) {
            try identityRegistry.hasVASPLicense(enriched.wallet) returns (bool val) {
                if (val) {
                    enriched.hasVASPLicense = true;
                }
            } catch {}
        }
    }
}
