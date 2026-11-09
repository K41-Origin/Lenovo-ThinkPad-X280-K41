#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
SCRIPT="$ROOT/scripts/k41-guest-storage-audit.sh"
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$*"; }

[[ -f $SCRIPT ]] || fail 'Guest Mode storage audit collector missing'
bash -n "$SCRIPT" || fail 'collector Bash syntax invalid'
pass 'collector passes bash -n'

help_output="$(bash "$SCRIPT" --help)" || fail 'help command failed'
grep -Fq 'read-only' <<<"$help_output" || fail 'help must state read-only behavior'
if bash "$SCRIPT" --invalid >/dev/null 2>&1; then
  fail 'unknown arguments must be rejected'
fi
pass 'help and argument validation passed'

for token in 'EUID != 0' 'branch --show-current' 'reports/guest-mode-audit' \
  'swapon --show' '/proc/meminfo' '/proc/cmdline' '/etc/fstab' \
  'systemd/journald.conf' 'systemd/coredump.conf' '/var/lib/systemd/coredump' \
  '/sys/block/zram*' 'findmnt -T'; do
  grep -Fq -- "$token" "$SCRIPT" || fail "missing audit/safety scope: $token"
done
pass 'required persistence inspection scope is present'

if grep -Eq 'pacman[[:space:]]+-S|systemctl[[:space:]]+(enable|disable|start|stop|restart)|swapon[[:space:]]+-a|swapoff|mkfs\.|cryptsetup[[:space:]]+(luksFormat|open|close)|mkinitcpio[[:space:]]+-P|chown[[:space:]]|chmod[[:space:]]|umask[[:space:]]' "$SCRIPT"; then
  fail 'collector must not mutate system configuration, swap, storage, or permissions'
fi
pass 'no system mutation, package install, permission change, or swap operation found'

if grep -Eq 'cat[[:space:]]+--?[[:space:]]+.*(/home|/root)|find[[:space:]].*(-name|--).*' "$SCRIPT"; then
  fail 'collector must not read/list user home content'
fi
pass 'collector does not enumerate user home contents'
