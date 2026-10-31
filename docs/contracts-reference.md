# Contracts Reference

## Enforcement

- `wUSDC`: owner-initiated `transfer` / `transferFrom` routes; records rejection and executes only after policy Pass.
- `AdminControls`: role-based administrative contract for compliance admins and emergency pause.

## Policy

- `PolicyManager`: policy registry, identity enrichment orchestrator, and aggregate policy evaluator.
- `VLEIWalletAssociationPolicy`: policy requiring current exact-wallet endorsements for both customer roles.

## Identity

- `IdentityRegistry`: Chainlink-style CCID-to-account registry.
- `ChainlinkCCIDIdentityAdapter`: adapts the exact-wallet Chainlink CCID lookup to the GL1 `IGL1IdentityRegistry` interface.

## Associations

- `VLEIOracleRegistry`: authorized current wallet/entity/association registry.
- `VLEIEndorsementChecker`: fail-closed endorsement checker that reads `IVLEIOracleRegistry`.

## Interfaces

- `IPolicy`: asset/amount/timestamp envelope, wallet/identity party, policy result and evaluator interface. No KYC fields or pending decisions.
- `IPolicyManager`: wrapper-to-manager policy orchestration interface.
- `IGL1IdentityRegistry`: single wallet-to-entity lookup consumed by the policy manager.
- `IAttestationServiceVerifier`: generic party verifier interface.
- `IVLEIOracleRegistry`: current wallet endorsement read interface.
- `identity/IIdentityRegistry.sol`: the Chainlink CCID identity registry interface.

Interfaces live with their owner: policy interfaces in policy/, wallet identity
lookup interfaces in identity/, and registry reads in associations/.

## Demo

- `demo/USDC.sol`: local ERC-20 asset with owner minting, holder burn and global pause.
- `demo/AllowAllPolicyEngine.sol`: dev-only Chainlink engine for Anvil/tests.

Their concrete consumers are DeployAll and test fixtures; production components
use asset and policy interfaces rather than importing demo implementations.
