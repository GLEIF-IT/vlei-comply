# GL1 USDC Local Infrastructure Setup

This sub-guide owns the mechanical startup details for the local GL1/vLEI
stack. The main [CLI Execution Guide](gl1-vlei-cli-execution-guide.md) assumes
this infrastructure is already running and focuses on operating the compliance
workflow.

The local stack uses:

- `kli witness demo` for witness and mailbox infrastructure
- `vLEI-server` for KLI schema OOBIs
- Anvil for the local EVM chain
- `forge script` for `vlei-comply` deployment
- `vlei-oracle server start` after the GEDA and oracle AIDs exist

This setup guide does not assume the GEDA, QVI, Legal Entity, or OOR holder
AIDs already exist when you run `start`. The base startup command only prepares
the reusable infrastructure those AIDs need. The later `oracle` command assumes
the execution guide has created the oracle Hab in `KERI_BASE` and that you know
the trusted `GEDA_AID`.

## Prepare Clean Checkouts

The oracle repository owns the pinned demo dependency manifest and preparer.
Start in any empty working directory; no existing KERIpy, schema-tool, or
contract checkout is required:

```sh
gh repo clone GLEIF-IT/vlei-oracle
cd vlei-oracle
python3.12 scripts/dev/prepare-demo.py
source .demo/demo.env
cd "$COMPLY_DIR"
scripts/dev/start-local-gl1-stack.sh check
```

Use Python 3.12.6 or newer and authenticate GitHub CLI with `gh auth login`
using an account with access to the GLEIF repositories. Install Foundry (`forge`,
`cast`, `anvil`), `git`, `gh`, `jq`, `curl`, and `nc` on `PATH`. The preparer
clones exact upstream commits into
an isolated dependency directory, installs the oracle and pinned Python packages,
and exports `ORACLE_DIR`, `COMPLY_DIR`, `KERIPY_DIR`, `VLEI_SCHEMA_TOOLS_DIR`, and
explicit Python tool paths. It starts no services or deployments.

The selected commits are owned by the oracle's
[`demo-dependencies.json`](https://github.com/GLEIF-IT/vlei-oracle/blob/main/scripts/dev/demo-dependencies.json).
A different origin, dirty checkout, or revision mismatch fails without a reset.
Choose a new preparer `--directory` for another checkout set. The scripts can
also accept explicit dependency/tool exports, but never search for neighbors.
Keep the generated `demo.env` path available in each terminal, or source the
resulting `stack.env` after startup; it retains the dependency selections.

## Recommended Startup

From `vlei-comply`:

```sh
scripts/dev/start-local-gl1-stack.sh start
source runs/local-gl1-stack/stack.env
scripts/dev/start-local-gl1-stack.sh status
```

The script starts or reuses the services it can safely identify, deploys the
contracts, parses the deployment log with `vlei-oracle parse-deploy-log`, and
writes `runs/local-gl1-stack/stack.env`.

It does not create KERI AIDs, issue credentials, or run the transfer scenario.
That is intentional. The fixture init script owns the repeatable
GEDA-to-QVI-to-LE-to-OOR setup:

```sh
scripts/dev/init-local-vlei-fixture.sh --through oracle-posted
source runs/latest-fixture.env
```

Use `--through source-chain` when you want to stop before wallet attestation
Grants and practice the vLEI Oracle presentation step manually. Use the default
`--through oracle-posted` when you want to focus on GL1, smart contract admin
controls, CCID registry state, minting, and transfer behavior.

## Required Tools

Source the generated `demo.env` to select `kli`, `vLEI-server`, and
`vlei-oracle`. Foundry tools, `jq`, `curl`, and `nc` are resolved from `PATH`.
Run `scripts/dev/start-local-gl1-stack.sh check` before starting services.

Override tool paths when needed:

```sh
KLI=/path/to/kli \
VLEI_SERVER=/path/to/vLEI-server \
VLEI_ORACLE=/path/to/vlei-oracle \
FORGE=/path/to/forge \
ANVIL=/path/to/anvil \
scripts/dev/start-local-gl1-stack.sh start
```

## Default Ports And Artifacts

| Component | Default | Notes |
|-----------|---------|-------|
| Witness HTTP | `5642`, `5643`, `5644` | `kli witness demo` witnesses `wan`, `wil`, `wes` |
| Witness TCP | `5632`, `5633`, `5634` | Must match witness curls config |
| vLEI schema server | `7723` | Serves upstream vLEI schemas plus GL1 wallet schema |
| Anvil | `8545` | Chain ID defaults to `31337` |
| vLEI Oracle | `9723` | Started after `GEDA_AID` and oracle Hab exist |

Generated files are written under:

```text
runs/local-gl1-stack/
  anvil.log
  contracts.json
  deploy-all.log
  kli-witness-demo.log
  stack.env
  vlei-server.log
  vlei-oracle.log
```

Fixture runs are written under `runs/local-gl1-fixture-*` by default, and
`runs/latest-fixture.env` points at the latest stack and actor exports.

The generated `stack.env` exports:

```sh
RUN_ID
RUN_DIR
RPC_URL
CHAIN_ID
ADMIN_PK
ORACLE_URL
CONTRACTS_JSON
ADMIN_CONTROLS
IDENTITY_REGISTRY
CREDENTIAL_REGISTRY
ORACLE_REGISTRY
USDC_TOKEN
WRAPPER
```

## Start The Oracle Service

The oracle service needs a local KERI Habery, an oracle Hab, and the trusted
GEDA AID. It does not require the LE/OOR holder AIDs to be pre-created before
the base infrastructure starts, but those AIDs and their credentials must exist
before wallet attestations can be Granted to the oracle. Start the oracle after
the execution guide has created the oracle Hab and GEDA AID:

```sh
source runs/local-gl1-stack/stack.env

export KERI_BASE=local-gl1-human
export GEDA_AID="<geda AID>"

scripts/dev/start-local-gl1-stack.sh oracle
curl -fsS "$ORACLE_URL/health" | jq .
```

The script calls:

```sh
vlei-oracle server start \
  --name oracle \
  --base "$KERI_BASE" \
  --alias oracle \
  --http-port "$ORACLE_HTTP_PORT" \
  --trusted-geda-aid "$GEDA_AID" \
  --contracts "$CONTRACTS_JSON" \
  --rpc-url "$RPC_URL" \
  --private-key "$ADMIN_PK"
```

The oracle pins the GL1 wallet schema internally. The schema server still runs
because KLI issuers need schema OOBIs for credential creation.

## Manual Multi-Terminal Startup

Use this when you want to see each service boundary directly. Source the
generated `demo.env` in every terminal before these commands.

Terminal 1, witnesses:

```sh
cd "$KERIPY_DIR"
"$KLI" witness demo
```

Terminal 2, schema server:

```sh
cd "$COMPLY_DIR"
mkdir -p runs/manual/schema/acdc
cp -R "$VLEI_SCHEMA_TOOLS_DIR/schema/acdc/." runs/manual/schema/acdc/
cp "$ORACLE_DIR/schemas/acdc/gl1-ethereum-wallet-attestation.json" runs/manual/schema/acdc/

"$VLEI_SERVER" \
  -p 7723 \
  -s runs/manual/schema/acdc \
  -c "$VLEI_SCHEMA_TOOLS_DIR/samples/acdc" \
  -o "$VLEI_SCHEMA_TOOLS_DIR/samples/oobis"
```

Terminal 3, Anvil:

```sh
anvil --host 127.0.0.1 --port 8545 --chain-id 31337
```

Terminal 4, deploy contracts:

```sh
cd "$COMPLY_DIR"
export RPC_URL=http://127.0.0.1:8545
export ADMIN_PK=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

PRIVATE_KEY="$ADMIN_PK" forge script script/DeployAll.s.sol \
  --rpc-url "$RPC_URL" \
  --broadcast \
  --slow \
  -vvvv | tee runs/manual/deploy-all.log

"$VLEI_ORACLE" parse-deploy-log \
  --log runs/manual/deploy-all.log \
  --out runs/manual/contracts.json
```

Terminal 5, oracle service, after the oracle Hab and GEDA AID exist:

```sh
"$VLEI_ORACLE" server start \
  --name oracle \
  --base "$KERI_BASE" \
  --alias oracle \
  --http-port 9723 \
  --trusted-geda-aid "$GEDA_AID" \
  --contracts runs/manual/contracts.json \
  --rpc-url http://127.0.0.1:8545 \
  --private-key "$ADMIN_PK"
```

## Witness Config And Reset

The demo witness config must include both TCP and HTTP curls for each witness:

```text
wan -> tcp://127.0.0.1:5632/ and http://127.0.0.1:5642/
wil -> tcp://127.0.0.1:5633/ and http://127.0.0.1:5643/
wes -> tcp://127.0.0.1:5634/ and http://127.0.0.1:5644/
```

KERI witnesses read their config once at initial bootstrap. If the witness was
initialized with bad curls, changing the config file is not enough. Stop the
witnesses and clear their stores before restarting:

```sh
for name in wan wil wes wit wub wyz; do
  rm -rf \
    "$HOME/.keri/ks/$name" \
    "$HOME/.keri/db/$name" \
    "$HOME/.keri/reg/$name" \
    "$HOME/.keri/mbx/$name"
done
```

The startup script performs this reset by default only when no demo witness
ports are active. Set `RESET_DEMO_WITNESSES=0` to disable that behavior.

## Cleanup

Stop processes started by the script:

```sh
scripts/dev/start-local-gl1-stack.sh stop
```

Force a fresh deployment while reusing the same run directory:

```sh
REDEPLOY=1 scripts/dev/start-local-gl1-stack.sh start
```

Start a separate run directory:

```sh
RUN_ID=local-gl1-stack-2 scripts/dev/start-local-gl1-stack.sh start
source runs/local-gl1-stack-2/stack.env
```

## Troubleshooting

If the witness OOBI does not resolve, check that the service on ports
`5642-5644` is really `kli witness demo`, not a stale container or unrelated
process.

If `vLEI-server` is reachable but wallet schema OOBI lookup fails, confirm that
the GL1 wallet schema was copied into the schema directory used with `-s`.

If Forge deploy hangs on local Anvil, keep `--slow`. Sequential broadcasting is
more reliable for this local flow.

If `vlei-oracle server start` fails, confirm that `KERI_BASE` points to the
database containing the oracle Hab and that `GEDA_AID` is the AID that issued
or anchors the trusted source chain.
