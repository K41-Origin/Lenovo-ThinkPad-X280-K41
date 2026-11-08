#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
SCRIPT="$ROOT/scripts/audit-x280-hardware.sh"
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$*"; }

[[ -f $SCRIPT ]] || fail 'hardware audit collector missing'
bash -n "$SCRIPT" || fail 'hardware audit collector syntax invalid'
pass 'hardware audit collector passes bash -n'
help_output="$(bash "$SCRIPT" --help)" || fail 'help command failed'
grep -Fq 'read-only' <<<"$help_output" || fail 'help must describe read-only behavior'
if bash "$SCRIPT" --invalid >/dev/null 2>&1; then
  fail 'unknown arguments must be rejected'
fi
for token in 'EUID == 0' 'umask 077' 'chmod 0700 "$run_dir"' 'chmod 0600 "$summary" "$diagnostics"' \
  'energy_full_design' 'charge_control_start_threshold' 'thermal_zone' \
  'power-profiles-daemon' 'lspci -nnk' 'lsblk -e7'; do
  grep -Fq -- "$token" "$SCRIPT" || fail "missing audit/safety contract: $token"
done
if grep -Eq 'pacman[[:space:]]+-S|systemctl[[:space:]]+(enable|disable|start|stop|restart)|chown[[:space:]]|chmod[[:space:]]+-R|mkfs\.|cryptsetup[[:space:]]+(luksFormat|open)|parted[[:space:]]|fdisk[[:space:]]' "$SCRIPT"; then
  fail 'hardware audit must not install packages, change services, or perform storage mutations'
fi
pass 'hardware audit read-only and privacy/safety contract checks passed'
