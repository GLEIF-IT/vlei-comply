// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import "../../../src/policy/IPolicy.sol";
import "../../../src/identity/IGL1IdentityRegistry.sol";

contract TestIdentityLookup is IGL1IdentityRegistry {
    bool public unavailable;

    function setUnavailable() external { unavailable = true; }

    function identityRef(address wallet) external view returns (bytes32) {
        require(!unavailable, "Registry unavailable");
        return keccak256(abi.encode(wallet));
    }
}

contract TestPolicy is IPolicy {
    PolicyStatus private immutable result;

    constructor(PolicyStatus status) { result = status; }

    function policyId() external pure returns (bytes32) { return keccak256("TEST_POLICY"); }
    function policyVersion() external pure returns (uint64) { return 1; }
    function evaluate(TransactionEnvelope calldata) external view returns (PolicyStatus, bytes memory) {
        return (result, hex"01");
    }
}
