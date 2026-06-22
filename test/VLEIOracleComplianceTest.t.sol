// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/admin/AdminControls.sol";
import "../src/assets/USDC.sol";
import "../src/attestation/VLEILegalEntityVerifier.sol";
import "../src/attestation/VLEIOracleRegistry.sol";
import "../src/identity/CredentialRegistry.sol";
import "../src/identity/IdentityRegistry.sol";
import "../src/identity/ChainlinkCCIDIdentityAdapter.sol";
import "../src/interfaces/IGL1IdentityRegistry.sol";
import "../src/policies/VLEILegalEntityKYCPolicy.sol";
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
    VLEILegalEntityVerifier verifier;
    PolicyManager manager;
    VLEILegalEntityKYCPolicy policy;
    USDC asset;
    wUSDC wrapper;

    address alice = address(0xA11CE);
    address bob = address(0xB0B);
    uint256 constant UNIT = 10 ** 6;

    string constant ALICE_AID = "EALICEAID";
    string constant BOB_AID = "EBOBAID";
    string constant ALICE_LEI = "5493001KJTIIGC8Y1R12";
    string constant BOB_LEI = "54930084UKLVMY22DS16";

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
        verifier = new VLEILegalEntityVerifier(address(oracleRegistry));
        manager = new PolicyManager(address(admin), address(identityRegistryAdapter));
        policy = new VLEILegalEntityKYCPolicy(
            1,
            address(identityRegistryAdapter),
            address(verifier),
            address(verifier)
        );
        manager.addPolicy(address(policy));

        asset = new USDC("USDC", "USDC", 6, address(this), 1_000_000 * UNIT, address(admin));
        wrapper = new wUSDC(address(asset), address(manager), address(admin));

        asset.transfer(alice, 1_000 * UNIT);
        vm.prank(alice);
        asset.approve(address(wrapper), type(uint256).max);

        admin.setAllowed(alice, true);
        admin.setAllowed(bob, true);

        aliceCcid = oracleRegistry.computeAidCcid(ALICE_AID);
        bobCcid = oracleRegistry.computeAidCcid(BOB_AID);
    }

    function testOracleRegistryValidationMatrix() public {
        bytes32 ccid = _postRecord(ALICE_AID, ALICE_LEI, ALICE_LEI, false, false, 0);
        assertEq(uint256(oracleRegistry.validationCode(ccid)), uint256(VLEIOracleRegistry.ValidationCode.NotAllowed));

        oracleRegistry.setAidAllowed(ccid, true);
        assertEq(uint256(oracleRegistry.validationCode(ccid)), uint256(VLEIOracleRegistry.ValidationCode.Valid));

        oracleRegistry.setCredentialRevoked(ccid, true);
        assertEq(uint256(oracleRegistry.validationCode(ccid)), uint256(VLEIOracleRegistry.ValidationCode.Revoked));
    }

    function testLeiMismatchFailsValidation() public {
        bytes32 ccid = _postRecord(ALICE_AID, ALICE_LEI, BOB_LEI, true, false, 0);
        assertEq(uint256(oracleRegistry.validationCode(ccid)), uint256(VLEIOracleRegistry.ValidationCode.LeiMismatch));
        assertFalse(oracleRegistry.isLegalEntityValid(ccid));
    }

    function testExpiredCredentialFailsValidation() public {
        bytes32 ccid = _postRecord(ALICE_AID, ALICE_LEI, ALICE_LEI, true, false, uint40(block.timestamp + 1));

        vm.warp(block.timestamp + 2);

        assertEq(uint256(oracleRegistry.validationCode(ccid)), uint256(VLEIOracleRegistry.ValidationCode.Expired));
        assertFalse(oracleRegistry.isLegalEntityValid(ccid));
    }

    function testDirectTransferFailsUntilBothAidRecordsAllowed() public {
        _registerAliceAndBob();

        assertFalse(_transferAsAlice(100 * UNIT), "missing oracle records should fail");

        _postRecord(ALICE_AID, ALICE_LEI, ALICE_LEI, true, false, 0);
        assertFalse(_transferAsAlice(100 * UNIT), "missing beneficiary oracle record should fail");

        _postRecord(BOB_AID, BOB_LEI, BOB_LEI, false, false, 0);
        assertFalse(_transferAsAlice(100 * UNIT), "unallowlisted beneficiary AID should fail");

        oracleRegistry.setAidAllowed(bobCcid, true);
        assertTrue(_transferAsAlice(100 * UNIT), "valid sender and beneficiary should pass");
        assertEq(asset.balanceOf(bob), 100 * UNIT);
    }

    function testMissingSenderIdentityFails() public {
        chainlinkIdentityRegistry.registerIdentity(bobCcid, bob, "");
        _postRecord(BOB_AID, BOB_LEI, BOB_LEI, true, false, 0);

        assertFalse(_transferAsAlice(100 * UNIT));
        assertEq(asset.balanceOf(bob), 0);
    }

    function testRevokedSenderFailsTransfer() public {
        _registerAliceAndBob();
        _postValidAliceAndBob();
        oracleRegistry.setCredentialRevoked(aliceCcid, true);

        assertFalse(_transferAsAlice(100 * UNIT));
        assertEq(asset.balanceOf(bob), 0);
    }

    function testExpiredBeneficiaryFailsTransfer() public {
        _registerAliceAndBob();
        _postRecord(ALICE_AID, ALICE_LEI, ALICE_LEI, true, false, 0);
        _postRecord(BOB_AID, BOB_LEI, BOB_LEI, true, false, uint40(block.timestamp + 1));

        vm.warp(block.timestamp + 2);

        assertFalse(_transferAsAlice(100 * UNIT));
        assertEq(asset.balanceOf(bob), 0);
    }

    function testTransferWithBeneficiaryUsesAidOnlyParties() public {
        _postValidAliceAndBob();

        vm.prank(alice);
        bool success = wrapper.transferWithBeneficiary(bob, 100 * UNIT, aliceCcid, bobCcid);

        assertTrue(success);
        assertEq(asset.balanceOf(bob), 100 * UNIT);
    }

    function _registerAliceAndBob() internal {
        chainlinkIdentityRegistry.registerIdentity(aliceCcid, alice, "");
        chainlinkIdentityRegistry.registerIdentity(bobCcid, bob, "");
    }

    function _postValidAliceAndBob() internal {
        _postRecord(ALICE_AID, ALICE_LEI, ALICE_LEI, true, false, 0);
        _postRecord(BOB_AID, BOB_LEI, BOB_LEI, true, false, 0);
    }

    function _postRecord(
        string memory aid,
        string memory entityLei,
        string memory credentialSubjectLei,
        bool allowed,
        bool revoked,
        uint40 expiresAt
    ) internal returns (bytes32) {
        return oracleRegistry.postLegalEntityRecord(
            aid,
            entityLei,
            credentialSubjectLei,
            keccak256(abi.encodePacked(aid, "-acdc")),
            keccak256(abi.encodePacked(aid, "-proof")),
            0,
            expiresAt,
            allowed,
            revoked
        );
    }

    function _transferAsAlice(uint256 amount) internal returns (bool) {
        vm.prank(alice);
        return wrapper.transfer(bob, amount);
    }
}
