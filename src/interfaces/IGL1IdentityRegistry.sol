// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Wallet-to-entity lookup consumed by the GL1 policy manager.
interface IGL1IdentityRegistry {
    /// @return Entity identity registered for this exact wallet, or zero if missing.
    function identityRef(address account) external view returns (bytes32);
}
