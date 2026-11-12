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

qml="$fixture/$workstream/modules/topbar/Topbar.qml"
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

# Static provider contract: all live values must come from existing services.
grep -Fq 'import Caelestia.Services' "$qml"
grep -Fq 'import Quickshell.Services.UPower' "$qml"
grep -Fq 'ServiceRef {' "$qml"
grep -Fq 'service: Cpu' "$qml"
grep -Fq 'service: Memory' "$qml"
grep -Fq 'Cpu.percentage' "$qml"
grep -Fq 'Memory.percentage' "$qml"
grep -Fq 'UPower.displayDevice.percentage' "$qml"
grep -Fq 'Math.round(UPower.displayDevice.percentage)' "$qml"
if grep -Fq 'UPower.displayDevice.percentage * 100' "$qml"; then
    printf 'UPower percentage must not be multiplied by 100.\n' >&2
    exit 1
fi
grep -Fq 'UPower.onBattery' "$qml"
grep -Fq 'Time.format(' "$qml"
grep -Fq 'Notifs.notClosed.length' "$qml"
grep -Fq 'ShellState.forScreen(modelData)' "$qml"

if grep -Eq '/proc/(stat|meminfo)|/sys/class/power_supply|new Date\(|Timer[[:space:]]*\{|NotificationServer|trayWindow' "$qml"; then
    printf 'Forbidden duplicate polling/provider implementation found.\n' >&2
    exit 1
fi

run_installer() {
    HOME="$home" XDG_CONFIG_HOME="$config" XDG_STATE_HOME="$state" \
        bash "$fixture/$workstream/scripts/k41-implement-topbar.sh"
}

target="$config/quickshell/k41/modules/topbar/Topbar.qml"
run_installer
test -f "$target"
cmp -s "$target" "$qml"
grep -Fqx 'import "../k41/modules/topbar" as K41Topbar' "$shell"
grep -Fqx '    K41Topbar.Topbar {}' "$shell"
root_id_line="$(grep -nE '^[[:space:]]*id:[[:space:]]*root[[:space:]]*$' "$shell" | cut -d: -f1)"
topbar_line="$(grep -nE '^[[:space:]]*K41Topbar\.Topbar[[:space:]]*\{[[:space:]]*\}[[:space:]]*$' "$shell" | cut -d: -f1)"
test "$topbar_line" -gt "$root_id_line"
test "$(find "$state/k41/backups/topbar" -mindepth 1 -maxdepth 1 -type d | wc -l)" -eq 1

# A second run must be idempotent and must not create another backup.
run_installer
test "$(find "$state/k41/backups/topbar" -mindepth 1 -maxdepth 1 -type d | wc -l)" -eq 1

# A legacy/misplaced instance must be normalized after id: root, not duplicated.
cat >"$shell" <<'QML'
import "../k41/modules/topbar" as K41Topbar
import "modules"
import QtQuick
import Quickshell
import qs.services

ShellRoot {
    K41Topbar.Topbar {}
    id: root
    Background {}
}
QML
run_installer
root_id_line="$(grep -nE '^[[:space:]]*id:[[:space:]]*root[[:space:]]*$' "$shell" | cut -d: -f1)"
topbar_line="$(grep -nE '^[[:space:]]*K41Topbar\.Topbar[[:space:]]*\{[[:space:]]*\}[[:space:]]*$' "$shell" | cut -d: -f1)"
test "$topbar_line" -gt "$root_id_line"
test "$(grep -Ec '^[[:space:]]*K41Topbar\.Topbar[[:space:]]*\{[[:space:]]*\}[[:space:]]*$' "$shell")" -eq 1
test "$(find "$state/k41/backups/topbar" -mindepth 1 -maxdepth 1 -type d | wc -l)" -eq 2

# A partial host integration must fail closed without changing the module.
sed -i '/K41Topbar.Topbar/d' "$shell"
before="$(sha256sum "$target" | awk '{print $1}')"
if run_installer >/dev/null 2>&1; then
    printf 'Expected partial-integration failure.\n' >&2
    exit 1
fi
after="$(sha256sum "$target" | awk '{print $1}')"
test "$before" == "$after"

# A host without the expected root id must fail before creating a backup or changing files.
cat >"$shell" <<'QML'
import "modules"
import QtQuick
import Quickshell
import qs.services

ShellRoot {
    Background {}
}
QML
backup_count_before="$(find "$state/k41/backups/topbar" -mindepth 1 -maxdepth 1 -type d | wc -l)"
if run_installer >/dev/null 2>&1; then
    printf 'Expected missing-root-id failure.\n' >&2
    exit 1
fi
after="$(sha256sum "$target" | awk '{print $1}')"
test "$before" == "$after"
backup_count_after="$(find "$state/k41/backups/topbar" -mindepth 1 -maxdepth 1 -type d | wc -l)"
test "$backup_count_before" -eq "$backup_count_after"

printf 'PASS: provider contract, deployment, host integration, backup, idempotency, and fail-closed fixture.\n'
