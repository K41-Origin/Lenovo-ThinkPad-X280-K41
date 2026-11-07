#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
SCRIPT="$ROOT/scripts/configure-arch-x280.sh"
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

[[ -f $SCRIPT ]] || fail "target configuration script is missing"
bash -n "$SCRIPT" || fail "target configuration script has a Bash syntax error"
pass "target configuration script passes bash -n"

 # shellcheck disable=SC2016
for required in \
  '/etc/arch-release' \
  'passwd "$username"' \
  'pacman -S --needed --noconfirm intel-ucode' \
  'Asia/Jakarta' \
  'locale-gen' \
  'useradd --create-home --groups wheel' \
  'visudo -cf /etc/sudoers.d/10-k41-wheel' \
  'fallocate -l "$swap_bytes"' \
  'mkswap "$swap_tmp"' \
  "'/swapfile none swap defaults 0 0'"; do
  grep -Fq -- "$required" "$SCRIPT" || fail "required target configuration action is missing: $required"
done
pass "target configuration includes user, sudo, locale, timezone, Intel microcode, and planned swapfile"

if grep -Eiq 'password[[:space:]]*=[[:space:]]*[^[:space:]]+' "$SCRIPT"; then
  fail "script appears to embed a password"
fi
pass "no static password is embedded"
printf '%s\n' 'All target configuration script tests passed.'
