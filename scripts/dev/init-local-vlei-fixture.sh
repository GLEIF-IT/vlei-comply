#!/usr/bin/env bash
set -Eeuo pipefail

# Run the isolated real association issuance/verification exercise.
if [[ -n "${DEMO_ENV:-}" ]]; then
  # shellcheck disable=SC1090
  source "$DEMO_ENV"
fi
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  printf 'Usage: scripts/dev/init-local-vlei-fixture.sh [--keep]\n'
  printf 'Requires the selected demo.env. Starts its own isolated Anvil and oracle.\n'
  printf 'The exercise currently qualifies issuance and verification, not transfer.\n'
  exit 0
fi
: "${ORACLE_DIR:?Source demo.env to select the oracle checkout}"
: "${VLEI_SCHEMA_TOOLS_DIR:?Source demo.env to select source schemas}"
: "${VLEI_ORACLE:?Source demo.env to select the oracle environment}"
ORACLE_EXECUTABLE="$(command -v "$VLEI_ORACLE")"
ORACLE_PYTHON="$(dirname "$ORACLE_EXECUTABLE")/python"
exec "$ORACLE_PYTHON" "$ORACLE_DIR/scripts/protocol/exercise_issuance.py" \
  --schema-dir "$VLEI_SCHEMA_TOOLS_DIR/schema/acdc" "$@"
