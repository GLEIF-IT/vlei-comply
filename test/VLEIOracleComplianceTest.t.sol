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

        aliceCcid = keccak256(bytes(ALICE_AID));
        bobCcid = keccak256(bytes(BOB_AID));
    }

    function testPolicyRejectsUnboundParties() public {
        chainlinkIdentityRegistry.registerIdentity(aliceCcid, alice, "");
        chainlinkIdentityRegistry.registerIdentity(bobCcid, bob, "");
        oracleRegistry.publishEndorsement(alice, aliceCcid, ALICE_SAID);
        oracleRegistry.publishEndorsement(bob, bobCcid, BOB_SAID);
        vm.prank(alice);
        assertFalse(wrapper.transfer(bob, 100 * UNIT));
        assertEq(asset.balanceOf(bob), 0);
    }
}
