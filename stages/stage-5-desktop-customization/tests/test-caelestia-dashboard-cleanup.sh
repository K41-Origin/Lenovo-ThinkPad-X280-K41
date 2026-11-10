#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $EUID -eq 0 ]]; then
  printf 'FAIL: Dashboard cleanup test must run as a regular user.\n' >&2
  exit 1
fi

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
script="$root/stages/stage-5-desktop-customization/scripts/k41-cleanup-caelestia.sh"
[[ -f $script ]]

tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
home="$tmp/home"
config="$tmp/config"
mkdir -p "$home" "$config/caelestia/monitors/eDP-1" \
  "$config/quickshell/caelestia/modules/dashboard" \
  "$config/quickshell/caelestia/modules/bar"

cat >"$config/caelestia/shell.json" <<'JSON'
{"dashboard":{"enabled":true},"bar":{"persistent":true}}
JSON
cat >"$config/caelestia/monitors/eDP-1/shell.json" <<'JSON'
{"dashboard":{"enabled":true},"bar":{"persistent":true}}
JSON
printf 'dashboard fixture\n' >"$config/quickshell/caelestia/modules/dashboard/Dash.qml"
printf 'bar fixture\n' >"$config/quickshell/caelestia/modules/bar/Bar.qml"

for option in --audit --apply --rollback; do
  if HOME="$home" XDG_CONFIG_HOME="$config" bash "$script" "$option" >/dev/null 2>&1; then
    printf 'FAIL: obsolete option accepted: %s\n' "$option" >&2
    exit 1
  fi
done

output="$(HOME="$home" XDG_CONFIG_HOME="$config" bash "$script")"
grep -q 'Dashboard cleanup completed' <<<"$output"
[[ ! -e $config/quickshell/caelestia/modules/dashboard ]]
[[ -f $config/quickshell/caelestia/modules/bar/Bar.qml ]]

python3 - "$config/caelestia/shell.json" "$config/caelestia/monitors/eDP-1/shell.json" <<'PY'
import json, pathlib, sys
for raw in sys.argv[1:]:
    data = json.loads(pathlib.Path(raw).read_text(encoding="utf-8"))
    assert "dashboard" not in data, raw
    assert data["bar"]["persistent"] is True, raw
PY

printf 'PASS: direct cleanup removes Dashboard config/source and preserves sibling modules.\n'
