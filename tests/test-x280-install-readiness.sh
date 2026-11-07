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
  'git rev-parse HEAD' \
  'reports/live-readiness' \
  'summary.md' \
  'diagnostics.log' \
  'trap on_exit EXIT' \
  'serial=)[^[:space:]]+' \
  'Checks passed:' \
  'Process exit code:'; do
  grep -Fq -- "$required" "$SCRIPT" || fail "required readiness/report feature is missing: $required"
done
pass "readiness gate records checkout, environment, test/storage results, and a final report"

grep -Fq 'Review both files before committing' "$SCRIPT" || fail "report review guidance is missing"
grep -Fq 'This report records checks' "$SCRIPT" || fail "report safety interpretation is missing"
pass "report includes review guidance and a clear safety boundary"

if grep -Eq 'wipefs|sgdisk|cryptsetup[[:space:]]+(luksFormat|open)|mkfs\.|pacstrap|mount[[:space:]]' "$SCRIPT"; then
  fail "readiness gate contains a destructive or installation command"
fi
pass "readiness gate contains no disk mutation or installation commands"
printf '%s\n' 'All X280 readiness script tests passed.'
