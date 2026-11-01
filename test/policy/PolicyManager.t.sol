// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/policy/PolicyManager.sol";
import "../support/doubles/PolicyDoubles.sol";

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
        IPolicy.ComplianceAttestation memory attestation = manager.runPolicies(submitted);
        submitted.parties[0].identityRef = lookup.identityRef(address(1));
        submitted.parties[1].identityRef = lookup.identityRef(address(2));
        assertEq(attestation.envelopeHash, keccak256(abi.encode(submitted)));
        assertEq(uint256(attestation.overallStatus), uint256(IPolicy.PolicyStatus.Pass));
        assertEq(attestation.policyResults.length, 1);
        assertEq(attestation.policyResults[0].attestationProof, hex"01");
    }

    function testUnavailableLookupCannotRestoreSuppliedIdentityHints() public {
        manager.addPolicy(address(new TestPolicy(IPolicy.PolicyStatus.Pass)));
        lookup.setUnavailable();
        IPolicy.TransactionEnvelope memory submitted = envelope();
        IPolicy.ComplianceAttestation memory attestation = manager.runPolicies(submitted);
        submitted.parties[0].identityRef = bytes32(0);
        submitted.parties[1].identityRef = bytes32(0);
        assertEq(attestation.envelopeHash, keccak256(abi.encode(submitted)));
    }

    function testZeroWalletHasNoAbstractIdentityFallback() public {
        manager.addPolicy(address(new TestPolicy(IPolicy.PolicyStatus.Pass)));
        IPolicy.TransactionEnvelope memory submitted = envelope();
        submitted.parties[0].wallet = address(0);
        IPolicy.ComplianceAttestation memory attestation = manager.runPolicies(submitted);
        submitted.parties[0].identityRef = bytes32(0);
        submitted.parties[1].identityRef = lookup.identityRef(address(2));
        assertEq(attestation.envelopeHash, keccak256(abi.encode(submitted)));
    }

    function testUnknownPolicyResultDoesNotBecomePass() public {
        manager.addPolicy(address(new TestPolicy(IPolicy.PolicyStatus.Unknown)));
        IPolicy.ComplianceAttestation memory attestation = manager.runPolicies(envelope());
        assertEq(uint256(attestation.overallStatus), uint256(IPolicy.PolicyStatus.Fail));
    }

    function testNonPassingPolicyDominatesInBothOrders() public {
        TestPolicy pass = new TestPolicy(IPolicy.PolicyStatus.Pass);
        TestPolicy fail = new TestPolicy(IPolicy.PolicyStatus.Fail);
        manager.addPolicy(address(pass));
        manager.addPolicy(address(fail));
        IPolicy.ComplianceAttestation memory attestation = manager.runPolicies(envelope());
        assertEq(uint256(attestation.overallStatus), uint256(IPolicy.PolicyStatus.Fail));
        assertEq(attestation.policyResults.length, 2);
        manager.removePolicy(address(pass));
        manager.addPolicy(address(pass));
        attestation = manager.runPolicies(envelope());
        assertEq(uint256(attestation.overallStatus), uint256(IPolicy.PolicyStatus.Fail));
    }

    event PoliciesRun(address indexed caller, bytes32 indexed envelopeHash, IPolicy.PolicyStatus overallStatus);

    function testUnconfiguredManagerFailsWithAuditedEnvelope() public {
        IPolicy.TransactionEnvelope memory submitted = envelope();
        IPolicy.TransactionEnvelope memory enriched = envelope();
        enriched.parties[0].identityRef = lookup.identityRef(address(1));
        enriched.parties[1].identityRef = lookup.identityRef(address(2));
        bytes32 expectedHash = keccak256(abi.encode(enriched));

        vm.expectEmit(true, true, false, true, address(manager));
        emit PoliciesRun(address(this), expectedHash, IPolicy.PolicyStatus.Fail);
        IPolicy.ComplianceAttestation memory attestation = manager.runPolicies(submitted);

        assertEq(uint256(attestation.overallStatus), uint256(IPolicy.PolicyStatus.Fail));
        assertEq(attestation.policyResults.length, 0);
        assertEq(attestation.envelopeHash, expectedHash);
    }

    function testFreezingUnconfiguredManagerCannotEnableTransfers() public {
        manager.freezePolicies();
        lookup.setUnavailable();
        IPolicy.ComplianceAttestation memory attestation = manager.runPolicies(envelope());
        assertEq(uint256(attestation.overallStatus), uint256(IPolicy.PolicyStatus.Fail));
        assertEq(attestation.policyResults.length, 0);
    }

    function testCannotRemoveLastPolicyOrChangeItsMembership() public {
        TestPolicy policy = new TestPolicy(IPolicy.PolicyStatus.Pass);
        manager.addPolicy(address(policy));

        vm.expectRevert("Cannot remove last policy");
        manager.removePolicy(address(policy));

        assertEq(manager.policyCount(), 1);
        assertTrue(manager.isPolicy(address(policy)));
        assertEq(manager.getPolicies()[0], address(policy));
        assertEq(uint256(manager.runPolicies(envelope()).overallStatus), uint256(IPolicy.PolicyStatus.Pass));
    }

    function testReplaceOnlyPolicyByAddingSuccessorFirst() public {
        TestPolicy previous = new TestPolicy(IPolicy.PolicyStatus.Pass);
        TestPolicy successor = new TestPolicy(IPolicy.PolicyStatus.Fail);
        manager.addPolicy(address(previous));
        manager.addPolicy(address(successor));
        manager.removePolicy(address(previous));

        assertEq(manager.policyCount(), 1);
        assertFalse(manager.isPolicy(address(previous)));
        assertTrue(manager.isPolicy(address(successor)));
        assertEq(manager.getPolicies()[0], address(successor));
        IPolicy.ComplianceAttestation memory attestation = manager.runPolicies(envelope());
        assertEq(uint256(attestation.overallStatus), uint256(IPolicy.PolicyStatus.Fail));
        assertEq(attestation.policyResults.length, 1);
    }

}
