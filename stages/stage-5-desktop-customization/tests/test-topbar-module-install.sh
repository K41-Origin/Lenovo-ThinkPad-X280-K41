#!/usr/bin/env bash
set -Eeuo pipefail
source_root="$(cd -- "$(dirname -- "$0")/../workstreams/04-topbar" && pwd -P)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fixture="$tmp/repository"; home="$tmp/home"; config="$tmp/config"; state="$tmp/state"
workstream="stages/stage-5-desktop-customization/workstreams/04-topbar"
mkdir -p "$fixture/$workstream/modules/topbar" "$fixture/$workstream/scripts" "$home" "$config/quickshell/caelestia"
cp "$source_root/modules/topbar/Topbar.qml" "$fixture/$workstream/modules/topbar/Topbar.qml"
cp "$source_root/scripts/k41-implement-topbar.sh" "$fixture/$workstream/scripts/k41-implement-topbar.sh"
git -C "$fixture" init -q
qml="$fixture/$workstream/modules/topbar/Topbar.qml"
cat >"$qml" <<'QML'
import QtQuick
Item { objectName: "K41Topbar" }
QML
host="$config/quickshell/caelestia/shell.qml"
cat >"$host" <<'QML'
import QtQuick
import Quickshell
ShellRoot {
    id: root
}
QML
host_before="$(sha256sum "$host" | cut -d' ' -f1)"
run_installer() { HOME="$home" XDG_CONFIG_HOME="$config" XDG_STATE_HOME="$state" bash "$fixture/$workstream/scripts/k41-implement-topbar.sh"; }
target="$config/quickshell/caelestia/k41/modules/topbar/Topbar.qml"
run_installer
cmp -s "$target" "$qml"
grep -Fqx 'import qs.k41.modules.topbar as K41Topbar' "$host"
grep -Fqx '    K41Topbar.Topbar {}' "$host"
test "$(find "$state/k41/backups/topbar" -mindepth 1 -maxdepth 1 -type d | wc -l)" -eq 1
run_installer
test "$(find "$state/k41/backups/topbar" -mindepth 1 -maxdepth 1 -type d | wc -l)" -eq 1
test -d "$config/quickshell/caelestia"
printf '\nimport Caelestia.Services\n' >>"$qml"
before="$(sha256sum "$target" | cut -d' ' -f1)"
if run_installer >/dev/null 2>&1; then echo 'Expected Caelestia dependency rejection.' >&2; exit 1; fi
test "$(sha256sum "$target" | cut -d' ' -f1)" = "$before"
rm -f "$target"; ln -s "$host" "$target"
if run_installer >/dev/null 2>&1; then echo 'Expected symlink target rejection.' >&2; exit 1; fi
test -L "$target"
test "$(sha256sum "$host" | cut -d' ' -f1)" != "$host_before"
printf 'PASS: Caelestia entrypoint integration, K41 module isolation, idempotency, dependency and symlink rejection.\\n'
