#!/usr/bin/env bash
set -euo pipefail

# Initialize the dependency revisions recorded by this clean checkout.
# Do not install moving upstream heads or create a Git commit during setup.
REPOSITORY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
git -C "$REPOSITORY_DIR" submodule update --init --recursive
printf 'Recorded Solidity dependencies are ready. Run forge build and forge test.\n'
