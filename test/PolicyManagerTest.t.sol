// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/policy/PolicyManager.sol";

contract TestIdentityLookup is IGL1IdentityRegistry {
    bool public unavailable;

    function setUnavailable() external { unavailable = true; }

    function identityRef(address wallet) external view returns (bytes32) {
        require(!unavailable, "Registry unavailable");
        return keccak256(abi.encode(wallet));
    }
}

contract TestPolicy is IPolicy {
    PolicyStatus private immutable result;

    constructor(PolicyStatus status) { result = status; }

    function policyId() external pure returns (bytes32) { return keccak256("TEST_POLICY"); }
    function policyVersion() external pure returns (uint64) { return 1; }
    function evaluate(TransactionEnvelope calldata) external view returns (PolicyStatus, bytes memory) {
        return (result, hex"01");
    }
}

contract PolicyManagerTest is Test {
    PolicyManager manager;
    TestIdentityLookup lookup;

    function setUp() public {
        lookup = new TestIdentityLookup();
        manager = new PolicyManager(address(new AdminControls(address(this))), address(lookup));
    }

    function envelope() private view returns (IPolicy.TransactionEnvelope memory txEnvelope) {
        txEnvelope.timestamp = block.timestamp;
        txEnvelope.parties = new IPolicy.PartyPacket[](2);
        txEnvelope.parties[0] = IPolicy.PartyPacket(
            IPolicy.PartyRole.OriginatorCustomer, address(1), keccak256("untrusted hint")
        );
        txEnvelope.parties[1] = IPolicy.PartyPacket(
            IPolicy.PartyRole.BeneficiaryCustomer, address(2), keccak256("another hint")
        );
    }

    function testAuditHashUsesWalletLookupInsteadOfSuppliedIdentityHints() public {
        manager.addPolicy(address(new TestPolicy(IPolicy.PolicyStatus.Pass)));
        IPolicy.TransactionEnvelope memory submitted = envelope();
        IPolicy.ComplianceAttestation memory result = manager.runPolicies(submitted);
        submitted.parties[0].identityRef = lookup.identityRef(address(1));
        submitted.parties[1].identityRef = lookup.identityRef(address(2));
        assertEq(result.envelopeHash, keccak256(abi.encode(submitted)));
        assertEq(uint256(result.overallStatus), uint256(IPolicy.PolicyStatus.Pass));
        assertEq(result.policyResults.length, 1);
        assertEq(result.policyResults[0].attestationProof, hex"01");
    }

    function testUnavailableLookupCannotRestoreSuppliedIdentityHints() public {
        manager.addPolicy(address(new TestPolicy(IPolicy.PolicyStatus.Pass)));
        lookup.setUnavailable();
        IPolicy.TransactionEnvelope memory submitted = envelope();
        IPolicy.ComplianceAttestation memory result = manager.runPolicies(submitted);
        submitted.parties[0].identityRef = bytes32(0);
        submitted.parties[1].identityRef = bytes32(0);
        assertEq(result.envelopeHash, keccak256(abi.encode(submitted)));
    }

    function testZeroWalletHasNoAbstractIdentityFallback() public {
        manager.addPolicy(address(new TestPolicy(IPolicy.PolicyStatus.Pass)));
        IPolicy.TransactionEnvelope memory submitted = envelope();
        submitted.parties[0].wallet = address(0);
        IPolicy.ComplianceAttestation memory result = manager.runPolicies(submitted);
        submitted.parties[0].identityRef = bytes32(0);
        submitted.parties[1].identityRef = lookup.identityRef(address(2));
        assertEq(result.envelopeHash, keccak256(abi.encode(submitted)));
    }

    function testUnknownPolicyResultDoesNotBecomePass() public {
        manager.addPolicy(address(new TestPolicy(IPolicy.PolicyStatus.Unknown)));
        IPolicy.ComplianceAttestation memory result = manager.runPolicies(envelope());
        assertEq(uint256(result.overallStatus), uint256(IPolicy.PolicyStatus.Fail));
    }

    function testNonPassingPolicyDominatesInBothOrders() public {
        TestPolicy pass = new TestPolicy(IPolicy.PolicyStatus.Pass);
        TestPolicy fail = new TestPolicy(IPolicy.PolicyStatus.Fail);
        manager.addPolicy(address(pass));
        manager.addPolicy(address(fail));
        IPolicy.ComplianceAttestation memory result = manager.runPolicies(envelope());
        assertEq(uint256(result.overallStatus), uint256(IPolicy.PolicyStatus.Fail));
        assertEq(result.policyResults.length, 2);
        manager.removePolicy(address(pass));
        manager.addPolicy(address(pass));
        result = manager.runPolicies(envelope());
        assertEq(uint256(result.overallStatus), uint256(IPolicy.PolicyStatus.Fail));
    }
}
