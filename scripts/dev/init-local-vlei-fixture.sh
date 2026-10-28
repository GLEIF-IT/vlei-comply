#!/usr/bin/env bash
set -Eeuo pipefail

# Run the pinned oracle-owned native two-service/token qualification.
if [[ -n "${DEMO_ENV:-}" ]]; then
  # shellcheck disable=SC1090
  source "$DEMO_ENV"
fi
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  printf 'Usage: scripts/dev/init-local-vlei-fixture.sh [pytest options]\n'
  printf 'Requires ORACLE_DIR and VLEI_ORACLE; uses this comply checkout.\n'
  printf 'Runs two installed CLIs, native witnessed issuance and actual USDC balances.\n'
  exit 0
fi
: "${ORACLE_DIR:?Select the qualified oracle source checkout}"
: "${VLEI_ORACLE:?Select the installed oracle CLI environment}"
COMPLY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ORACLE_EXECUTABLE="$(command -v "$VLEI_ORACLE")"
ORACLE_PYTHON="$(dirname "$ORACLE_EXECUTABLE")/python"
export VLEI_COMPLY_DIR="$COMPLY_DIR"
export PYTHONPATH="$ORACLE_DIR/tests:$ORACLE_DIR/scripts/protocol"
exec "$ORACLE_PYTHON" -m pytest -q "$ORACLE_DIR/tests/test_two_services.py" "$@"
