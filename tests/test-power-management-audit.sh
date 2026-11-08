#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
SCRIPT="$ROOT/scripts/audit-x280-power-management.sh"
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$*"; }
[[ -f $SCRIPT ]] || fail 'power-management audit collector missing'
bash -n "$SCRIPT" || fail 'power-management audit collector syntax invalid'
pass 'power-management audit collector passes bash -n'
help_output="$(bash "$SCRIPT" --help)" || fail 'help command failed'
grep -Fq 'read-only' <<<"$help_output" || fail 'help must describe read-only behavior'
if bash "$SCRIPT" --invalid >/dev/null 2>&1; then fail 'unknown arguments must be rejected'; fi
for token in 'EUID == 0' 'umask 077' 'chmod 0700 "$run_dir"' 'chmod 0600 "$summary" "$diagnostics"' 'scaling_governor' 'energy_performance_preference' 'intel_pstate' 'platform_profile' 'power-profiles-daemon.service' 'charge_control_start_threshold' 'busctl --system introspect' 'ActiveProfile'; do
  grep -Fq -- "$token" "$SCRIPT" || fail "missing baseline/safety contract: $token"
done
if grep -Eq 'pacman[[:space:]]+-S|systemctl[[:space:]]+(enable|disable|start|stop|restart)|tee[[:space:]]+(/sys/|/etc/)|>[[:space:]]*/sys/|chown[[:space:]]|chmod[[:space:]]+-R|modprobe[[:space:]]+-r' "$SCRIPT"; then
  fail 'power audit must not install packages, change services, or write system controls'
fi
pass 'power-management audit read-only and safety contract checks passed'
