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
mkdir -p "$fixture/$workstream/modules/topbar" "$fixture/$workstream/scripts" \
    "$home" "$config/quickshell/caelestia"
cp -- "$source_root/modules/topbar/Topbar.qml" "$fixture/$workstream/modules/topbar/Topbar.qml"
cp -- "$source_root/scripts/k41-implement-topbar.sh" "$fixture/$workstream/scripts/k41-implement-topbar.sh"
git -C "$fixture" init -q

shell="$config/quickshell/caelestia/shell.qml"
cat >"$shell" <<'QML'
import "modules"
import QtQuick
import Quickshell
import qs.services

ShellRoot {
    id: root
    Background {}
}
QML

run_installer() {
    HOME="$home" XDG_CONFIG_HOME="$config" XDG_STATE_HOME="$state" \
        bash "$fixture/$workstream/scripts/k41-implement-topbar.sh"
}

target="$config/quickshell/k41/modules/topbar/Topbar.qml"
run_installer
test -f "$target"
cmp -s "$target" "$fixture/$workstream/modules/topbar/Topbar.qml"
grep -Fqx 'import "../k41/modules/topbar" as K41Topbar' "$shell"
grep -Fqx '    K41Topbar.Topbar {}' "$shell"
test "$(find "$state/k41/backups/topbar" -mindepth 1 -maxdepth 1 -type d | wc -l)" -eq 1

# A second run must be idempotent and must not create another backup.
run_installer
test "$(find "$state/k41/backups/topbar" -mindepth 1 -maxdepth 1 -type d | wc -l)" -eq 1

# A partial host integration must fail closed without changing the module.
sed -i '/K41Topbar.Topbar/d' "$shell"
before="$(sha256sum "$target" | awk '{print $1}')"
if run_installer >/dev/null 2>&1; then
    printf 'Expected partial-integration failure.\n' >&2
    exit 1
fi
after="$(sha256sum "$target" | awk '{print $1}')"
test "$before" == "$after"

printf 'PASS: deployment, host integration, backup, idempotency, and fail-closed fixture.\n'
