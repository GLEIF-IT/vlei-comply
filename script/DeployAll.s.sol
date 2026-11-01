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

        string memory contractsObjectKey = "contracts";
        vm.serializeAddress(contractsObjectKey, "adminControls", address(adminControls));
        vm.serializeAddress(contractsObjectKey, "devPolicyEngine", address(devPolicyEngine));
        vm.serializeAddress(contractsObjectKey, "identityRegistry", address(identities));
        vm.serializeAddress(contractsObjectKey, "identityAdapter", address(adapter));
        vm.serializeAddress(contractsObjectKey, "policyManager", address(policyManager));
        vm.serializeAddress(contractsObjectKey, "oracleRegistry", address(oracleRegistry));
        vm.serializeAddress(contractsObjectKey, "endorsementChecker", address(checker));
        vm.serializeAddress(contractsObjectKey, "associationPolicy", address(policy));
        vm.serializeAddress(contractsObjectKey, "usdcToken", address(asset));
        string memory contractsJson = vm.serializeAddress(contractsObjectKey, "wrapper", address(wrapper));
        string memory deploymentJson = string.concat(
            '{"version":1,"chainId":', vm.toString(block.chainid),
            ',"deployer":"', vm.toString(deployer), '","contracts":', contractsJson, "}"
        );
        vm.writeJson(deploymentJson, vm.envString("DEPLOYMENT_OUTPUT"));
    }
}
