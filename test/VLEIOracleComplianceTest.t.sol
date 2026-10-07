// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/admin/AdminControls.sol";
import "../src/assets/USDC.sol";
import "../src/attestation/VLEIEndorsementChecker.sol";
import "../src/attestation/VLEIOracleRegistry.sol";
import "../src/identity/CredentialRegistry.sol";
import "../src/identity/IdentityRegistry.sol";
import "../src/identity/ChainlinkCCIDIdentityAdapter.sol";
import "../src/interfaces/IGL1IdentityRegistry.sol";
import "../src/policies/VLEIWalletAssociationPolicy.sol";
import "../src/policy/AllowAllPolicyEngine.sol";
import "../src/policy/PolicyManager.sol";
import "../src/wrappers/wUSDC.sol";

contract VLEIOracleComplianceTest is Test {
    AdminControls admin;
    AllowAllPolicyEngine policyEngine;
    IdentityRegistry chainlinkIdentityRegistry;
    CredentialRegistry credentialRegistry;
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

        CredentialRegistry credentialImpl = new CredentialRegistry();
        ERC1967Proxy credentialProxy = new ERC1967Proxy(
            address(credentialImpl),
            abi.encodeCall(CredentialRegistry.initialize, (address(policyEngine), address(this)))
        );
        credentialRegistry = CredentialRegistry(address(credentialProxy));

        identityRegistryAdapter = IGL1IdentityRegistry(
            address(new ChainlinkCCIDIdentityAdapter(address(chainlinkIdentityRegistry), address(credentialRegistry)))
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

    function testAidOnlyCustomerPartiesCannotPass() public {
        _registerAndEndorse();
        vm.prank(alice);
        assertFalse(wrapper.transferWithBeneficiary(bob, 100 * UNIT, aliceCcid, bobCcid));
        assertEq(asset.balanceOf(bob), 0);
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
        assertFalse(verifier.checkEndorsement(party));
        party.wallet = alice;
        assertTrue(verifier.checkEndorsement(party));
        party.identityRef = bobCcid;
        assertFalse(verifier.checkEndorsement(party));
        party.identityRef = bytes32(0);
        assertFalse(verifier.checkEndorsement(party));
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
        vm.prank(alice);
        assertTrue(wrapper.transferWithBeneficiary(bob, UNIT, bytes32(0), bytes32(0)));
        vm.prank(alice);
        assertTrue(wrapper.transferFromWithBeneficiary(alice, bob, UNIT, bytes32(0), bytes32(0)));
        assertEq(asset.balanceOf(bob), 4 * UNIT);
    }

    function testWrapperApprovalDoesNotAuthorizeAnotherCallerToSpend() public {
        _registerAndEndorse();
        address attacker = address(0xBAD);
        vm.prank(attacker);
        vm.expectRevert("Caller must be token owner");
        wrapper.transferFrom(alice, bob, UNIT);
        vm.prank(attacker);
        vm.expectRevert("Caller must be token owner");
        wrapper.transferFromWithBeneficiary(alice, bob, UNIT, bytes32(0), bytes32(0));
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
        vm.prank(alice);
        vm.expectRevert("System paused");
        wrapper.transferWithBeneficiary(bob, UNIT, bytes32(0), bytes32(0));
        vm.prank(alice);
        vm.expectRevert("System paused");
        wrapper.transferFromWithBeneficiary(alice, bob, UNIT, bytes32(0), bytes32(0));
        admin.unpause();
        assertTrue(_transfer());
    }

    function testEmergencyPauseRemainsRoleProtected() public {
        vm.prank(alice);
        vm.expectRevert("Not emergency role");
        admin.pause();
        assertFalse(admin.isPaused());
    }

}
