// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

/// @notice Read boundary for current wallet endorsements on this chain.
interface IVLEIOracleRegistry {
    function isEndorsed(address wallet, bytes32 identityRef) external view returns (bool);
}
