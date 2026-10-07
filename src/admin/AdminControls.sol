// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title AdminControls
 * @notice Shared role and emergency pause controller for the compliance system.
 * @dev This contract is intentionally small so policy, wrapper, and oracle contracts can share
 * the same authority source. Production deployments should govern role grants and revocations
 * through a multisig, timelock, or equivalent operational control.
 */
contract AdminControls is AccessControl {
    /// @notice Role allowed to manage policy configuration and oracle endorsements.
    bytes32 public constant COMPLIANCE_ADMIN_ROLE = keccak256("COMPLIANCE_ADMIN_ROLE");

    /// @notice Role allowed to toggle the global emergency pause.
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    
    bool private _paused;

    /// @notice Emitted when an emergency role holder pauses the system.
    /// @param account Caller that triggered the pause.
    event Paused(address account);

    /// @notice Emitted when an emergency role holder unpauses the system.
    /// @param account Caller that removed the pause.
    event Unpaused(address account);
    
    /// @notice Restricts emergency operations to `EMERGENCY_ROLE` holders.
    /// @dev Reverts when `msg.sender` lacks the role. This modifier gates global pause controls only.
    modifier onlyEmergency() {
        require(hasRole(EMERGENCY_ROLE, msg.sender), "Not emergency role");
        _;
    }
    
    /// @notice Grants all initial administrative roles to `admin`.
    /// @param admin Initial default admin, compliance admin, and emergency operator.
    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(COMPLIANCE_ADMIN_ROLE, admin);
        _grantRole(EMERGENCY_ROLE, admin);
    }
    
    /// @notice Enables the global pause checked by the token and wrapper.
    /// @dev Pausing blocks `USDC` token updates and `wUSDC` wrapper transfer calls.
    function pause() external onlyEmergency {
        _paused = true;
        emit Paused(msg.sender);
    }
    
    /// @notice Disables the global pause.
    function unpause() external onlyEmergency {
        _paused = false;
        emit Unpaused(msg.sender);
    }
    
    /// @notice Returns whether the global pause is active.
    /// @return True when transfer-affecting contracts should reject activity.
    function isPaused() external view returns (bool) {
        return _paused;
    }

}
