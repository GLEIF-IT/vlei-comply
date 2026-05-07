// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title AdminControls
 * @notice Administrative control for compliance infrastructure
 */
contract AdminControls is AccessControl {
    bytes32 public constant COMPLIANCE_ADMIN_ROLE = keccak256("COMPLIANCE_ADMIN_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    
    bool private _paused;

    // Global Allowlist (Gatekeeper)
    mapping(address => bool) private _allowlist;
    event AllowlistUpdated(address indexed account, bool isAllowed);

    
    event Paused(address account);
    event Unpaused(address account);
    
    modifier onlyEmergency() {
        require(hasRole(EMERGENCY_ROLE, msg.sender), "Not emergency role");
        _;
    }
    
    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(COMPLIANCE_ADMIN_ROLE, admin);
        _grantRole(EMERGENCY_ROLE, admin);
    }
    
    function pause() external onlyEmergency {
        _paused = true;
        emit Paused(msg.sender);
    }
    
    function unpause() external onlyEmergency {
        _paused = false;
        emit Unpaused(msg.sender);
    }
    
    function isPaused() external view returns (bool) {
        return _paused;
    }

    /**
     * @notice Add or remove an address from the global allowlist
     * @param account Address to manage
     * @param allowed Whether the address is allowed
     */
    function setAllowed(address account, bool allowed) external onlyRole(COMPLIANCE_ADMIN_ROLE) {
        _allowlist[account] = allowed;
        emit AllowlistUpdated(account, allowed);
    }
    
    /**
     * @notice Check if an address is globally allowed
     * @param account Address to check
     * @return Whether the address is allowed
     */
    function isAllowed(address account) external view returns (bool) {
        return _allowlist[account];
    }

}
