# Local two-service infrastructure

Use independent test stores and a local Anvil chain. EOA Verifier performs initial
credential/wallet/account verification; vLEI Oracle trusts its authenticated status
and posts the selected mapping. Neither application refreshes accepted evidence.

## Qualify the installed applications

Select the oracle source revision that owns the shared native fixture, then install
both applications in a fresh Python 3.12 environment. From this comply checkout:

```sh
export WORK="$PWD/runs/qualification"
mkdir -p "$WORK"
gh repo clone GLEIF-IT/vlei-oracle "$WORK/oracle"
git -C "$WORK/oracle" checkout --detach 7d82d04cd444cb21e1da1e6ec0408cc40105d4f4
python3.12 -m venv "$WORK/venv"
"$WORK/venv/bin/pip" install "$WORK/oracle" \
  -r "$WORK/oracle/tests/requirements.txt" \
  -r "$WORK/oracle/scripts/protocol/requirements.txt"
export ORACLE_DIR="$WORK/oracle"
export VLEI_ORACLE="$WORK/venv/bin/vlei-oracle"
export EOA_VERIFIER="$WORK/venv/bin/eoa-verifier"
scripts/dev/init-local-vlei-fixture.sh
```

Foundry 1.5.1 (`forge`, `cast`, `anvil`) must be on PATH and this checkout's
submodules initialized. The pinned test requirements select EOA Verifier's merged
artifact. The fixture owns its Anvil, witness, issuer stores and both CLI processes;
it stops them on exit. Add pytest's `--basetemp <fresh-directory>` to retain test
artifacts for inspection. It never shares a running operator's stores. Old
`--keep`, `--process-check` and related legacy exercise flags are not accepted.

The scenario verifies actual source-chain issuance, native IPEX/CESR intake,
signed delivery/lost ACK, two wallet endorsements, token balance changes,
replacement, restart and revocation withdrawal. See [integration](vlei-oracle-e2e.md).
On affected macOS hosts, copy inputs into a Linux container without host bind
mounts; keep LMDB stores in that container.

## Persistent local services

The existing `start-local-gl1-stack.sh start` command starts the witness demo,
schema server and Anvil, deploys contracts, and writes `runs/<run-id>/stack.env`.
It requires explicit `ORACLE_DIR`, `KERIPY_DIR` (witness demo assets),
`VLEI_SCHEMA_TOOLS_DIR`, installed `KLI`/`VLEI_SERVER`, both application executables,
Foundry, `jq`, `curl` and `nc`. It does not infer sibling repository paths. The
oracle dependency preparer can provide asset paths; use the selected application
executables above rather than an older combined-service environment.

```sh
scripts/dev/start-local-gl1-stack.sh check
scripts/dev/start-local-gl1-stack.sh start
source runs/local-gl1-stack/stack.env
```

Provision two native service identities before starting either application. The
following unencrypted single-key setup is for isolated local development:

```sh
export VERIFIER_BASE=local-gl1-stack-verifier
export ORACLE_BASE=local-gl1-stack-oracle
"$KLI" init --name verifier --base "$VERIFIER_BASE" --nopasscode
"$KLI" incept --name verifier --base "$VERIFIER_BASE" --alias verifier \
  --transferable --icount 1 --isith 1 --ncount 1 --nsith 1 --toad 0
"$KLI" init --name oracle --base "$ORACLE_BASE" --nopasscode
"$KLI" incept --name oracle --base "$ORACLE_BASE" --alias oracle \
  --transferable --icount 1 --isith 1 --ncount 1 --nsith 1 --toad 0
```

Set `VERIFIER_AID` and `ORACLE_AID` to the identifiers printed by those commands,
and `GEDA_AID` to the configured initial-verification trust root. Use a separate
funded Ethereum key for `VLEI_ORACLE_POSTING_KEY`; grant its address the deployed
`AdminControls.COMPLIANCE_ADMIN_ROLE` using the deployment administrator. Never
share that writer's nonce stream with setup transactions. The local deployment's
registry policy engine is permissive for demonstration; production governance is
separate work.

```sh
scripts/dev/start-local-gl1-stack.sh services
scripts/dev/start-local-gl1-stack.sh status
```

`services` starts verifier on 9724 and oracle on 9723, exports the verifier's public
KEL to the oracle, then sends the oracle's public KEL to the verifier. Each peer
AID is explicitly configured; fetched keys do not change that trust choice.
Native validation accepts the streams before their keys can authenticate status or
ACKs. The verifier sends to `/v1/status-events`; the oracle gets only its own
posting secret. `verifier` and `oracle` commands can start them separately;
`oracle` also requires `VERIFIER_KEL` naming the public CESR file.

Present the association and its required native evidence to EOA Verifier, not the
oracle. After native association revocation, deliver its TEL and witnessed KEL
anchor through the same native transport. Grant or credential bytes alone do not
establish revocation. GET `/v1/associations/<said>/status` reads stored status only.

Use `start-local-gl1-stack.sh stop` to stop processes recorded by this launcher.
Persistent identities, accepted/revoked status and delivery records remain.
