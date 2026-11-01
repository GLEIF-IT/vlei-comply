// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../policy/IPolicyManager.sol";
import "../policy/IPolicy.sol";
import "../admin/AdminControls.sol";

/// @notice Noncustodial wallet-to-wallet transfer route with auditable compliance decisions.
/// @dev The owner approves this wrapper on the underlying token and initiates each transfer.
/// PolicyManager records the evaluated envelope hash; failed policy checks emit a rejection.
contract wUSDC {
    IERC20 public immutable asset;
    IPolicyManager public immutable policyManager;
    AdminControls public immutable adminControls;

    /// @notice Policy rejected the transfer; no underlying token call was made.
    /// @param policyId First non-passing policy in evaluation order; zero when no policy is configured.
    /// @param reasonCode Aggregate policy status, distinct from per-policy proof reasons.
    event ComplianceCheckFailed(
        address indexed from,
        address indexed to,
        uint256 amount,
        bytes32 policyId,
        uint8 reasonCode
    );

    constructor(address _asset, address _policyManager, address _adminControls) {
        asset = IERC20(_asset);
        policyManager = IPolicyManager(_policyManager);
        adminControls = AdminControls(_adminControls);
    }

    modifier whenNotPaused() {
        require(!adminControls.isPaused(), "System paused");
        _;
    }

    /// @notice Wrapper allowance authorizes the token call, not another caller.
    modifier onlyTokenOwner(address from) {
        require(msg.sender == from, "Caller must be token owner");
        _;
    }

    /// @notice Evaluate both wallets and transfer the caller's approved underlying tokens.
    /// @return False on policy rejection; the underlying token call may revert.
    function transfer(address to, uint256 amount) external whenNotPaused returns (bool) {
        return _transfer(msg.sender, to, amount);
    }

    /// @notice Explicit-source variant; the caller must own the source wallet.
    /// @return False on policy rejection; the underlying token call may revert.
    function transferFrom(address from, address to, uint256 amount)
        external whenNotPaused onlyTokenOwner(from) returns (bool)
    {
        return _transfer(from, to, amount);
    }

    function _transfer(address from, address to, uint256 amount) private returns (bool) {
        IPolicy.PartyPacket[] memory parties = new IPolicy.PartyPacket[](2);
        parties[0] = IPolicy.PartyPacket({
            role: IPolicy.PartyRole.OriginatorCustomer,
            wallet: from,
            identityRef: bytes32(0)
        });
        parties[1] = IPolicy.PartyPacket({
            role: IPolicy.PartyRole.BeneficiaryCustomer,
            wallet: to,
            identityRef: bytes32(0)
        });
        IPolicy.TransactionEnvelope memory envelope = IPolicy.TransactionEnvelope({
            token: address(asset), amount: amount, timestamp: block.timestamp, parties: parties
        });
        IPolicy.ComplianceAttestation memory attestation = policyManager.runPolicies(envelope);
        if (attestation.overallStatus != IPolicy.PolicyStatus.Pass) {
            bytes32 failingPolicyId;
            for (uint256 i = 0; i < attestation.policyResults.length; i++) {
                if (attestation.policyResults[i].status != IPolicy.PolicyStatus.Pass) {
                    failingPolicyId = attestation.policyResults[i].policyId;
                    break;
                }
            }
            emit ComplianceCheckFailed(from, to, amount, failingPolicyId, uint8(attestation.overallStatus));
            return false;
        }
        return asset.transferFrom(from, to, amount);
    }
}
