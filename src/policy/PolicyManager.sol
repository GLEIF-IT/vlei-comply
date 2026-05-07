// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import "../interfaces/IPolicy.sol";
import "../interfaces/IPolicyManager.sol";
import "../interfaces/IGL1IdentityRegistry.sol";
import "../admin/AdminControls.sol";

/**
 * @title PolicyManager
 * @notice Orchestration layer for compliance policy evaluation
 * @dev Implements Transaction Envelope pattern:
 *      - Receives minimal TxContext from PolicyWrapper
 *      - Enriches party packets via IGL1IdentityRegistry
 *      - Builds TransactionEnvelope
 *      - Evaluates all policies
 *      - Aggregates into ComplianceAttestation
 */
contract PolicyManager is IPolicyManager {
    AdminControls public immutable adminControls;
    IGL1IdentityRegistry public immutable identityRegistry;
    
    address[] public policies;
    mapping(address => bool) public isPolicy;
    bool public frozen;
    
    event PolicyAdded(address indexed policy);
    event PolicyRemoved(address indexed policy);
    event PolicySetFrozen();
    event PolicySetUnfrozen();
    event PoliciesRun(address indexed caller, bytes32 indexed envelopeHash, IPolicy.PolicyStatus overallStatus);
    
    modifier onlyAdmin() {
        require(adminControls.hasRole(adminControls.COMPLIANCE_ADMIN_ROLE(), msg.sender), "Not admin");
        _;
    }
    
    modifier notFrozen() {
        require(!frozen, "Policy set frozen");
        _;
    }
    
    constructor(address _adminControls, address _identityRegistry) {
        adminControls = AdminControls(_adminControls);
        identityRegistry = IGL1IdentityRegistry(_identityRegistry);
    }
    
    function addPolicy(address policy) external onlyAdmin notFrozen {
        require(policy != address(0), "Invalid policy address");
        require(!isPolicy[policy], "Policy already added");
        
        policies.push(policy);
        isPolicy[policy] = true;
        emit PolicyAdded(policy);
    }
    
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
    
    function freezePolicies() external onlyAdmin notFrozen {
        frozen = true;
        emit PolicySetFrozen();
    }

    function unfreezePolicies() external onlyAdmin {
        frozen = false;
        emit PolicySetUnfrozen();
    }
    
    /**
     * @notice Run all policies on a transaction envelope
     * @dev Implements orchestration layer pattern:
     *      1. Enrich party packets via IGL1IdentityRegistry
     *      2. Evaluate all policies
     *      3. Aggregate results (Fail > Pending > Pass)
     *      4. Return ComplianceAttestation
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
            enrichedParties[i] = envelope.parties[i];
            
            if (address(identityRegistry) != address(0)) {

            if (enrichedParties[i].identityRef == bytes32(0)) {
                try identityRegistry.getBeneficiaryId(enrichedParties[i].wallet) returns (bytes32 val) {
                    if (val != bytes32(0)) {
                        enrichedParties[i].identityRef = val;
                    }
                } catch {}
            }

            if (enrichedParties[i].kycHash == bytes32(0)) {
                try identityRegistry.kycHash(enrichedParties[i].wallet) returns (bytes32 val) {
                    if (val != bytes32(0)) {
                        enrichedParties[i].kycHash = val;
                    }
                } catch {}
            }

            if (enrichedParties[i].accountRef == bytes32(0)) {
                try identityRegistry.accountRef(enrichedParties[i].wallet) returns (bytes32 val) {
                    if (val != bytes32(0)) {
                        enrichedParties[i].accountRef = val;
                    }
                } catch {}
            }

            if (enrichedParties[i].jurisdiction == bytes32(0)) {
                try identityRegistry.jurisdiction(enrichedParties[i].wallet) returns (bytes32 val) {
                    if (val != bytes32(0)) {
                        enrichedParties[i].jurisdiction = val;
                    }
                } catch {}
            }

            if (enrichedParties[i].kycLevel == 0) {
                try identityRegistry.kycLevel(enrichedParties[i].wallet) returns (uint256 val) {
                    if (val != 0) {
                        enrichedParties[i].kycLevel = val;
                    }
                } catch {}
            }

            if (enrichedParties[i].hasVASPLicense == false) {
                try identityRegistry.hasVASPLicense(enrichedParties[i].wallet) returns (bool val) {
                    if (val != false) {
                        enrichedParties[i].hasVASPLicense = val;
                    }
                } catch {}
            }
            }
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
    
    function policyCount() external view returns (uint256) {
        return policies.length;
    }
    
    function getPolicies() external view returns (address[] memory) {
        return policies;
    }
}
