// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/admin/AdminControls.sol";
import "../src/policy/PolicyManager.sol";
import "../src/demo/AllowAllPolicyEngine.sol";
import "../src/identity/IdentityRegistry.sol";
import "../src/identity/ChainlinkCCIDIdentityAdapter.sol";
import "../src/associations/VLEIOracleRegistry.sol";
import "../src/associations/VLEIEndorsementChecker.sol";
import "../src/demo/USDC.sol";
import "../src/wrappers/wUSDC.sol";
import "../src/policy/VLEIWalletAssociationPolicy.sol";

/// @notice Deploy the local direct-wallet association and audit prototype.
/// @dev The dev-only allow-all engine enables local Chainlink registry writes.
/// Production registry governance and key management remain separate work.
contract DeployAll is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        AdminControls adminControls = new AdminControls(deployer);
        AllowAllPolicyEngine devPolicyEngine = new AllowAllPolicyEngine();
        IdentityRegistry identityImpl = new IdentityRegistry();
        ERC1967Proxy identityProxy = new ERC1967Proxy(
            address(identityImpl),
            abi.encodeCall(IdentityRegistry.initialize, (address(devPolicyEngine), deployer))
        );
        IdentityRegistry identities = IdentityRegistry(address(identityProxy));
        ChainlinkCCIDIdentityAdapter adapter = new ChainlinkCCIDIdentityAdapter(address(identities));
        PolicyManager policyManager = new PolicyManager(address(adminControls), address(adapter));
        VLEIOracleRegistry oracleRegistry = new VLEIOracleRegistry(address(adminControls));
        VLEIEndorsementChecker checker = new VLEIEndorsementChecker(address(oracleRegistry));
        VLEIWalletAssociationPolicy policy = new VLEIWalletAssociationPolicy(1, address(checker));
        policyManager.addPolicy(address(policy));
        USDC asset = new USDC("USDC", "USDC", 6, deployer, 0, address(adminControls));
        wUSDC wrapper = new wUSDC(address(asset), address(policyManager), address(adminControls));
        vm.stopBroadcast();

        string memory addresses = "contracts";
        vm.serializeAddress(addresses, "adminControls", address(adminControls));
        vm.serializeAddress(addresses, "devPolicyEngine", address(devPolicyEngine));
        vm.serializeAddress(addresses, "identityRegistry", address(identities));
        vm.serializeAddress(addresses, "identityAdapter", address(adapter));
        vm.serializeAddress(addresses, "policyManager", address(policyManager));
        vm.serializeAddress(addresses, "oracleRegistry", address(oracleRegistry));
        vm.serializeAddress(addresses, "endorsementChecker", address(checker));
        vm.serializeAddress(addresses, "associationPolicy", address(policy));
        vm.serializeAddress(addresses, "usdcToken", address(asset));
        string memory contractsJson = vm.serializeAddress(addresses, "wrapper", address(wrapper));
        string memory output = string.concat(
            '{"version":1,"chainId":', vm.toString(block.chainid),
            ',"deployer":"', vm.toString(deployer), '","contracts":', contractsJson, "}"
        );
        vm.writeJson(output, vm.envString("DEPLOYMENT_OUTPUT"));
    }
}
