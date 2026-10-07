# Security Model

This repository is a production-preparation prototype. It demonstrates the contract boundaries and fail-closed behavior expected in a production USDC compliance integration, but it is not production-ready as deployed.

## Trust Boundaries

| Boundary | Current implementation |
|---|---|
| Wallet access | `AdminControls` allowlist gates wrapper callers. |
| Identity mapping | Chainlink `IdentityRegistry` maps wallet to `aidCcid`. |
| Wallet endorsement | `VLEIOracleRegistry` stores authorized wallet/entity/association bindings. |
| Policy evaluation | `PolicyManager` evaluates all configured policies with fail priority. |
| Direct token transfer | `USDC` only checks global pause. |

## Admin Roles

`AdminControls.COMPLIANCE_ADMIN_ROLE` can:

- manage wallet allowlist,
- add/remove/freeze policy set,
- publish, replace, and withdraw exact wallet associations.

`AdminControls.EMERGENCY_ROLE` can pause and unpause the system.

## Fail-Closed Behavior

The registry accepts only nonzero wallets and identities and a nonempty association
reference. A policy must bind the supplied wallet and entity to the current
endorsement. A mapping alone is insufficient; the current consumer rejects
unbound parties. Withdrawal deletes the result, and late withdrawal cannot clear
a replacement. Time alone does not expire a result. Oracle outages can leave
stale results usable until the oracle can withdraw them.

## Prototype Limitations

- `AllowAllPolicyEngine` is dev-only and must not be used in production.
- The oracle registry trusts the admin/oracle poster; it does not verify signatures or KERI events on-chain.
- `USDC` direct ERC-20 transfers bypass wrapper compliance except for global pause.
- OOR and role/scope authority checks are not implemented by this verifier.
