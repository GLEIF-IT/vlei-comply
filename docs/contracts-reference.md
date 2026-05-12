# Contracts Reference

## Enforcement

- `vLEI`: ERC-20 asset with owner minting, holder burn, and global pause enforcement.
- `wvLEI`: wrapper-style transfer surface that builds policy envelopes and executes transfers only after compliance passes.
- `AdminControls`: role-based administrative contract for compliance admins, emergency pause, and wallet allowlist.

## Policy

- `PolicyManager`: policy registry, identity enrichment orchestrator, and aggregate policy evaluator.
- `vLEI_kyc_and_sanctions`: first-pass policy requiring valid originator and beneficiary Legal Entity status.
- `AllowAllPolicyEngine`: dev-only Chainlink policy engine shim for Anvil and tests.

## Identity

- `IdentityRegistry`: Chainlink-style CCID-to-account registry.
- `CredentialRegistry`: Chainlink-style CCID credential store, retained for future credential-source work.
- `CredentialRegistryIdentityValidator`: validates configured credential requirements across identity and credential sources.
- `TrustedIssuerRegistry`: stores trusted issuer hashes for future issuer-governance use.
- `IdentityRegistryAdapter`: adapts Chainlink CCID data to the GL1 `IGL1IdentityRegistry` interface.

## Attestation And Oracle

- `vLEIOracleRegistry`: oracle/admin-posted Legal Entity evidence registry.
- `vLEIAttestationVerifier`: fail-closed verifier that reads `vLEIOracleRegistry`.
- `GLEIFAdapter`: legacy/generated placeholder kept for compatibility; not the active vLEI verifier path. TODO: remove

## Interfaces

- `IPolicy`: common transaction envelope, party packet, policy result, and policy evaluator interface.
- `IPolicyManager`: wrapper-to-manager policy orchestration interface.
- `IGL1IdentityRegistry`: GL1 policy identity enrichment interface.
- `IAttestationServiceVerifier`: generic party verifier interface.
- `IvLEIVerifier`: vLEI-specific verifier extension.
- `IAddressListVerifier`: simple list verifier interface retained for generated compatibility.
- `identity/interfaces/*`: Chainlink CCID identity, credential, issuer, and requirement interfaces.
