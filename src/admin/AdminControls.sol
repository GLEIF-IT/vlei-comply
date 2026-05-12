// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title AdminControls
 * @notice Shared role, pause, and wallet allowlist controller for the compliance system.
 * @dev This contract is intentionally small so policy, wrapper, and oracle contracts can share
 * the same authority source. Production deployments should govern role grants and revocations
 * through a multisig, timelock, or equivalent operational control.
 */
contract AdminControls is AccessControl {
    /// @notice Role allowed to manage policy configuration, wallet allowlist, and oracle evidence.
    bytes32 public constant COMPLIANCE_ADMIN_ROLE = keccak256("COMPLIANCE_ADMIN_ROLE");

    /// @notice Role allowed to toggle the global emergency pause.
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    
    bool private _paused;

    mapping(address => bool) private _allowlist;

    /// @notice Emitted whenever a wallet's wrapper-level allowlist status changes.
    /// @param account Wallet whose allowlist status changed.
    /// @param isAllowed True when the wallet is allowed to call wrapper transfer functions.
    event AllowlistUpdated(address indexed account, bool isAllowed);

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
    /// @dev Pausing blocks `vLEI` token updates and `wvLEI` wrapper transfer calls.
    function pause() external onlyEmergency {
        _paused = true;
        emit Paused(msg.sender);
    }
    
    /// @notice Disables the global pause.
    /// @dev This does not alter wallet or AID allowlist state.
    function unpause() external onlyEmergency {
        _paused = false;
        emit Unpaused(msg.sender);
    }
    
    /// @notice Returns whether the global pause is active.
    /// @return True when transfer-affecting contracts should reject activity.
    function isPaused() external view returns (bool) {
        return _paused;
    }

    /**
     * @notice Adds or removes a wallet from the wrapper-level allowlist.
     * @dev This is distinct from the vLEI AID allowlist in `vLEIOracleRegistry`.
     * @param account Wallet address to manage.
     * @param allowed True to allow the wallet to call wrapper transfer functions.
     */
    function setAllowed(address account, bool allowed) external onlyRole(COMPLIANCE_ADMIN_ROLE) {
        _allowlist[account] = allowed;
        emit AllowlistUpdated(account, allowed);
    }
    
    /**
     * @notice Checks whether a wallet is allowed to call wrapper transfer functions.
     * @param account Wallet address to check.
     * @return True when `account` is wrapper-allowlisted.
     */
    function isAllowed(address account) external view returns (bool) {
        return _allowlist[account];
    }

}
