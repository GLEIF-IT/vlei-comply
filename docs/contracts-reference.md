# Contracts Reference

## Enforcement

- `USDC`: ERC-20 asset with owner minting, holder burn, and global pause enforcement.
- `wUSDC`: wrapper-style transfer surface that builds policy envelopes and executes transfers only after compliance passes.
- `AdminControls`: role-based administrative contract for compliance admins and emergency pause.

## Policy

- `PolicyManager`: policy registry, identity enrichment orchestrator, and aggregate policy evaluator.
- `VLEIWalletAssociationPolicy`: policy requiring current exact-wallet endorsements for both customer roles.
- `AllowAllPolicyEngine`: dev-only Chainlink policy engine shim for Anvil and tests.

## Identity

- `IdentityRegistry`: Chainlink-style CCID-to-account registry.
- `CredentialRegistry`: Chainlink-style CCID credential store.
- `CredentialRegistryIdentityValidator`: validates configured credential requirements across identity and credential sources.
- `TrustedIssuerRegistry`: stores trusted issuer hashes.
- `ChainlinkCCIDIdentityAdapter`: adapts Chainlink CCID data to the GL1 `IGL1IdentityRegistry` interface.

## Attestation And Oracle

- `VLEIOracleRegistry`: authorized current wallet/entity/association registry.
- `VLEIEndorsementChecker`: fail-closed endorsement checker that reads `IVLEIOracleRegistry`.

## Interfaces

- `IPolicy`: common transaction envelope, party packet, policy result, and policy evaluator interface.
- `IPolicyManager`: wrapper-to-manager policy orchestration interface.
- `IGL1IdentityRegistry`: GL1 policy identity enrichment interface.
- `IAttestationServiceVerifier`: generic party verifier interface.
- `IVLEIEndorsementChecker`: vLEI-specific consumer extension.
- `IVLEIOracleRegistry`: current wallet endorsement read interface.
- `identity/interfaces/*`: Chainlink CCID identity, credential, issuer, and requirement interfaces.
