#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
SCRIPT="$ROOT/stages/stage-2-basic-arch-install/scripts/configure-arch-x280.sh"
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

[[ -f $SCRIPT ]] || fail "target configuration script is missing"
bash -n "$SCRIPT" || fail "target configuration script has a Bash syntax error"
pass "target configuration script passes bash -n"

 # shellcheck disable=SC2016
for required in \
  '/etc/arch-release' \
  'passwd "$username"' \
  'Asia/Jakarta' \
  'locale-gen' \
  'useradd --create-home --groups wheel' \
  'visudo -cf /etc/sudoers.d/10-k41-wheel' \
  'fallocate -l "$swap_bytes"' \
  'mkswap "$swap_tmp"' \
  "'/swapfile none swap defaults 0 0'"; do
  grep -Fq -- "$required" "$SCRIPT" || fail "required target configuration action is missing: $required"
done
pass "target configuration includes user, sudo, locale, timezone, and planned swapfile"

if grep -Eiq 'password[[:space:]]*=[[:space:]]*[^[:space:]]+' "$SCRIPT"; then
  fail "script appears to embed a password"
fi
pass "no static password is embedded"

if grep -Eq '(^|[[:space:]])(pacman|pacstrap)[[:space:]].*intel-ucode' "$SCRIPT"; then
  fail "Intel microcode must not be installed automatically"
fi
grep -Fq 'intel-ucode' "$SCRIPT" || fail "report-only Intel microcode recommendation is missing"
pass "Intel microcode follows the explicit report-only policy"
printf '%s\n' 'All target configuration script tests passed.'
