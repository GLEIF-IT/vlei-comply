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
     * @notice Checks whether an address appears in the implementing list.
     * @param addr Address to check.
     * @return inList True when the address is present in the list.
     */
    function isInList(address addr) external view returns (bool inList);
}
