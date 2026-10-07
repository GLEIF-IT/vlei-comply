# Local association infrastructure

Use fresh isolated checkouts and stores. The oracle's dependency manifest owns
the exact schema, KERI demo, and contract revisions. Its preparer selects those
paths explicitly and refuses dirty or mismatched dependency checkouts.

```sh
gh repo clone GLEIF-IT/vlei-oracle
cd vlei-oracle
python3.12 scripts/dev/prepare-demo.py --directory .demo-association
source .demo-association/demo.env
cd "$COMPLY_DIR"
scripts/dev/start-local-gl1-stack.sh check
```

Requires Python 3.12.6+, authenticated GitHub CLI access, Git, Foundry (`forge`,
`cast`, `anvil`), `jq`, `curl`, and `nc`. The environment uses GLEIF KERI/HIO
packages and must not contain upstream distributions owning the same imports.
The preparer starts no services and modifies no operator credentials.

## Isolated issuance exercise

```sh
scripts/dev/init-local-vlei-fixture.sh
# Retain newly created test stores and print KLI inspection commands:
scripts/dev/init-local-vlei-fixture.sh --keep
```

This invokes the oracle's single real issuance implementation. It creates its
own local Anvil and oracle, stops them on exit, and uses temporary KERI stores
unless requested otherwise. It exercises GEDA delegation, QVI/LE/association
issuance, nonce consumption, IPEX/HTTP verification, missing evidence, EOA
classification, and source revocation. The current fixture is witness-free and
uses simulated account code for its contract/EIP-7702 cases. It does not yet
post endorsements or transact through the deployed compliance contracts.

## Persistent local services

For manual KLI work, the starter can run the witness demo, schema OOBI server,
local Anvil, and Forge deployment. Witness keystores use `WITNESS_BASE`
(default: the run ID plus `-witnesses`); choose a fresh base to change configuration.
The starter never deletes existing witness stores:

```sh
scripts/dev/start-local-gl1-stack.sh start
source runs/local-gl1-stack/stack.env
scripts/dev/start-local-gl1-stack.sh status
```

The schema server includes the canonical association schema from the selected
oracle checkout. Create the controller/source chain through supported KLI
workflows and configure its witness/mailbox discovery. The oracle launcher
requires the existing oracle Hab and trusted GEDA AID:

```sh
export KERI_BASE='<fresh KLI base>'
export GEDA_AID='<trusted GEDA AID>'
scripts/dev/start-local-gl1-stack.sh oracle
```

The launcher currently runs verification with `--no-post`, the selected schema
cache, and local RPC. The [registry guide](oracle-registry.md) describes the
separate contract ABI. A complete issuance-to-transfer qualification is still
pending connection of durable posting. There is no global wallet whitelist or
AID-record/signature-attachment workflow.

`runs/<run-id>/stack.env` retains selected dependency and contract paths. Use
`start-local-gl1-stack.sh stop` to stop processes recorded by that starter;
do not delete existing credentials to refresh the prototype. Choose fresh
state instead.
