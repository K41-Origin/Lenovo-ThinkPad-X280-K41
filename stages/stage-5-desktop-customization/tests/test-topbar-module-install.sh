#!/usr/bin/env bash
set -Eeuo pipefail
source_root="$(cd -- "$(dirname -- "$0")/../workstreams/04-topbar" && pwd -P)"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
fixture="$tmp/repository"
home="$tmp/home"
config="$tmp/config"
state="$tmp/state"
workstream="stages/stage-5-desktop-customization/workstreams/04-topbar"
mkdir -p "$fixture/$workstream/modules/topbar" "$fixture/$workstream/scripts" "$home" "$config/quickshell/caelestia"
cp "$source_root/shell.qml" "$fixture/$workstream/shell.qml"
cp "$source_root/modules/topbar/Topbar.qml" "$fixture/$workstream/modules/topbar/Topbar.qml"
cp "$source_root/scripts/k41-implement-topbar.sh" "$fixture/$workstream/scripts/k41-implement-topbar.sh"
git -C "$fixture" init -q
cat >"$fixture/$workstream/modules/topbar/Topbar.qml" <<'QML'
import QtQuick
Item { objectName: "K41StandaloneTopbar" }
QML
caelestia_shell="$config/quickshell/caelestia/shell.qml"
printf 'ShellRoot { id: root }\n' >"$caelestia_shell"
caelestia_before="$(sha256sum "$caelestia_shell" | cut -d' ' -f1)"
run_installer() {
    HOME="$home" XDG_CONFIG_HOME="$config" XDG_STATE_HOME="$state" bash "$fixture/$workstream/scripts/k41-implement-topbar.sh"
}
target_shell="$config/quickshell/k41/shell.qml"
target_topbar="$config/quickshell/k41/modules/topbar/Topbar.qml"
run_installer
cmp -s "$target_shell" "$fixture/$workstream/shell.qml"
cmp -s "$target_topbar" "$fixture/$workstream/modules/topbar/Topbar.qml"
test "$(sha256sum "$caelestia_shell" | cut -d' ' -f1)" = "$caelestia_before"
test "$(find "$state/k41/backups/topbar" -mindepth 1 -maxdepth 1 -type d | wc -l)" -eq 1
run_installer
test "$(find "$state/k41/backups/topbar" -mindepth 1 -maxdepth 1 -type d | wc -l)" -eq 1
printf '\nimport Caelestia.Services\n' >>"$fixture/$workstream/modules/topbar/Topbar.qml"
before="$(sha256sum "$target_topbar" | cut -d' ' -f1)"
if run_installer >/dev/null 2>&1; then echo 'Expected Caelestia dependency rejection.' >&2; exit 1; fi
test "$(sha256sum "$target_topbar" | cut -d' ' -f1)" = "$before"
rm -f "$target_topbar"
ln -s "$target_shell" "$target_topbar"
if run_installer >/dev/null 2>&1; then echo 'Expected symlink target rejection.' >&2; exit 1; fi
test -L "$target_topbar"
test "$(sha256sum "$caelestia_shell" | cut -d' ' -f1)" = "$caelestia_before"
printf 'PASS: standalone deployment, Caelestia isolation, idempotency, dependency rejection, and symlink fail-closed.\n'
