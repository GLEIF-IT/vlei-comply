# Security Model

This repository is a production-preparation prototype. It demonstrates current contract boundaries and configured-policy checks, but it is not production-ready as deployed.

## Trust Boundaries

| Boundary | Current implementation |
|---|---|
| Wallet eligibility | Current exact-wallet endorsements and configured policies gate transfers. |
| Identity mapping | Chainlink `IdentityRegistry` maps wallet to `aidCcid`. |
| Wallet endorsement | `VLEIOracleRegistry` stores authorized wallet/entity/association endorsements. |
| Policy evaluation | `PolicyManager` evaluates all configured policies with fail priority. |
| Direct token transfer | `USDC` only checks global pause. |

## Admin Roles

`AdminControls.COMPLIANCE_ADMIN_ROLE` can:

- add/remove/freeze policies while retaining at least one active policy after configuration,
- publish, replace, and withdraw exact wallet associations.

`AdminControls.EMERGENCY_ROLE` can pause and unpause the system.

## Spending authority

There is no global wallet whitelist. Transfer eligibility is decided by current
endorsements and policy. The token owner approves the wrapper and initiates the
transfer. The `transferFrom` wrapper entry point requires `msg.sender == from`:
approval to the wrapper authorizes its token call, not an arbitrary caller.
Administrator roles still protect registry writes and policy changes, and the
emergency role still controls the shared pause.

## Fail-Closed Behavior

The registry accepts only nonzero wallets and identities and a nonempty association
reference. A policy must bind the supplied wallet and entity to the current
endorsement. A mapping alone is insufficient; `VLEIEndorsementChecker` requires a nonzero
wallet and identity matching the current result. Zero-wallet customer parties fail. Withdrawal deletes the result, and late withdrawal cannot clear
a replacement. Time alone does not expire a result. Oracle outages can leave
stale results usable until the oracle can withdraw them.

## Prototype Limitations

- `AllowAllPolicyEngine` is dev-only and must not be used in production.
- The oracle registry trusts the admin/oracle poster; it does not verify signatures or KERI events on-chain.
- wUSDC is an auditable transfer route; direct USDC transfers are intentionally outside its policy checks.
- OOR and role/scope authority checks are not implemented by this contract policy.

## Supported transfer surface

Only owner-initiated `transfer` and `transferFrom` are supported. Both resolve
current wallet identities and evaluate policy immediately. There is no pending
queue or administrative approval that can execute a previously evaluated transfer.
Policy hashes bind the resolved wallet parties, asset, amount and timestamp.
Failed identity lookups discard supplied hints; unknown policy results fail.

An unconfigured manager returns Fail with no per-policy results and emits the
normal `PoliciesRun` audit event. Both wrapper routes return false and emit
`ComplianceCheckFailed` with a zero policy ID; token balances and allowances
remain unchanged. Freezing an empty set does not enable transfers.

Administrators cannot remove the last active policy. To replace it, add the
successor first, then remove the previous policy. The constructor remains
unconfigured until the first policy is explicitly installed. Local deployment
installs the wallet-association policy and validates that configuration before
publishing its deployment artifact.
