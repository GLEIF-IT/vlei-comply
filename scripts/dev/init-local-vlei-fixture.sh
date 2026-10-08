#!/usr/bin/env bash
set -Eeuo pipefail

# Run the isolated real association issuance/verification exercise.
if [[ -n "${DEMO_ENV:-}" ]]; then
  # shellcheck disable=SC1090
  source "$DEMO_ENV"
fi
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  printf 'Usage: scripts/dev/init-local-vlei-fixture.sh [--keep] [--two-chain-check --process-check --kli-check]\n'
  printf 'Requires the selected demo.env. Starts its own isolated Anvil and oracle.\n'
  printf 'Qualifies witnessed issuance, verification, posting, transfers, and revocation.\n'
  exit 0
fi
: "${COMPLY_DIR:?Source demo.env to select the pinned contract checkout}"
: "${ORACLE_DIR:?Source demo.env to select the oracle checkout}"
: "${VLEI_SCHEMA_TOOLS_DIR:?Source demo.env to select source schemas}"
: "${VLEI_ORACLE:?Source demo.env to select the oracle environment}"
ORACLE_EXECUTABLE="$(command -v "$VLEI_ORACLE")"
ORACLE_PYTHON="$(dirname "$ORACLE_EXECUTABLE")/python"
exec "$ORACLE_PYTHON" "$ORACLE_DIR/scripts/protocol/exercise_issuance.py" \
  --schema-dir "$VLEI_SCHEMA_TOOLS_DIR/schema/acdc" --comply-dir "$COMPLY_DIR" "$@"
