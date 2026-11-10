#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $EUID -eq 0 ]]; then
  printf 'FAIL: dashboard cleanup fixture must run as a regular user.\n' >&2
  exit 1
fi

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
script="$root/stages/stage-5-desktop-customization/scripts/k41-cleanup-caelestia.sh"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT

home="$tmp/home"
config="$home/.config"
state="$home/.local/state"
mkdir -p -- "$config/caelestia/monitors/DP-1" "$state"
global="$config/caelestia/shell.json"
monitor="$config/caelestia/monitors/DP-1/shell.json"

cat >"$global" <<'JSON'
{
  "dashboard": {
    "enabled": true,
    "showDashboard": true,
    "showMedia": true
  },
  "launcher": {
    "enabled": true
  },
  "lock": {
    "enabled": true
  }
}
JSON

cat >"$monitor" <<'JSON'
{
  "dashboard": {
    "enabled": true,
    "showMedia": false
  },
  "bar": {
    "persistent": false
  }
}
JSON

cp -- "$global" "$tmp/global.before"
cp -- "$monitor" "$tmp/monitor.before"

run_cleanup() {
  HOME="$home" XDG_CONFIG_HOME="$config" XDG_STATE_HOME="$state" \
    bash "$script" "$@"
}

dry_output="$(run_cleanup --dry-run)"
grep -q 'DRY RUN ONLY' <<<"$dry_output"
cmp -s "$global" "$tmp/global.before"
cmp -s "$monitor" "$tmp/monitor.before"
[[ ! -e $state/k41/caelestia-cleanup/backups ]]

apply_output="$(run_cleanup --apply)"
grep -q 'Dashboard disabled and JSON read-back verification passed' <<<"$apply_output"
backup_dir="$(sed -n 's/^Backup: //p' <<<"$apply_output")"
[[ -n $backup_dir && -d $backup_dir ]]

python3 - "$global" "$monitor" <<'PY'
import json, pathlib, sys
global_cfg, monitor_cfg = map(pathlib.Path, sys.argv[1:])
g = json.loads(global_cfg.read_text())
m = json.loads(monitor_cfg.read_text())
assert g["dashboard"]["enabled"] is False
assert g["dashboard"]["showDashboard"] is True
assert g["dashboard"]["showMedia"] is True
assert g["launcher"]["enabled"] is True
assert g["lock"]["enabled"] is True
assert m["dashboard"]["enabled"] is False
assert m["dashboard"]["showMedia"] is False
assert m["bar"]["persistent"] is False
PY

rollback_output="$(run_cleanup --rollback "$backup_dir")"
grep -q 'Rollback completed' <<<"$rollback_output"
cmp -s "$global" "$tmp/global.before"
cmp -s "$monitor" "$tmp/monitor.before"

printf 'PASS: dashboard cleanup dry-run, apply, backup, verification, and rollback.\n'
