#!/usr/bin/env bash
set -Eeuo pipefail

# Start the local infrastructure used by the human GL1/vLEI CLI guide.
#
# This is intentionally not an e2e runner. It starts the long-lived services
# and deploys contracts, then leaves KERI identity creation, credential
# presentation and transfer checks to the operator.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Dependencies are selected by the clean-checkout setup or explicit exports.
# No parent-directory search is allowed to select another repository.
if [[ -n "${DEMO_ENV:-}" ]]; then
  # shellcheck disable=SC1090
  source "$DEMO_ENV"
fi
COMPLY_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ORACLE_DIR="${ORACLE_DIR:-}"
KERIPY_DIR="${KERIPY_DIR:-}"
VLEI_SCHEMA_TOOLS_DIR="${VLEI_SCHEMA_TOOLS_DIR:-}"

KLI="${KLI:-kli}"
VLEI_ORACLE="${VLEI_ORACLE:-vlei-oracle}"
VLEI_SERVER="${VLEI_SERVER:-vLEI-server}"
FORGE="${FORGE:-forge}"
CAST="${CAST:-cast}"
ANVIL="${ANVIL:-anvil}"
JQ="${JQ:-jq}"

RUN_ID="${RUN_ID:-local-gl1-stack}"
RUN_DIR="${RUN_DIR:-${COMPLY_DIR}/runs/${RUN_ID}}"
SCHEMA_DIR="${RUN_DIR}/schema/acdc"
STACK_ENV="${STACK_ENV:-${RUN_DIR}/stack.env}"
DEPLOY_LOG="${DEPLOY_LOG:-${RUN_DIR}/deploy-all.log}"
CONTRACTS_JSON="${CONTRACTS_JSON:-${RUN_DIR}/contracts.json}"

RPC_URL="${RPC_URL:-http://127.0.0.1:8545}"
CHAIN_ID="${CHAIN_ID:-31337}"
ANVIL_PORT="${ANVIL_PORT:-8545}"
VLEI_SCHEMA_PORT="${VLEI_SCHEMA_PORT:-7723}"
ORACLE_HTTP_PORT="${ORACLE_HTTP_PORT:-9723}"
ORACLE_URL="${ORACLE_URL:-http://127.0.0.1:${ORACLE_HTTP_PORT}}"
ADMIN_PK="${ADMIN_PK:-0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80}"

WALLET_SCHEMA=""  # Read from the selected oracle schema during preflight.

log() {
  printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"
}

usage() {
  cat <<'USAGE'
Usage:
  scripts/dev/start-local-gl1-stack.sh check
  scripts/dev/start-local-gl1-stack.sh start
  scripts/dev/start-local-gl1-stack.sh oracle
  scripts/dev/start-local-gl1-stack.sh status
  scripts/dev/start-local-gl1-stack.sh stop
  scripts/dev/start-local-gl1-stack.sh env

Commands:
  check   Validate dependency paths/tools without starting services or deploying.
  start   Start/reuse witness demo, vLEI-server, Anvil, and deploy contracts.
  oracle  Start/reuse vlei-oracle after the oracle Hab and GEDA_AID exist.
  status  Show whether the expected local ports are listening.
  stop    Stop processes previously started by this script.
  env     Print the generated environment file path.

Dependency inputs (source the generated demo.env first):
  DEMO_ENV, ORACLE_DIR, KERIPY_DIR, VLEI_SCHEMA_TOOLS_DIR

Useful environment variables:
  RUN_ID, RUN_DIR, RPC_URL, CHAIN_ID, ADMIN_PK, KLI, VLEI_ORACLE, VLEI_SERVER,
  FORGE, CAST, ANVIL, JQ, RESET_DEMO_WITNESSES, REDEPLOY, START_ORACLE,
  KERI_BASE, GEDA_AID, ORACLE_NAME, ORACLE_ALIAS
USAGE
}

need() {
  if [[ ! -x "$1" ]] && ! command -v "$1" >/dev/null 2>&1; then
    printf 'Missing required executable: %s\n' "$1" >&2
    exit 1
  fi
}

check_dependencies() {
  : "${ORACLE_DIR:?Source the clean-checkout demo.env to set ORACLE_DIR}"
  : "${KERIPY_DIR:?Source the clean-checkout demo.env to set KERIPY_DIR}"
  : "${VLEI_SCHEMA_TOOLS_DIR:?Source the clean-checkout demo.env to set VLEI_SCHEMA_TOOLS_DIR}"
  for file in \
    "$ORACLE_DIR/schemas/acdc/gl1-ethereum-wallet-attestation.json" \
    "$KERIPY_DIR/scripts/demo/data/rules.json" \
    "$VLEI_SCHEMA_TOOLS_DIR/samples/acdc/qualified-vLEI-issuer-vLEI-credential.json"; do
    if [[ ! -f "$file" ]]; then
      printf 'Missing checkout asset: %s\n' "$file" >&2
      exit 1
    fi
  done
  for tool in "$KLI" "$VLEI_SERVER" "$VLEI_ORACLE" "$FORGE" "$CAST" "$ANVIL" "$JQ" curl nc; do
    need "$tool"
  done
  WALLET_SCHEMA="$("$JQ" -er '.["$id"]' "$ORACLE_DIR/schemas/acdc/gl1-ethereum-wallet-attestation.json")"
}

port_listening() {
  nc -z 127.0.0.1 "$1" >/dev/null 2>&1
}

wait_for_port() {
  local port="$1"
  local label="$2"
  for _ in $(seq 1 80); do
    if port_listening "$port"; then
      return
    fi
    sleep 0.25
  done
  printf 'Timed out waiting for %s on port %s\n' "$label" "$port" >&2
  exit 1
}

pid_file_for() {
  printf '%s/%s.pid\n' "$RUN_DIR" "$1"
}

start_detached() {
  local port="$1"
  local label="$2"
  local pid_key="$3"
  local log_file="$4"
  shift 4

  if port_listening "$port"; then
    log "${label} already listening on ${port}; reusing it"
    return
  fi

  log "Starting ${label}"
  mkdir -p "$RUN_DIR"
  nohup "$@" >"$log_file" 2>&1 &
  echo "$!" >"$(pid_file_for "$pid_key")"
  wait_for_port "$port" "$label"
}

require_http() {
  local url="$1"
  local label="$2"
  for _ in $(seq 1 40); do
    if curl -fsS "$url" >/dev/null 2>&1; then
      return
    fi
    sleep 0.25
  done
  printf '%s is not serving the expected endpoint: %s\n' "$label" "$url" >&2
  exit 1
}

require_demo_witness_config() {
  local alias="$1"
  local tcp_url="$2"
  local http_url="$3"
  local config="${KERIPY_DIR}/scripts/keri/cf/main/${alias}.json"

  if [[ ! -f "$config" ]]; then
    printf 'Missing demo witness config: %s\n' "$config" >&2
    exit 1
  fi

  if ! "$JQ" -e --arg alias "$alias" --arg tcp "$tcp_url" --arg http "$http_url" \
    '.[$alias].curls | index($tcp) and index($http)' "$config" >/dev/null; then
    printf 'Demo witness config %s does not contain required curls %s and %s\n' \
      "$config" "$tcp_url" "$http_url" >&2
    printf 'Fix the curls config, then clear witness stores or rerun with RESET_DEMO_WITNESSES=1.\n' >&2
    exit 1
  fi
}

reset_demo_witness_state() {
  if [[ "${RESET_DEMO_WITNESSES:-1}" != "1" ]]; then
    return
  fi

  for port in 5632 5633 5634 5635 5636 5637 5642 5643 5644 5645 5646 5647; do
    if port_listening "$port"; then
      log "Demo witness port ${port} is active; leaving witness stores intact"
      return
    fi
  done

  log "Clearing persisted demo witness stores so curls config is reapplied"
  for name in wan wil wes wit wub wyz; do
    rm -rf \
      "${HOME}/.keri/ks/${name}" \
      "${HOME}/.keri/db/${name}" \
      "${HOME}/.keri/reg/${name}" \
      "${HOME}/.keri/mbx/${name}"
  done
}

prepare_schema_dir() {
  mkdir -p "$SCHEMA_DIR"
  cp -R "${VLEI_SCHEMA_TOOLS_DIR}/schema/acdc/." "$SCHEMA_DIR/"
  cp "${ORACLE_DIR}/schemas/acdc/gl1-ethereum-wallet-attestation.json" "$SCHEMA_DIR/"
}

contracts_have_code() {
  if [[ ! -f "$CONTRACTS_JSON" ]]; then
    return 1
  fi

  local wrapper
  wrapper="$("$JQ" -r '.wrapper // empty' "$CONTRACTS_JSON")"
  if [[ -z "$wrapper" || "$wrapper" == "null" ]]; then
    return 1
  fi

  local code
  code="$("$CAST" code --rpc-url "$RPC_URL" "$wrapper" 2>/dev/null || true)"
  [[ -n "$code" && "$code" != "0x" ]]
}

write_stack_env() {
  local admin_controls identity_registry credential_registry oracle_registry usdc_token wrapper name
  admin_controls="$("$JQ" -r .adminControls "$CONTRACTS_JSON")"
  identity_registry="$("$JQ" -r .identityRegistry "$CONTRACTS_JSON")"
  credential_registry="$("$JQ" -r .credentialRegistry "$CONTRACTS_JSON")"
  oracle_registry="$("$JQ" -r .oracleRegistry "$CONTRACTS_JSON")"
  usdc_token="$("$JQ" -r .usdcToken "$CONTRACTS_JSON")"
  wrapper="$("$JQ" -r .wrapper "$CONTRACTS_JSON")"

  {
    printf '# Generated by scripts/dev/start-local-gl1-stack.sh.\n'
    for name in ORACLE_DIR COMPLY_DIR KERIPY_DIR VLEI_SCHEMA_TOOLS_DIR KLI VLEI_SERVER VLEI_ORACLE \
      RUN_ID RUN_DIR RPC_URL CHAIN_ID ADMIN_PK VLEI_SCHEMA_PORT ORACLE_HTTP_PORT ORACLE_URL CONTRACTS_JSON; do
      printf 'export %s=%q\n' "$name" "${!name}"
    done
    printf 'export ADMIN_CONTROLS=%q\n' "$admin_controls"
    printf 'export IDENTITY_REGISTRY=%q\n' "$identity_registry"
    printf 'export CREDENTIAL_REGISTRY=%q\n' "$credential_registry"
    printf 'export ORACLE_REGISTRY=%q\n' "$oracle_registry"
    printf 'export USDC_TOKEN=%q\n' "$usdc_token"
    printf 'export WRAPPER=%q\n' "$wrapper"
  } >"$STACK_ENV"
}

deploy_contracts() {
  if [[ "${REDEPLOY:-0}" != "1" ]] && contracts_have_code; then
    log "Contracts already parsed at ${CONTRACTS_JSON}; set REDEPLOY=1 to redeploy"
    write_stack_env
    return
  fi

  if [[ -f "$CONTRACTS_JSON" && "${REDEPLOY:-0}" != "1" ]]; then
    log "Ignoring stale contract addresses because no wrapper code exists on ${RPC_URL}"
  fi

  log "Deploying vlei-comply contracts to ${RPC_URL}"
  (
    cd "$COMPLY_DIR"
    PRIVATE_KEY="$ADMIN_PK" "$FORGE" script script/DeployAll.s.sol --rpc-url "$RPC_URL" --broadcast --slow -vvvv
  ) >"$DEPLOY_LOG" 2>&1

  "$VLEI_ORACLE" parse-deploy-log --log "$DEPLOY_LOG" --out "$CONTRACTS_JSON"
  write_stack_env
}

start_base() {
  check_dependencies

  mkdir -p "$RUN_DIR"
  prepare_schema_dir
  require_demo_witness_config wan "tcp://127.0.0.1:5632/" "http://127.0.0.1:5642/"
  require_demo_witness_config wil "tcp://127.0.0.1:5633/" "http://127.0.0.1:5643/"
  require_demo_witness_config wes "tcp://127.0.0.1:5634/" "http://127.0.0.1:5644/"
  reset_demo_witness_state

  start_detached 5642 "kli witness demo" witness "$RUN_DIR/kli-witness-demo.log" \
    bash -c 'cd "$1" && exec "$2" witness demo' _ "$KERIPY_DIR" "$KLI"
  require_http "http://127.0.0.1:5642/oobi/BBilc4-L3tFUnfM_wJr4S4OJanAv_VmF_dJNN6vkf2Ha/controller" \
    "kli witness demo"

  start_detached "$VLEI_SCHEMA_PORT" "vLEI schema server" vlei-server "$RUN_DIR/vlei-server.log" \
    "$VLEI_SERVER" -p "$VLEI_SCHEMA_PORT" \
      -s "$SCHEMA_DIR" \
      -c "${VLEI_SCHEMA_TOOLS_DIR}/samples/acdc" \
      -o "${VLEI_SCHEMA_TOOLS_DIR}/samples/oobis"
  require_http "http://127.0.0.1:${VLEI_SCHEMA_PORT}/oobi/${WALLET_SCHEMA}" "vLEI schema server"

  start_detached "$ANVIL_PORT" "Anvil" anvil "$RUN_DIR/anvil.log" \
    "$ANVIL" --host 127.0.0.1 --port "$ANVIL_PORT" --chain-id "$CHAIN_ID"

  deploy_contracts
  log "Wrote stack environment: ${STACK_ENV}"

  if [[ "${START_ORACLE:-0}" == "1" ]]; then
    start_oracle
  else
    log "Oracle not started yet. After creating the oracle Hab and GEDA AID, run:"
    log "  source '${STACK_ENV}'"
    log "  KERI_BASE=<base> GEDA_AID=<aid> scripts/dev/start-local-gl1-stack.sh oracle"
  fi
}

start_oracle() {
  if [[ -f "$STACK_ENV" ]]; then
    # shellcheck disable=SC1090
    source "$STACK_ENV"
  fi
  : "${KERI_BASE:?KERI_BASE is required to start vlei-oracle}"
  : "${GEDA_AID:?GEDA_AID is required to start vlei-oracle}"
  : "${CONTRACTS_JSON:?CONTRACTS_JSON is required to start vlei-oracle}"

  need "$VLEI_ORACLE"
  start_detached "$ORACLE_HTTP_PORT" "vLEI Oracle service" vlei-oracle "$RUN_DIR/vlei-oracle.log" \
    "$VLEI_ORACLE" server start \
      --name "${ORACLE_NAME:-oracle}" \
      --base "$KERI_BASE" \
      --alias "${ORACLE_ALIAS:-oracle}" \
      --http-port "$ORACLE_HTTP_PORT" \
      --trusted-geda-aid "$GEDA_AID" \
      --contracts "$CONTRACTS_JSON" \
      --rpc-url "$RPC_URL" \
      --private-key "$ADMIN_PK"
  require_http "${ORACLE_URL}/health" "vLEI Oracle service"
  log "vLEI Oracle service is listening at ${ORACLE_URL}"
}

show_status() {
  local row
  for row in \
    "5642:kli witness demo" \
    "${VLEI_SCHEMA_PORT}:vLEI schema server" \
    "${ANVIL_PORT}:Anvil" \
    "${ORACLE_HTTP_PORT}:vLEI Oracle"; do
    local port="${row%%:*}"
    local label="${row#*:}"
    if port_listening "$port"; then
      printf 'up   %s (%s)\n' "$label" "$port"
    else
      printf 'down %s (%s)\n' "$label" "$port"
    fi
  done
}

stop_started() {
  if [[ ! -d "$RUN_DIR" ]]; then
    log "No run directory found: ${RUN_DIR}"
    return
  fi
  for pid_file in "$RUN_DIR"/*.pid; do
    [[ -f "$pid_file" ]] || continue
    pid="$(cat "$pid_file")"
    if kill -0 "$pid" >/dev/null 2>&1; then
      log "Stopping PID ${pid} from ${pid_file}"
      kill "$pid" >/dev/null 2>&1 || true
    fi
    rm -f "$pid_file"
  done
}

command="${1:-start}"
case "$command" in
  check) check_dependencies; log "Dependency inputs are ready" ;;
  start) start_base ;;
  oracle) start_oracle ;;
  status) show_status ;;
  stop) stop_started ;;
  env) printf '%s\n' "$STACK_ENV" ;;
  -h|--help|help) usage ;;
  *)
    usage >&2
    exit 2
    ;;
esac
