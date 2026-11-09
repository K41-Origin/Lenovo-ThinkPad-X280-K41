#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
SCRIPT="$ROOT/scripts/k41-guest-storage-audit.sh"
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$*"; }

[[ -f $SCRIPT ]] || fail 'Guest Mode audit collector missing'
bash -n "$SCRIPT" || fail 'collector Bash syntax invalid'
pass 'collector passes bash -n'

help_output="$(bash "$SCRIPT" --help)" || fail 'help command failed'
grep -Fq 'read-only' <<<"$help_output" || fail 'help must state read-only behavior'
grep -Fq 'browser profiles' <<<"$help_output" || fail 'help must state browser-profile privacy boundary'
if bash "$SCRIPT" --invalid >/dev/null 2>&1; then fail 'unknown arguments must be rejected'; fi
pass 'help and argument validation passed'

for token in 'EUID != 0' 'branch --show-current' 'reports/guest-mode-audit' \
  'swapon --show' '/proc/meminfo' '/proc/cmdline' '/etc/fstab' \
  'systemd/journald.conf' 'systemd/coredump.conf' 'systemd/logind.conf' \
  '/var/lib/systemd/coredump' '/sys/block/zram*' '/sys/module/zswap' \
  'loginctl list-sessions' 'loginctl show-user guest' 'getent passwd guest' \
  '/var/lib/systemd/linger/guest' 'pacman -Q' '/usr/share/wayland-sessions' \
  '/etc/xdg/autostart' 'findmnt -T' 'getfacl -cpn'; do
  grep -Fq -- "$token" "$SCRIPT" || fail "missing audit/safety scope: $token"
done
pass 'storage, logind, account, desktop, browser and permission audit scope is present'

if grep -Eq 'pacman[[:space:]]+-S|systemctl[[:space:]]+(enable|disable|start|stop|restart)|swapon[[:space:]]+-a|swapoff|mkfs\.|cryptsetup[[:space:]]+(luksFormat|open|close)|mkinitcpio[[:space:]]+-P|chown[[:space:]]|chmod[[:space:]]|user(add|del|mod)|group(add|del|mod)|passwd[[:space:]]|rm[[:space:]]+-rf' "$SCRIPT"; then
  fail 'collector must not mutate system configuration, accounts, swap, storage, or permissions'
fi
pass 'no system mutation, account management, package install, or destructive operation found'

if grep -Eq 'cat[[:space:]]+--?[[:space:]]+.*(/home|/root)|find[[:space:]].*(-name|--).*' "$SCRIPT"; then
  fail 'collector must not read/list user home content'
fi
if grep -Eq 'firefox.*(profile|cookies)|chrom(e|ium).*(profile|cookies)|\.mozilla|\.config' "$SCRIPT"; then
  fail 'collector must not inspect browser profiles or user config'
fi
pass 'collector avoids home contents, browser profiles, credentials, and user configuration'
