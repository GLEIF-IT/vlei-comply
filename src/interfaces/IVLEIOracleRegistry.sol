// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

/// @notice Read boundary used by the vLEI policy consumer.
interface IVLEIOracleRegistry {
    function isLegalEntityValid(bytes32 identityRef) external view returns (bool);
}
