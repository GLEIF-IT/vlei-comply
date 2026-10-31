// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import "@chainlink/policy-management/interfaces/IPolicyEngine.sol";

/**
 * @title AllowAllPolicyEngine
 * @notice Dev-only policy engine that lets Chainlink-style registries run locally.
 * @dev This is only for Anvil/CLI demos and tests. It satisfies the Chainlink policy-management
 * interface but never rejects operations. Do not deploy this as a production policy engine.
 * @custom:security This contract intentionally provides no access control and no policy enforcement.
 */
contract AllowAllPolicyEngine is IPolicyEngine {
    /// @notice Tracks whether a target contract has called `attach`.
    /// @dev This is diagnostic state only; it does not affect `check` or `run`.
    mapping(address target => bool attached) public isAttached;

    /// @notice Returns the dev policy engine type/version string.
    /// @return Type/version string.
    function typeAndVersion() external pure override returns (string memory) {
        return "AllowAllPolicyEngine 1.0.0";
    }

    /// @notice Records the caller as attached.
    /// @dev Emits the Chainlink policy engine event expected by registry integrations.
    function attach() external override {
        isAttached[msg.sender] = true;
        emit TargetAttached(msg.sender);
    }

    /// @notice Records the caller as detached.
    /// @dev Emits the Chainlink policy engine event expected by registry integrations.
    function detach() external override {
        isAttached[msg.sender] = false;
        emit TargetDetached(msg.sender);
    }

    /// @notice Emits extractor configuration without storing it.
    /// @param selector Function selector being configured.
    /// @param extractor Extractor address supplied by the caller.
    function setExtractor(bytes4 selector, address extractor) external override {
        emit ExtractorSet(selector, extractor);
    }

    /// @notice Emits extractor configuration for multiple selectors without storing it.
    /// @param selectors Function selectors being configured.
    /// @param extractor Extractor address supplied by the caller.
    function setExtractors(bytes4[] calldata selectors, address extractor) external override {
        for (uint256 i = 0; i < selectors.length; i++) {
            emit ExtractorSet(selectors[i], extractor);
        }
    }

    /// @notice Returns no extractor because this dev engine stores no extractor state.
    /// @return Always the zero address.
    function getExtractor(bytes4) external pure override returns (address) {
        return address(0);
    }

    /// @notice Emits policy mapper configuration without storing it.
    /// @param policy Policy address supplied by the caller.
    /// @param mapper Mapper address supplied by the caller.
    function setPolicyMapper(address policy, address mapper) external override {
        emit PolicyMapperSet(policy, mapper);
    }

    /// @notice Returns no policy mapper because this dev engine stores no mapper state.
    /// @return Always the zero address.
    function getPolicyMapper(address) external pure override returns (address) {
        return address(0);
    }

    /// @notice Emits policy addition without storing or enforcing the policy.
    /// @param target Target contract that would receive the policy.
    /// @param selector Function selector that would receive the policy.
    /// @param policy Policy address supplied by the caller.
    /// @param policyParameterNames Parameter names supplied by the caller.
    function addPolicy(
        address target,
        bytes4 selector,
        address policy,
        bytes32[] calldata policyParameterNames
    ) external override {
        emit PolicyAdded(target, selector, policy, 0, policyParameterNames);
    }

    /// @notice Emits positioned policy addition without storing or enforcing the policy.
    /// @param target Target contract that would receive the policy.
    /// @param selector Function selector that would receive the policy.
    /// @param policy Policy address supplied by the caller.
    /// @param policyParameterNames Parameter names supplied by the caller.
    /// @param position Requested insertion position.
    function addPolicyAt(
        address target,
        bytes4 selector,
        address policy,
        bytes32[] calldata policyParameterNames,
        uint256 position
    ) external override {
        address[] memory policies = new address[](1);
        policies[0] = policy;
        emit PolicyAddedAt(target, selector, policy, position, policyParameterNames, policies);
    }

    /// @notice Emits policy removal without changing enforcement behavior.
    /// @param target Target contract that would lose the policy.
    /// @param selector Function selector that would lose the policy.
    /// @param policy Policy address supplied by the caller.
    function removePolicy(address target, bytes4 selector, address policy) external override {
        emit PolicyRemoved(target, selector, policy);
    }

    /// @notice Returns an empty policy list because this dev engine stores no policies.
    /// @return Empty policy address array.
    function getPolicies(address, bytes4) external pure override returns (address[] memory) {
        return new address[](0);
    }

    /// @notice Emits policy configuration without storing it.
    /// @param policy Policy address supplied by the caller.
    /// @param configVersion Configuration version supplied by the caller.
    /// @param configSelector Configuration selector supplied by the caller.
    /// @param configData Configuration bytes supplied by the caller.
    function setPolicyConfiguration(
        address policy,
        uint256 configVersion,
        bytes4 configSelector,
        bytes calldata configData
    ) external override {
        emit PolicyConfigured(policy, configVersion, configSelector, configData);
    }

    /// @notice Returns zero because this dev engine stores no policy configuration.
    /// @return Always zero.
    function getPolicyConfigVersion(address) external pure override returns (uint256) {
        return 0;
    }

    /// @notice Emits default-policy setting without storing it.
    /// @param defaultAllow Default allow flag supplied by the caller.
    function setDefaultPolicyAllow(bool defaultAllow) external override {
        emit DefaultPolicyAllowSet(defaultAllow);
    }

    /// @notice Emits target-specific default-policy setting without storing it.
    /// @param target Target contract supplied by the caller.
    /// @param defaultAllow Default allow flag supplied by the caller.
    function setTargetDefaultPolicyAllow(address target, bool defaultAllow) external override {
        emit TargetDefaultPolicyAllowSet(target, defaultAllow);
    }

    /// @notice Accepts any payload without reverting.
    /// @dev This is the core dev-only behavior that allows local registry writes.
    function check(Payload calldata) external pure override {}

    /// @notice Accepts any payload and emits a policy-run-complete event.
    /// @param payload Chainlink policy payload supplied by the protected target.
    function run(Payload calldata payload) external override {
        Parameter[] memory parameters = new Parameter[](0);
        emit PolicyRunComplete(payload.sender, msg.sender, payload.selector, parameters, payload.context);
    }
}
