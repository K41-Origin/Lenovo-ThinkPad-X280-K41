#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "\${BASH_SOURCE[0]}")/.." && pwd -P)"
SCRIPT="$ROOT/scripts/set-x280-power-profile.sh"
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$*"; }
bash -n "$SCRIPT" || fail 'profile selector syntax invalid'
pass 'profile selector passes bash -n'
bash "$SCRIPT" --help | grep -Fq -- '--apply PROFILE' || fail 'help missing apply usage'
if bash "$SCRIPT" --invalid >/dev/null 2>&1; then fail 'invalid option accepted'; fi
grep -Fq 'set-property' "$SCRIPT" || fail 'D-Bus mutation command missing'
grep -Fq 'get-property' "$SCRIPT" || fail 'D-Bus verification missing'
grep -Fq 'power-saver|balanced|performance' "$SCRIPT" || fail 'profile allowlist missing'
if grep -Eq 'pacman[[:space:]]+-S|systemctl[[:space:]]+(enable|disable|start|stop|restart)|tee[[:space:]]+(/sys/|/etc/)|>[[:space:]]*/sys/' "$SCRIPT"; then fail 'unsafe side effect found'; fi
pass 'profile selector explicit mutation and safety checks passed'
