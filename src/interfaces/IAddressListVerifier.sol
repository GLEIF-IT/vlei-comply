// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

/**
 * @title IAddressListVerifier
 * @notice Interface for address allowlist/blocklist verification
 * @dev Simple on-chain address list - NOT recommended for production
 *      Production systems should use services like Chainalysis or TRM Labs
 */
interface IAddressListVerifier {
    /**
     * @notice Check if an address is in the list
     * @param addr Address to check
     * @return inList Whether address is in the list
     */
    function isInList(address addr) external view returns (bool inList);
}
