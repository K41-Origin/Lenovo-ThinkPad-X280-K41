#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
SCRIPT="$ROOT/scripts/x280-install-readiness.sh"
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

[[ -f $SCRIPT ]] || fail "readiness script is missing"
bash -n "$SCRIPT" || fail "readiness script has a Bash syntax error"
pass "readiness script passes bash -n"

for required in \
  '/etc/arch-release' \
  '/sys/firmware/efi' \
  'bash tests/run.sh' \
  'bash scripts/validate-live-storage.sh' \
  'git rev-parse HEAD'; do
  grep -Fq -- "$required" "$SCRIPT" || fail "required readiness check is missing: $required"
done
pass "readiness gate includes Arch, UEFI, commit identity, tests, and live storage validation"

if grep -Eq 'wipefs|sgdisk|cryptsetup[[:space:]]+(luksFormat|open)|mkfs\.|pacstrap|mount[[:space:]]' "$SCRIPT"; then
  fail "readiness gate contains a destructive or installation command"
fi
pass "readiness gate contains no disk mutation or installation commands"
printf '%s\n' 'All X280 readiness script tests passed.'
