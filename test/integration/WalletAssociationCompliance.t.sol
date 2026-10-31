// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../../src/admin/AdminControls.sol";
import "../../src/demo/USDC.sol";
import "../../src/associations/VLEIEndorsementChecker.sol";
import "../../src/associations/VLEIOracleRegistry.sol";
import "../../src/identity/IdentityRegistry.sol";
import "../../src/identity/ChainlinkCCIDIdentityAdapter.sol";
import "../../src/identity/IGL1IdentityRegistry.sol";
import "../../src/policy/VLEIWalletAssociationPolicy.sol";
import "../../src/demo/AllowAllPolicyEngine.sol";
import "../../src/policy/PolicyManager.sol";
import "../../src/wrappers/wUSDC.sol";

contract WalletAssociationComplianceTest is Test {
    AdminControls admin;
    AllowAllPolicyEngine policyEngine;
    IdentityRegistry chainlinkIdentityRegistry;
    IGL1IdentityRegistry identityRegistryAdapter;
    VLEIOracleRegistry oracleRegistry;
    VLEIEndorsementChecker verifier;
    PolicyManager manager;
    VLEIWalletAssociationPolicy policy;
    USDC asset;
    wUSDC wrapper;

    address alice = address(0xA11CE);
    address bob = address(0xB0B);
    uint256 constant UNIT = 10 ** 6;

    string constant ALICE_AID = "EALICEAID";
    string constant BOB_AID = "EBOBAID";
    string constant ALICE_SAID = "EALICEASSOCIATION";
    string constant BOB_SAID = "EBOBASSOCIATION";

    bytes32 aliceCcid;
    bytes32 bobCcid;

    function setUp() public {
        admin = new AdminControls(address(this));
        policyEngine = new AllowAllPolicyEngine();

        IdentityRegistry identityImpl = new IdentityRegistry();
        ERC1967Proxy identityProxy = new ERC1967Proxy(
            address(identityImpl),
            abi.encodeCall(IdentityRegistry.initialize, (address(policyEngine), address(this)))
        );
        chainlinkIdentityRegistry = IdentityRegistry(address(identityProxy));

        identityRegistryAdapter = IGL1IdentityRegistry(
            address(new ChainlinkCCIDIdentityAdapter(address(chainlinkIdentityRegistry)))
        );

        oracleRegistry = new VLEIOracleRegistry(address(admin));
        verifier = new VLEIEndorsementChecker(address(oracleRegistry));
        manager = new PolicyManager(address(admin), address(identityRegistryAdapter));
        policy = new VLEIWalletAssociationPolicy(1, address(verifier));
        manager.addPolicy(address(policy));

        asset = new USDC("USDC", "USDC", 6, address(this), 1_000_000 * UNIT, address(admin));
        wrapper = new wUSDC(address(asset), address(manager), address(admin));

        asset.transfer(alice, 1_000 * UNIT);
        vm.prank(alice);
        asset.approve(address(wrapper), type(uint256).max);


        aliceCcid = keccak256(bytes(ALICE_AID));
        bobCcid = keccak256(bytes(BOB_AID));
    }

    function _registerAndEndorse() internal {
        chainlinkIdentityRegistry.registerIdentity(aliceCcid, alice, "");
        chainlinkIdentityRegistry.registerIdentity(bobCcid, bob, "");
        oracleRegistry.publishEndorsement(alice, aliceCcid, ALICE_SAID);
        oracleRegistry.publishEndorsement(bob, bobCcid, BOB_SAID);
    }

    function _transfer() internal returns (bool) {
        vm.prank(alice);
        return wrapper.transfer(bob, 100 * UNIT);
    }

    function testTransferRequiresBothExactWalletEndorsements() public {
        chainlinkIdentityRegistry.registerIdentity(aliceCcid, alice, "");
        chainlinkIdentityRegistry.registerIdentity(bobCcid, bob, "");
        assertFalse(_transfer());
        oracleRegistry.publishEndorsement(alice, aliceCcid, ALICE_SAID);
        assertFalse(_transfer());
        oracleRegistry.publishEndorsement(bob, bobCcid, BOB_SAID);
        assertTrue(_transfer());
        assertEq(asset.balanceOf(bob), 100 * UNIT);
    }

    function testWithdrawnOriginatorCannotTransferThroughStaleMapping() public {
        _registerAndEndorse();
        oracleRegistry.withdrawEndorsement(alice, ALICE_SAID);
        assertFalse(_transfer());
        assertEq(chainlinkIdentityRegistry.getIdentity(alice), aliceCcid);
        assertEq(asset.balanceOf(bob), 0);
    }

    function testWithdrawnBeneficiaryRejectsTransfer() public {
        _registerAndEndorse();
        oracleRegistry.withdrawEndorsement(bob, BOB_SAID);
        assertFalse(_transfer());
        assertEq(asset.balanceOf(bob), 0);
    }

    function testEndorsementForAnotherWalletOfTheSameEntityIsInsufficient() public {
        chainlinkIdentityRegistry.registerIdentity(aliceCcid, alice, "");
        chainlinkIdentityRegistry.registerIdentity(bobCcid, bob, "");
        oracleRegistry.publishEndorsement(address(0xCAFE), aliceCcid, ALICE_SAID);
        oracleRegistry.publishEndorsement(bob, bobCcid, BOB_SAID);
        assertFalse(_transfer());
    }

    function testIdentityMismatchFailsForBothRoles() public {
        _registerAndEndorse();
        oracleRegistry.publishEndorsement(alice, bobCcid, "different-originator");
        assertFalse(_transfer());
        oracleRegistry.publishEndorsement(alice, aliceCcid, ALICE_SAID);
        oracleRegistry.publishEndorsement(bob, aliceCcid, "different-beneficiary");
        assertFalse(_transfer());
    }

    function testReplacementRemainsUsableAfterLateWithdrawal() public {
        _registerAndEndorse();
        oracleRegistry.publishEndorsement(alice, aliceCcid, "new-association");
        oracleRegistry.withdrawEndorsement(alice, ALICE_SAID);
        assertTrue(_transfer());
        oracleRegistry.withdrawEndorsement(alice, "new-association");
        assertFalse(_transfer());
    }

    function testMissingIdentityAndElapsedTime() public {
        oracleRegistry.publishEndorsement(alice, aliceCcid, ALICE_SAID);
        oracleRegistry.publishEndorsement(bob, bobCcid, BOB_SAID);
        assertFalse(_transfer());
        chainlinkIdentityRegistry.registerIdentity(aliceCcid, alice, "");
        chainlinkIdentityRegistry.registerIdentity(bobCcid, bob, "");
        vm.warp(block.timestamp + 365 days);
        assertTrue(_transfer());
    }

    function testCheckerRejectsZeroWalletAndWrongIdentity() public {
        oracleRegistry.publishEndorsement(alice, aliceCcid, ALICE_SAID);
        IPolicy.PartyPacket memory party;
        party.identityRef = aliceCcid;
        assertFalse(verifier.validate(party));
        party.wallet = alice;
        assertTrue(verifier.validate(party));
        party.identityRef = bobCcid;
        assertFalse(verifier.validate(party));
        party.identityRef = bytes32(0);
        assertFalse(verifier.validate(party));
    }
    function testPolicyRequiresBothCustomerRoles() public {
        _registerAndEndorse();
        IPolicy.TransactionEnvelope memory envelope;
        envelope.parties = new IPolicy.PartyPacket[](1);
        envelope.parties[0].role = IPolicy.PartyRole.OriginatorCustomer;
        envelope.parties[0].wallet = alice;
        envelope.parties[0].identityRef = aliceCcid;
        (IPolicy.PolicyStatus status, bytes memory reason) = policy.evaluate(envelope);
        assertEq(uint256(status), uint256(IPolicy.PolicyStatus.Fail));
        assertEq(abi.decode(reason, (uint8)), 11);
        envelope.parties[0].role = IPolicy.PartyRole.BeneficiaryCustomer;
        (status, reason) = policy.evaluate(envelope);
        assertEq(uint256(status), uint256(IPolicy.PolicyStatus.Fail));
        assertEq(abi.decode(reason, (uint8)), 10);
    }

    function testOwnerCanUseEveryTransferEntryPointWithoutWalletAdmission() public {
        _registerAndEndorse();
        vm.prank(alice);
        assertTrue(wrapper.transfer(bob, UNIT));
        vm.prank(alice);
        assertTrue(wrapper.transferFrom(alice, bob, UNIT));
        assertEq(asset.balanceOf(bob), 2 * UNIT);
    }

    function testWrapperApprovalDoesNotAuthorizeAnotherCallerToSpend() public {
        _registerAndEndorse();
        address attacker = address(0xBAD);
        vm.prank(attacker);
        vm.expectRevert("Caller must be token owner");
        wrapper.transferFrom(alice, bob, UNIT);
        assertEq(asset.balanceOf(alice), 1_000 * UNIT);
        assertEq(asset.balanceOf(bob), 0);
    }

    function testEmergencyPauseStillProtectsEveryTransferEntryPoint() public {
        _registerAndEndorse();
        admin.pause();
        vm.prank(alice);
        vm.expectRevert("System paused");
        wrapper.transfer(bob, UNIT);
        vm.prank(alice);
        vm.expectRevert("System paused");
        wrapper.transferFrom(alice, bob, UNIT);
        admin.unpause();
        assertTrue(_transfer());
    }

    function testEmergencyPauseRemainsRoleProtected() public {
        vm.prank(alice);
        vm.expectRevert("Not emergency role");
        admin.pause();
        assertFalse(admin.isPaused());
    }

    event PoliciesRun(address indexed caller, bytes32 indexed envelopeHash, IPolicy.PolicyStatus overallStatus);
    event ComplianceCheckFailed(
        address indexed from, address indexed to, uint256 amount, bytes32 policyId, uint8 reasonCode
    );

    function testPassAuditBindsBothResolvedWalletsAndTransfer() public {
        _registerAndEndorse();
        IPolicy.PartyPacket[] memory parties = new IPolicy.PartyPacket[](2);
        parties[0] = IPolicy.PartyPacket(IPolicy.PartyRole.OriginatorCustomer, alice, aliceCcid);
        parties[1] = IPolicy.PartyPacket(IPolicy.PartyRole.BeneficiaryCustomer, bob, bobCcid);
        IPolicy.TransactionEnvelope memory envelope = IPolicy.TransactionEnvelope(
            address(asset), UNIT, block.timestamp, parties
        );
        vm.expectEmit(true, true, false, true, address(manager));
        emit PoliciesRun(address(wrapper), keccak256(abi.encode(envelope)), IPolicy.PolicyStatus.Pass);
        vm.prank(alice);
        assertTrue(wrapper.transfer(bob, UNIT));
        assertEq(asset.balanceOf(bob), UNIT);
        assertEq(asset.balanceOf(alice), 999 * UNIT);
    }

    function testRejectedTransferAuditPreservesBalancesAndAllowance() public {
        _registerAndEndorse();
        oracleRegistry.withdrawEndorsement(bob, BOB_SAID);
        uint256 allowance = asset.allowance(alice, address(wrapper));
        vm.expectEmit(true, true, false, true, address(wrapper));
        emit ComplianceCheckFailed(alice, bob, UNIT, policy.policyId(), uint8(IPolicy.PolicyStatus.Fail));
        vm.prank(alice);
        assertFalse(wrapper.transfer(bob, UNIT));
        assertEq(asset.balanceOf(bob), 0);
        assertEq(asset.balanceOf(alice), 1_000 * UNIT);
        assertEq(asset.allowance(alice, address(wrapper)), allowance);
    }

    function testExplicitSourceRouteRechecksCurrentAssociation() public {
        _registerAndEndorse();
        vm.prank(alice);
        assertTrue(wrapper.transferFrom(alice, bob, UNIT));
        oracleRegistry.withdrawEndorsement(bob, BOB_SAID);
        vm.prank(alice);
        assertFalse(wrapper.transferFrom(alice, bob, UNIT));
        assertEq(asset.balanceOf(bob), UNIT);
    }

    function testRetiredMediationAndAdminSettlementCallsAreAbsent() public {
        _registerAndEndorse();
        vm.prank(alice);
        (bool mediated, bytes memory mediatedError) = address(wrapper).call(abi.encodeWithSignature(
            "transferWithBeneficiary(address,uint256,bytes32,bytes32)", bob, UNIT, aliceCcid, bobCcid
        ));
        assertFalse(mediated);
        assertEq(mediatedError.length, 0);
        vm.prank(alice);
        (bool explicitSource, bytes memory sourceError) = address(wrapper).call(abi.encodeWithSignature(
            "transferFromWithBeneficiary(address,address,uint256,bytes32,bytes32)",
            alice, bob, UNIT, aliceCcid, bobCcid
        ));
        assertFalse(explicitSource);
        assertEq(sourceError.length, 0);
        (bool adminSettlement, bytes memory settlementError) = address(wrapper).call(abi.encodeWithSignature(
            "resolvePendingTransaction(uint256,bool)", 1, true
        ));
        assertFalse(adminSettlement);
        assertEq(settlementError.length, 0);
        assertEq(asset.balanceOf(bob), 0);
        assertEq(asset.balanceOf(alice), 1_000 * UNIT);
    }

}
