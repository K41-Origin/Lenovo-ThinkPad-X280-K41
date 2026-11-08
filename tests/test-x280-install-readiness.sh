#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
CANONICAL="$ROOT/scripts/k41-live-validation.sh"
READINESS_WRAPPER="$ROOT/scripts/x280-install-readiness.sh"
DIAGNOSTICS_WRAPPER="$ROOT/scripts/live-validation.sh"
SUPPLEMENTAL="$ROOT/scripts/x280-archiso-test.sh"

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

for script in "$CANONICAL" "$READINESS_WRAPPER" "$DIAGNOSTICS_WRAPPER" "$SUPPLEMENTAL"; do
  [[ -f $script ]] || fail "required live-validation script is missing: $script"
  bash -n "$script" || fail "Bash syntax error: $script"
done
pass "canonical validator, compatibility entry points, and supplemental collector pass bash -n"

bash "$CANONICAL" --help >/dev/null || fail "canonical validator help should succeed without running checks"
if bash "$CANONICAL" --invalid-option >/dev/null 2>&1; then
  fail "canonical validator must reject unknown options"
else
  rc=$?
  [[ $rc -eq 2 ]] || fail "unknown option should return exit 2, got $rc"
fi
pass "canonical validator help and argument rejection behavior are correct"

for required in \
  '--readiness' \
  '--diagnostics-only' \
  '/etc/arch-release' \
  '/run/archiso' \
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

grep -Fq 'k41-live-validation.sh" --readiness' "$SUPPLEMENTAL" || fail "supplemental Arch ISO collector does not delegate readiness to canonical validator"
grep -Fq '/run/x280-archiso-storage-test-' "$SUPPLEMENTAL" || fail "supplemental RAM-only report behavior was lost"
grep -Fq 'WWN,SERIAL,RM,RO,FSTYPE,MOUNTPOINTS' "$SUPPLEMENTAL" || fail "supplemental detailed block-device inventory was lost"
if grep -Fq 'scripts/validate-live-storage.sh' "$SUPPLEMENTAL"; then
  fail "supplemental collector duplicates the canonical storage-validator call"
fi
pass "supplemental collector retains detailed RAM-only evidence and delegates readiness/storage checks"

if grep -Eq 'wipefs|sgdisk|cryptsetup[[:space:]]+(luksFormat|open)|mkfs\.|pacstrap|mount[[:space:]]' "$CANONICAL"; then
  fail "canonical live validator contains disk mutation or installation commands"
fi
pass "canonical live validator contains no disk mutation or installation commands"
printf '%s\n' 'All K41 live-validation tests passed.'
