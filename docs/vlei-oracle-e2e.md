# Verifier, oracle and contract integration

EOA Verifier owns initial KERI/ACDC/source-chain, EIP-712 and account checks.
It retains accepted status until verified association revocation and sends
authenticated events to the configured webhook. The oracle acknowledges durable
event storage with an authenticated response, selects association mappings and
submits ordinary Ethereum transactions. Contracts consume the exact
wallet/entity/association endorsement; they do not verify credentials.

`scripts/dev/init-local-vlei-fixture.sh` invokes the shared oracle-owned scenario
at revision `7d82d04cd444cb21e1da1e6ec0408cc40105d4f4`. It runs two installed CLIs
with independent identities/stores and real witnessed GEDA/QVI/LE issuance. IPEX
delivery of JSON messages with CESR attachments leads to
verification, application acceptance, authenticated delivery and confirmed
endorsements. The oracle selects association mappings under the ownership and
replacement rules before publication. A dropped ACK is retried without repeating
its effects. Both applications reopen stored state without another Grant.

The pinned scenario predates the revised verifier status/ACK vocabulary. Its
qualification evidence covers that pinned pair. The oracle terminology follow-on
will pin the merged producer and contracts and qualify a fresh deployment; do not
pair this older consumer with the revised verifier.

The fixture checks sender and beneficiary USDC balances: a transfer fails before
endorsement, moves tokens with both mappings present, and stops moving tokens
after confirmed association withdrawal. Policy failure can return false inside a
successful transaction receipt; receipt status alone is not the acceptance gate.
A separate funded oracle writer has an explicitly checked compliance-admin role.
Same-LE replacement and delayed old-SAID revocation are exercised before current
revocation clears the mapping. No global wallet admission bypass is used.

The [local setup guide](gl1-vlei-local-infra-setup.md) covers both isolated
qualification and persistent services. The [registry reference](oracle-registry.md)
and [contract commands](gl1-vlei-cli-execution-guide.md) describe the unchanged ABI.
CI runs the Solidity and launcher-argument tests; the real two-service scenario
also runs in oracle's installed-wheel CI against pinned contracts. This comply
increment is locally qualified through the same entry point against its candidate
checkout. Advanced transaction recovery and continuing source/account monitoring
remain outside the build.
