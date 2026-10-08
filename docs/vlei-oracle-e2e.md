# Oracle and contract integration

The oracle verifies a finished untargeted association credential and its
GLEIF-rooted source chain, then checks its embedded EOA signature and account
code. The contract consumes only the resulting wallet/entity/association
endorsement. Issuance is owned by the Legal Entity controller, while verification
and posting are separate oracle responsibilities.

The current oracle issuance exercise is documented in its `scripts/protocol`
directory. It verifies real credentials through IPEX/HTTP and uses local Anvil
for account-code observations. With `--comply-dir`, the same workflow deploys
fresh contracts and proves real endorsements, an allowed wrapper transfer,
revocation withdrawal, and a rejected transfer using token balances.
The contract suite separately tests exact-wallet endorsement consumption,
withdrawal, replacement, unauthorized writers, stale identity hints, and
zero-wallet customer rejection.

Use the [registry reference](oracle-registry.md) for the ABI and the
[local command guide](gl1-vlei-cli-execution-guide.md) for contract commands.
The old signature-attachment/AID-record fixture cannot be used with these
contracts. The oracle dependency preparer pins the contract revision for the complete
acceptance exercise. Run `scripts/dev/init-local-vlei-fixture.sh` after loading
its generated environment; add `--two-chain-check --process-check --kli-check`
for the full local qualification. Existing operator stores remain untouched.
