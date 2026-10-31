// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/associations/VLEIOracleRegistry.sol";

contract VLEIOracleRegistryTest is Test {
    AdminControls admin;
    VLEIOracleRegistry registry;
    address wallet = address(0xA11CE);
    bytes32 entity = keccak256("entity");

    function setUp() public {
        admin = new AdminControls(address(this));
        registry = new VLEIOracleRegistry(address(admin));
    }

    function testPublicationEncodingVector() public {
        string memory vector = vm.readFile("abi/endorsement-vector.json");
        address account = vm.parseJsonAddress(vector, ".wallet");
        bytes32 identityRef = vm.parseJsonBytes32(vector, ".identityRef");
        string memory said = vm.parseJsonString(vector, ".associationSaid");
        bytes memory encoded = abi.encodeCall(VLEIOracleRegistry.publishEndorsement, (account, identityRef, said));
        assertEq(encoded, vm.parseJsonBytes(vector, ".calldata"));
        (bool success,) = address(registry).call(encoded);
        assertTrue(success);
        assertEq(registry.getEndorsement(account).associationSaid, said);
    }

    function testPublicationWithdrawalAndReplacement() public {
        assertFalse(registry.isEndorsed(wallet, entity));
        registry.publishEndorsement(wallet, entity, "association-one");
        assertTrue(registry.isEndorsed(wallet, entity));
        VLEIOracleRegistry.Endorsement memory current = registry.getEndorsement(wallet);
        assertEq(current.identityRef, entity);
        assertEq(current.associationSaid, "association-one");
        registry.publishEndorsement(wallet, entity, "association-two");
        assertFalse(registry.withdrawEndorsement(wallet, "association-one"));
        assertTrue(registry.isEndorsed(wallet, entity));
        assertTrue(registry.withdrawEndorsement(wallet, "association-two"));
        assertFalse(registry.isEndorsed(wallet, entity));
        assertEq(registry.getEndorsement(wallet).associationSaid, "");
        assertFalse(registry.withdrawEndorsement(wallet, "association-two"));
    }

    function testWriterAuthorizationAndLossOfRole() public {
        address writer = address(0xB0B);
        vm.prank(writer);
        vm.expectRevert("Not compliance admin");
        registry.publishEndorsement(wallet, entity, "association");
        admin.grantRole(admin.COMPLIANCE_ADMIN_ROLE(), writer);
        vm.prank(writer);
        registry.publishEndorsement(wallet, entity, "association");
        admin.revokeRole(admin.COMPLIANCE_ADMIN_ROLE(), writer);
        // Removing a writer does not retroactively erase its records.
        assertTrue(registry.isEndorsed(wallet, entity));
        vm.prank(writer);
        vm.expectRevert("Not compliance admin");
        registry.withdrawEndorsement(wallet, "association");
        assertTrue(registry.isEndorsed(wallet, entity));
    }

    function testEmptyInputsFailClosed() public {
        vm.expectRevert("Wallet required");
        registry.publishEndorsement(address(0), entity, "association");
        vm.expectRevert("Identity required");
        registry.publishEndorsement(wallet, bytes32(0), "association");
        vm.expectRevert("Association required");
        registry.publishEndorsement(wallet, entity, "");
        assertFalse(registry.isEndorsed(wallet, bytes32(0)));
    }

    function testWalletAndIdentityIsolation() public {
        registry.publishEndorsement(wallet, entity, "association");
        assertFalse(registry.isEndorsed(address(0xB0B), entity));
        assertFalse(registry.isEndorsed(wallet, keccak256("other entity")));
    }

    function testDeploymentScopeAndTimeDoNotChangeAnEndorsement() public {
        registry.publishEndorsement(wallet, entity, "association");
        VLEIOracleRegistry otherChainRegistry = new VLEIOracleRegistry(address(admin));
        assertFalse(otherChainRegistry.isEndorsed(wallet, entity));
        vm.warp(block.timestamp + 365 days);
        assertTrue(registry.isEndorsed(wallet, entity));
    }
}
