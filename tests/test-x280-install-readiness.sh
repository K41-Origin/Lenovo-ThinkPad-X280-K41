#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
CANONICAL="$ROOT/scripts/k41-live-validation.sh"
READINESS_WRAPPER="$ROOT/scripts/x280-install-readiness.sh"
DIAGNOSTICS_WRAPPER="$ROOT/scripts/live-validation.sh"

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

for script in "$CANONICAL" "$READINESS_WRAPPER" "$DIAGNOSTICS_WRAPPER"; do
  [[ -f $script ]] || fail "required live-validation script is missing: $script"
  bash -n "$script" || fail "Bash syntax error: $script"
done
pass "canonical validator and both compatibility entry points pass bash -n"

for required in \
  '--readiness' \
  '--diagnostics-only' \
  '/etc/arch-release' \
  '/sys/firmware/efi' \
  'ThinkPad X280 DMI identity' \
  'bash tests/run.sh' \
  'bash scripts/validate-live-storage.sh' \
  'reports/live-readiness' \
  'reports/live-validation' \
  'summary.md' \
  'diagnostics.log' \
  'ShellCheck (severity error)' \
  'shfmt formatting check' \
  'installer --help' \
  'installer --preflight' \
  'serial[[:space:]]*=?[[:space:]]*' \
  'Process exit code:'; do
  grep -Fq -- "$required" "$CANONICAL" || fail "required live-validation feature is missing: $required"
done
pass "canonical validator retains readiness, host diagnostics, static analysis, tests, installer diagnostics, and both reports"

grep -Fq 'k41-live-validation.sh" --readiness' "$READINESS_WRAPPER" || fail "readiness compatibility wrapper does not delegate to canonical validator"
grep -Fq 'k41-live-validation.sh" --diagnostics-only' "$DIAGNOSTICS_WRAPPER" || fail "diagnostics compatibility wrapper does not delegate to canonical validator"
pass "legacy entry points delegate without maintaining duplicate implementations"

if grep -Eq 'wipefs|sgdisk|cryptsetup[[:space:]]+(luksFormat|open)|mkfs\.|pacstrap|mount[[:space:]]' "$CANONICAL"; then
  fail "canonical live validator contains disk mutation or installation commands"
fi
pass "canonical live validator contains no disk mutation or installation commands"
printf '%s\n' 'All K41 live-validation tests passed.'
