// SPDX-License-Identifier: Apache-2.0
pragma solidity ^ 0.8.24;

import "forge-std/Test.sol";
import "../src/admin/AdminControls.sol";
import "../src/policy/PolicyManager.sol";
import "../src/identity/TrustedIssuerRegistry.sol";
import "../src/identity/IdentityRegistry.sol";
import "../src/identity/CredentialRegistry.sol";
import "../src/identity/CredentialRegistryIdentityValidator.sol";
import "../src/identity/ChainlinkCCIDIdentityAdapter.sol";
import "../src/identity/interfaces/ICredentialRequirements.sol";
import "../src/assets/vLEI.sol";
import "../src/wrappers/wvLEI.sol";
import "../src/interfaces/IPolicy.sol";

// MockPolicy for infrastructure testing (ensures stable environment for pending/resolution tests)
contract MockPolicy is IPolicy {
    PolicyStatus public overrideStatus;

    constructor(PolicyStatus _status) {
        overrideStatus = _status;
    }

    function setStatus(PolicyStatus _status) external {
        overrideStatus = _status;
    }

    function policyId() external pure returns(bytes32) {
        return keccak256("MOCK");
    }

    function policyVersion() external pure returns(uint64) {
        return 1;
    }

    function evaluate(IPolicy.TransactionEnvelope calldata) 
        external view returns(IPolicy.PolicyStatus status, bytes memory proof) {
        return (overrideStatus, "");
    }
}



contract ComplianceTest is Test {
    AdminControls admin;
    TrustedIssuerRegistry trustedIssuerRegistry;
    IdentityRegistry vendorIdentityRegistry;
    CredentialRegistry credentialRegistry;
    CredentialRegistryIdentityValidator credentialRegistryIdentityValidator;
    
    IGL1IdentityRegistry public identityRegistry;
    PolicyManager manager;
    vLEI asset;
    wvLEI wrapper;
    MockPolicy mockPolicy;

    address alice = address(0x1);
    address bob = address(0x2);
    uint256 constant UNIT = 10**18;

    function setUp() public {
        admin = new AdminControls(address(this));
        
        // Deploy vendor identity contracts directly (CHAINLINK_CCI).
        // Initialization is skipped because vendor constructors call _disableInitializers().
        // This is safe for testing: view functions return defaults, and MockPolicy controls outcomes.
        // For production deployment, use ERC1967Proxy - see DeployAll.s.sol.
        trustedIssuerRegistry = new TrustedIssuerRegistry();
        vendorIdentityRegistry = new IdentityRegistry();
        credentialRegistry = new CredentialRegistry();
        credentialRegistryIdentityValidator = new CredentialRegistryIdentityValidator();

        
        identityRegistry = IGL1IdentityRegistry(address(new ChainlinkCCIDIdentityAdapter(address(vendorIdentityRegistry), address(credentialRegistryIdentityValidator))));
        
        manager = new PolicyManager(address(admin), address(identityRegistry));
        
        asset = new vLEI("vLEI", "VLEI", 18, address(this), 1000000 * 10**18, address(admin));

        wrapper = new wvLEI (
            address(asset),
            address(manager),
            address(admin)
        );

        // Add mock policy for infrastructure tests (defaults to Pending)
        mockPolicy = new MockPolicy(IPolicy.PolicyStatus.Pending);
        manager.addPolicy(address(mockPolicy));

        // Grant roles
        admin.grantRole(admin.COMPLIANCE_ADMIN_ROLE(), address(this));

        // Setup tokens
        
        asset.transfer(alice, 1000 * UNIT);
        vm.prank(alice);
        asset.approve(address(wrapper), 1000 * UNIT);
        

        admin.setAllowed(alice, true);
        admin.setAllowed(bob, true);
    }

    // Event definitions for expectEmit matching
    event ComplianceCheckFailed(address indexed from, address indexed to, uint256 amount, bytes32 policyId, uint8 reasonCode);
    event TransactionPending(uint256 indexed pendingId, address indexed from, address indexed to, uint256 amount, bytes32 envelopeHash);
    event TransactionResolved(uint256 indexed pendingId, bool approved);

    function testPendingQueuesTransaction() public {
        // Policy is Pending - transfer should be queued, not fail outright

        vm.prank(alice);
        
        bool success = wrapper.transfer(bob, 100 * UNIT);
        assertFalse(success, "Pending should return false");
        // Verify pending transaction was queued
        assertEq(wrapper.pendingNonce(), 1, "Should have 1 pending tx");
        
    }

    function testPassAllowsTransfer() public {
        // First, create a pending transaction
        vm.prank(alice);
        
        wrapper.transfer(bob, 100 * UNIT);
        

        // Now resolve it as approved - this should execute the stored transfer
        wrapper.resolvePendingTransaction(1, true);

        
        assertEq(asset.balanceOf(bob), 100 * UNIT);
        
    }

    function testRejectPendingTransaction() public {
        // Create a pending transaction
        vm.prank(alice);
        
        wrapper.transfer(bob, 100 * UNIT);
        

        // Reject it - transfer should NOT execute
        wrapper.resolvePendingTransaction(1, false);

        
        assertEq(asset.balanceOf(bob), 0, "Bob should have no tokens after rejection");
        
    }

    function testMultiPartyTransfer() public {
        // First queue a simple transfer to get pending nonce to 1, then resolve it
        vm.prank(alice);
        
        wrapper.transfer(bob, 50 * UNIT);
        
        wrapper.resolvePendingTransaction(1, true);
        
        bytes32 originatorId = keccak256("Originator");
        bytes32 beneficiaryId = keccak256("Beneficiary");
        
        vm.prank(alice);
        
        wrapper.transferWithBeneficiary(bob, 100 * UNIT, originatorId, beneficiaryId);
        // Resolve multi-party pending tx
        wrapper.resolvePendingTransaction(2, true);
        assertEq(asset.balanceOf(bob), 150 * UNIT, "Multi-party transfer should succeed after resolution");
        
    }
}
