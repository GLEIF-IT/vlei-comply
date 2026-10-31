// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IGL1IdentityRegistry.sol";
import "./IIdentityRegistry.sol";

/// @notice Connects GL1 wallet policy evaluation to the Chainlink CCID registry.
/// @dev The oracle registers keccak256(bytes(canonicalIssuerAid)) for each wallet.
/// The policy manager consumes this lookup and the checker requires its matching endorsement.
contract ChainlinkCCIDIdentityAdapter is IGL1IdentityRegistry {
    IIdentityRegistry public immutable identityRegistry;

    constructor(address _identityRegistry) {
        require(_identityRegistry != address(0), "Invalid identity registry");
        identityRegistry = IIdentityRegistry(_identityRegistry);
    }

    function identityRef(address account) external view override returns (bytes32) {
        return identityRegistry.getIdentity(account);
    }
}
