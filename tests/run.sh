#!/usr/bin/env bash
# Canonical test manifest for local runs and CI.
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"

for dependency in bash jq python3 cc; do
  if ! command -v "$dependency" >/dev/null 2>&1; then
    printf 'Missing test dependency: %s\n' "$dependency" >&2
    exit 2
  fi
done

tests=(
  tests/test-common-preflight.sh
  tests/test-installer-entry.sh
  tests/test-inventory.sh
  tests/test-storage-discovery.sh
  tests/test-storage-plan.sh
  tests/test-storage-prerequisites.sh
  tests/test-storage-confirmation.sh
  tests/test-storage-execution-dry-run.sh
  tests/test-storage-execution-boundary.sh
  tests/test-storage-topology.sh
  tests/test-preflight-gate.sh
  tests/test-native-storage-handle.sh
)

for test in "${tests[@]}"; do
  if [[ ! -f "$test" ]]; then
    printf 'Required test is missing: %s\n' "$test" >&2
    exit 1
  fi
done

for test in "${tests[@]}"; do
  printf '\n== %s ==\n' "$test"
  bash "$test"
done

printf '\nAll %d repository test scripts passed.\n' "${#tests[@]}"
