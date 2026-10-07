# Security Model

This repository is a production-preparation prototype. It demonstrates the contract boundaries and fail-closed behavior expected in a production USDC compliance integration, but it is not production-ready as deployed.

## Trust Boundaries

| Boundary | Current implementation |
|---|---|
| Wallet eligibility | Current exact-wallet endorsements and configured policies gate transfers. |
| Identity mapping | Chainlink `IdentityRegistry` maps wallet to `aidCcid`. |
| Wallet endorsement | `VLEIOracleRegistry` stores authorized wallet/entity/association bindings. |
| Policy evaluation | `PolicyManager` evaluates all configured policies with fail priority. |
| Direct token transfer | `USDC` only checks global pause. |

## Admin Roles

`AdminControls.COMPLIANCE_ADMIN_ROLE` can:

- add/remove/freeze policy set,
- publish, replace, and withdraw exact wallet associations.

`AdminControls.EMERGENCY_ROLE` can pause and unpause the system.

## Spending authority

There is no global wallet whitelist. Transfer eligibility is decided by current
endorsements and policy. The token owner approves the wrapper and initiates the
transfer. Both `transferFrom` wrapper entry points require `msg.sender == from`:
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
- `USDC` direct ERC-20 transfers bypass wrapper compliance except for global pause.
- OOR and role/scope authority checks are not implemented by this verifier.
