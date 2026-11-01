#!/usr/bin/env bash
# Deploy contracts to an explicitly selected local Anvil; never start a network.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RPC=""
OUTPUT=""
while (($#)); do
  case "$1" in
    --rpc-url) RPC="${2:?Missing RPC URL}"; shift 2 ;;
    --output) OUTPUT="${2:?Missing output path}"; shift 2 ;;
    -h|--help) echo 'Usage: PRIVATE_KEY=<local key> scripts/deploy-local.sh --rpc-url http://127.0.0.1:PORT --output deployments/RUN/contracts.json'; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done
: "${PRIVATE_KEY:?PRIVATE_KEY is required}"
case "$RPC" in http://127.0.0.1:*|http://localhost:*) ;; *) echo 'Only loopback Anvil RPC is supported' >&2; exit 2 ;; esac
case "$OUTPUT" in deployments/*.json) ;; *) echo 'Output must be a new deployments/...json path relative to this checkout' >&2; exit 2 ;; esac
case "/$OUTPUT/" in */../*|*/./*|*//* ) echo 'Output path must be canonical' >&2; exit 2 ;; esac
cd "$ROOT"
for tool in forge cast jq; do command -v "$tool" >/dev/null || { echo "Missing executable: $tool" >&2; exit 1; }; done
cast rpc --rpc-url "$RPC" web3_clientVersion | jq -e 'ascii_downcase | contains("anvil")' >/dev/null
[[ ! -e "$OUTPUT" ]] || { echo "Refusing existing output: $OUTPUT" >&2; exit 1; }
parent="$(dirname "$OUTPUT")"
current="$ROOT"
IFS=/ read -r -a parts <<< "$parent"
for part in "${parts[@]}"; do
  current="$current/$part"
  [[ ! -L "$current" ]] || { echo 'Symlink output directories are not supported' >&2; exit 2; }
done
mkdir -p "$parent"
# A partial Forge run can write simulation output. Never publish it as a result.
PARTIAL="${OUTPUT%.json}.partial.json"
trap 'rm -f "$PARTIAL"' EXIT
DEPLOYMENT_OUTPUT="$PARTIAL" forge script script/DeployAll.s.sol --rpc-url "$RPC" --broadcast --non-interactive
CHAIN="$(cast chain-id --rpc-url "$RPC")"
jq -e --argjson chain "$CHAIN" '.version == 1 and .chainId == $chain and (.contracts | length == 10)' "$PARTIAL" >/dev/null
while IFS= read -r address; do
  [[ "$(cast code --rpc-url "$RPC" "$address")" != '0x' ]] || { echo "No deployed code: $address" >&2; exit 1; }
done < <(jq -r '.contracts[]' "$PARTIAL")
MANAGER="$(jq -r '.contracts.policyManager' "$PARTIAL")"
[[ "$(cast call --rpc-url "$RPC" "$MANAGER" 'policyCount()(uint256)')" == '1' ]]
ADMIN="$(jq -r '.contracts.adminControls' "$PARTIAL")"
DEPLOYER="$(jq -r '.deployer' "$PARTIAL")"
ROLE="$(cast call --rpc-url "$RPC" "$ADMIN" 'COMPLIANCE_ADMIN_ROLE()(bytes32)')"
[[ "$(cast call --rpc-url "$RPC" "$ADMIN" 'hasRole(bytes32,address)(bool)' "$ROLE" "$DEPLOYER")" == 'true' ]]
mv "$PARTIAL" "$OUTPUT"
printf 'Deployment artifact: %s/%s\n' "$ROOT" "$OUTPUT"
