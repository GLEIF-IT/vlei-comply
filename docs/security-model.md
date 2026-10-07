# Security Model

This repository is a production-preparation prototype. It demonstrates the contract boundaries and fail-closed behavior expected in a production USDC compliance integration, but it is not production-ready as deployed.

## Trust Boundaries

| Boundary | Current implementation |
|---|---|
| Wallet access | `AdminControls` allowlist gates wrapper callers. |
| Identity mapping | Chainlink `IdentityRegistry` maps wallet to `aidCcid`. |
| vLEI evidence | `VLEIOracleRegistry` stores admin/oracle-posted status. |
| Policy evaluation | `PolicyManager` evaluates all configured policies with fail priority. |
| Direct token transfer | `USDC` only checks global pause. |

## Admin Roles

`AdminControls.COMPLIANCE_ADMIN_ROLE` can:

- manage wallet allowlist,
- add/remove/freeze policy set,
- post and update vLEI oracle records,
- allowlist or revoke AID-level status.

`AdminControls.EMERGENCY_ROLE` can pause and unpause the system.

## Fail-Closed Behavior

Legal Entity verification fails when:

- no Chainlink CCID resolves for a wallet-based party,
- no `identityRef` is present for an AID-only party,
- no oracle record exists,
- the AID is not allowlisted,
- LEI evidence is missing or mismatched,
- ACDC evidence is missing,
- the record is expired,
- the record is revoked.

## Prototype Limitations

- `AllowAllPolicyEngine` is dev-only and must not be used in production.
- The oracle registry trusts the admin/oracle poster; it does not verify signatures or KERI events on-chain.
- `USDC` direct ERC-20 transfers bypass wrapper compliance except for global pause.
- OOR and role/scope authority checks are not implemented by this verifier.
