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
  "$config/quickshell/caelestia/modules/nexus/pages/panels"
cat >"$config/caelestia/shell.json" <<'JSON'
{"dashboard":{"enabled":true},"bar":{"persistent":true},"launcher":{"enabled":true}}
JSON
cat >"$config/caelestia/monitors/eDP-1/shell.json" <<'JSON'
{"bar":{"persistent":false},"appearance":{"scale":1}}
JSON
printf 'upstream nexus fixture\n' >"$config/quickshell/caelestia/modules/nexus/pages/panels/DashboardPanel.qml"

output="$(HOME="$home" XDG_CONFIG_HOME="$config" bash "$script")"
grep -q 'Dashboard disabled' <<<"$output"
grep -q 'Nexus may still display' <<<"$output"

python3 - "$config/caelestia/shell.json" "$config/caelestia/monitors/eDP-1/shell.json" <<'PY'
import json, pathlib, sys
global_data = json.loads(pathlib.Path(sys.argv[1]).read_text())
monitor_data = json.loads(pathlib.Path(sys.argv[2]).read_text())
assert global_data["dashboard"]["enabled"] is False
assert global_data["bar"]["persistent"] is True
assert global_data["launcher"]["enabled"] is True
assert monitor_data["bar"]["persistent"] is False
assert monitor_data["appearance"]["scale"] == 1
PY

# A second run is idempotent and preserves the existing disabled value.
HOME="$home" XDG_CONFIG_HOME="$config" bash "$script" >/dev/null
python3 - "$config/caelestia/shell.json" <<'PY'
import json, pathlib, sys
assert json.loads(pathlib.Path(sys.argv[1]).read_text())["dashboard"]["enabled"] is False
PY

# A broken monitor JSON file must abort before the global file changes.
before="$(sha256sum "$config/caelestia/shell.json" | cut -d' ' -f1)"
printf '{invalid json\n' >"$config/caelestia/monitors/eDP-1/shell.json"
if HOME="$home" XDG_CONFIG_HOME="$config" bash "$script" >/dev/null 2>&1; then
  printf 'FAIL: invalid monitor JSON was accepted.\n' >&2
  exit 1
fi
after="$(sha256sum "$config/caelestia/shell.json" | cut -d' ' -f1)"
[[ $before == "$after" ]]

# Source files are deliberately untouched.
[[ -f $config/quickshell/caelestia/modules/nexus/pages/panels/DashboardPanel.qml ]]

printf 'PASS: Dashboard config is disabled, unrelated settings/source are preserved, and failures preflight safely.\n'
