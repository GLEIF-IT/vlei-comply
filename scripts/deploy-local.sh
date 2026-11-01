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
  local deployment_path="$1"
  case "$deployment_path" in deployments/*.json) ;; *) fail 'Output must be deployments/...json relative to this checkout' ;; esac
  case "/$deployment_path/" in */../*|*/./*|*//* ) fail 'Output path must be canonical' ;; esac
  [[ ! -e "$deployment_path" && ! -L "$deployment_path" ]] || fail "Output already exists: $deployment_path"
  local directory="$(dirname "$deployment_path")"
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
  local rpc_url="$1" artifact_path="$2"
  local chain_id address policy_manager_address admin_controls_address deployer_address admin_role
  chain_id="$(cast chain-id --rpc-url "$rpc_url")"
  jq -e --argjson chain_id "$chain_id" \
    '.version == 1 and .chainId == $chain_id and (.contracts | length == 10)' "$artifact_path" >/dev/null
  while IFS= read -r address; do
    [[ "$(cast code --rpc-url "$rpc_url" "$address")" != '0x' ]] || fail "No deployed code: $address"
  done < <(jq -r '.contracts[]' "$artifact_path")
  policy_manager_address="$(jq -r '.contracts.policyManager' "$artifact_path")"
  [[ "$(cast call --rpc-url "$rpc_url" "$policy_manager_address" 'policyCount()(uint256)')" == '1' ]] || fail 'Expected one configured policy'
  admin_controls_address="$(jq -r '.contracts.adminControls' "$artifact_path")"
  deployer_address="$(jq -r '.deployer' "$artifact_path")"
  admin_role="$(cast call --rpc-url "$rpc_url" "$admin_controls_address" 'COMPLIANCE_ADMIN_ROLE()(bytes32)')"
  [[ "$(cast call --rpc-url "$rpc_url" "$admin_controls_address" 'hasRole(bytes32,address)(bool)' "$admin_role" "$deployer_address")" == 'true' ]] || fail 'Deployer lacks compliance-admin role'
}

# Use a subshell so the EXIT trap still owns its local temporary path on failure.
deploy() (
  local rpc_url="$1" deployment_path="$2"
  local partial_path
  partial_path="$(mktemp "${deployment_path%.json}.partial.XXXXXX")"
  trap 'rm -f -- "$partial_path"' EXIT
  DEPLOYMENT_OUTPUT="$partial_path" forge script script/DeployAll.s.sol \
    --rpc-url "$rpc_url" --broadcast --non-interactive
  verify_deployment "$rpc_url" "$partial_path"
  # A hard link publishes atomically and refuses a concurrent existing output.
  ln "$partial_path" "$deployment_path"
  printf 'Deployment artifact: %s/%s\n' "$SCRIPT_ROOT" "$deployment_path"
)

main() {
  local rpc_url='' deployment_path='' tool
  while (($#)); do
    case "$1" in
      --rpc-url) rpc_url="${2:?--rpc-url requires a value}"; shift 2 ;;
      --output) deployment_path="${2:?--output requires a value}"; shift 2 ;;
      -h|--help) usage; return ;;
      *) fail "Unknown option: $1" ;;
    esac
  done
  : "${PRIVATE_KEY:?PRIVATE_KEY is required}"
  for tool in forge cast jq; do command -v "$tool" >/dev/null || fail "Missing executable: $tool"; done
  cd "$SCRIPT_ROOT"
  validate_rpc "$rpc_url"
  prepare_output_directory "$deployment_path"
  deploy "$rpc_url" "$deployment_path"
}

main "$@"
