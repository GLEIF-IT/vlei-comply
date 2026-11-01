# Verifier, Oracle and contract integration

Verifier owns initial evidence/proof/account checks and application acceptance.
Oracle durably receives authenticated status, selects a current association, then
posts or withdraws the exact mapping. Comply consumes current wallet/entity
endorsements for transfers through wUSDC. ACK, selection and confirmed contract
state are separate milestones. Superseding Oracle selection does not revoke
Verifier acceptance.

The single maintained full-system scenario belongs to
[Oracle qualification](https://github.com/GLEIF-IT/vlei-oracle/blob/main/docs/two-service-qualification.md).
It uses two installed CLIs, independent persistent stores/identities, witnessed
GEDA/QVI/LE issuance, signed webhooks, lost-ACK redelivery, restart, replacement
and exact-SAID withdrawal on Anvil. It checks actual sender/beneficiary token
balances before/after allowed and rejected transfers. A policy rejection can
return false in a successful transaction; transaction receipt success alone does not prove token
movement. The separately funded Oracle writer has an explicitly granted role.

Run the full system through the
[Oracle-owned environment](https://github.com/GLEIF-IT/vlei-oracle/tree/main/scripts/integration).
It selects exact compatible revisions and invokes Comply's
[contract deployment command](../scripts/README.md). Comply owns no Python,
witness, schema or application launcher. See the [local setup guide](gl1-vlei-local-infra-setup.md),
[registry contract](oracle-registry.md) and [contract commands](gl1-vlei-cli-execution-guide.md).

Comply CI runs Forge and a local deployment smoke; Oracle CI owns the paired
installed-wheel run against its exact contract pin. There is no second copied
qualification. wUSDC supplies audit records for its routed transfers; direct USDC
transfers remain possible. No pending/manual settlement path, continuing account
monitoring or comprehensive transaction recovery is promised.
