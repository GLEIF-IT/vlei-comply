#!/usr/bin/env bash
# Deploy the Comply contracts to one explicit local Anvil.
# Requires PRIVATE_KEY in the environment, Foundry 1.5.1 and jq. The command does
# not start a chain or Python service. Only validated post-broadcast JSON is
# published; failed/simulated output is retained in logs, never as a final result.
set -Eeuo pipefail

readonly SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  cat <<'USAGE'
Usage: PRIVATE_KEY=<local key> scripts/deploy-local.sh \
  --rpc-url http://127.0.0.1:PORT --output deployments/RUN/contracts.json

Deploy against an already running local Anvil. Output must be a new path inside
this checkout's deployments directory. Existing files and symlink parents are
refused. The artifact records chain, deployer and addresses, never the private key.
USAGE
}

# Report an input/prerequisite failure without attempting a deployment.
fail() {
  printf 'deploy-local: %s\n' "$*" >&2
  exit 1
}

# Validate the full URL, not a prefix that could hide userinfo or a remote host.
validate_rpc() {
  local rpc_url="$1"
  local loopback_pattern='^http://(127[.]0[.]0[.]1|localhost):[0-9]{1,5}/?$'
  [[ "$rpc_url" =~ $loopback_pattern ]] || fail 'RPC must be an explicit loopback HTTP URL and port'
  local port="${rpc_url##*:}"
  port="${port%/}"
  ((10#$port > 0 && 10#$port < 65536)) || fail 'RPC port is outside 1-65535'
  cast rpc --rpc-url "$rpc_url" web3_clientVersion |
    jq -e 'ascii_downcase | contains("anvil")' >/dev/null || fail 'RPC is not a local Anvil'
}

# Keep every output component under our permitted directory; never follow links.
prepare_output_directory() {
  local output="$1"
  case "$output" in deployments/*.json) ;; *) fail 'Output must be deployments/...json relative to this checkout' ;; esac
  case "/$output/" in */../*|*/./*|*//* ) fail 'Output path must be canonical' ;; esac
  [[ ! -e "$output" && ! -L "$output" ]] || fail "Output already exists: $output"
  local directory="$(dirname "$output")"
  local component current="$SCRIPT_ROOT"
  local components=()
  IFS=/ read -r -a components <<< "$directory"
  for component in "${components[@]}"; do
    current="$current/$component"
    [[ ! -L "$current" ]] || fail 'Symlink output directories are unsupported'
  done
  mkdir -p "$directory"
}

# Check actual chain state after broadcast, including the intentionally active policy.
verify_deployment() {
  local rpc_url="$1" artifact="$2"
  local chain address manager admin deployer role
  chain="$(cast chain-id --rpc-url "$rpc_url")"
  jq -e --argjson chain "$chain" \
    '.version == 1 and .chainId == $chain and (.contracts | length == 10)' "$artifact" >/dev/null
  while IFS= read -r address; do
    [[ "$(cast code --rpc-url "$rpc_url" "$address")" != '0x' ]] || fail "No deployed code: $address"
  done < <(jq -r '.contracts[]' "$artifact")
  manager="$(jq -r '.contracts.policyManager' "$artifact")"
  [[ "$(cast call --rpc-url "$rpc_url" "$manager" 'policyCount()(uint256)')" == '1' ]] || fail 'Expected one configured policy'
  admin="$(jq -r '.contracts.adminControls' "$artifact")"
  deployer="$(jq -r '.deployer' "$artifact")"
  role="$(cast call --rpc-url "$rpc_url" "$admin" 'COMPLIANCE_ADMIN_ROLE()(bytes32)')"
  [[ "$(cast call --rpc-url "$rpc_url" "$admin" 'hasRole(bytes32,address)(bool)' "$role" "$deployer")" == 'true' ]] || fail 'Deployer lacks compliance-admin role'
}

# Use a subshell so the EXIT trap still owns its local temporary path on failure.
deploy() (
  local rpc_url="$1" output="$2"
  local partial_output
  partial_output="$(mktemp "${output%.json}.partial.XXXXXX")"
  trap 'rm -f -- "$partial_output"' EXIT
  DEPLOYMENT_OUTPUT="$partial_output" forge script script/DeployAll.s.sol \
    --rpc-url "$rpc_url" --broadcast --non-interactive
  verify_deployment "$rpc_url" "$partial_output"
  # A hard link publishes atomically and refuses a concurrent existing output.
  ln "$partial_output" "$output"
  printf 'Deployment artifact: %s/%s\n' "$SCRIPT_ROOT" "$output"
)

main() {
  local rpc_url='' output='' tool
  while (($#)); do
    case "$1" in
      --rpc-url) rpc_url="${2:?--rpc-url requires a value}"; shift 2 ;;
      --output) output="${2:?--output requires a value}"; shift 2 ;;
      -h|--help) usage; return ;;
      *) fail "Unknown option: $1" ;;
    esac
  done
  : "${PRIVATE_KEY:?PRIVATE_KEY is required}"
  for tool in forge cast jq; do command -v "$tool" >/dev/null || fail "Missing executable: $tool"; done
  cd "$SCRIPT_ROOT"
  validate_rpc "$rpc_url"
  prepare_output_directory "$output"
  deploy "$rpc_url" "$output"
}

main "$@"
