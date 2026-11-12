#!/usr/bin/env bash
set -Eeuo pipefail

root="$(git -C "$(dirname -- "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT

workstream="stages/stage-5-desktop-customization/workstreams/03-bottombar"
fixture="$tmp/repository"
home="$tmp/home"
config="$tmp/config"
state="$tmp/state"
mkdir -p "$fixture/$workstream/modules/bottombar" "$fixture/$workstream/scripts" \
    "$home" "$config/quickshell/caelestia"
cp -- "$root/$workstream/modules/bottombar/Dock.qml" "$fixture/$workstream/modules/bottombar/Dock.qml"
cp -- "$root/$workstream/scripts/k41-implement-bottombar.sh" "$fixture/$workstream/scripts/k41-implement-bottombar.sh"
git -C "$fixture" init -q

shell="$config/quickshell/caelestia/shell.qml"
cat >"$shell" <<'QML'
import "modules"
import "modules/drawers"
import "modules/k41dock" as K41Dock
import QtQuick
import Quickshell
import qs.services

ShellRoot {
    Background {}
    K41Dock.K41Dock {}
}
QML

run_installer() {
    HOME="$home" XDG_CONFIG_HOME="$config" XDG_STATE_HOME="$state" \
        bash "$fixture/$workstream/scripts/k41-implement-bottombar.sh"
}

source="$fixture/$workstream/modules/bottombar/Dock.qml"
target="$config/quickshell/k41/modules/bottombar/Dock.qml"
backup_root="$state/k41/backups/bottombar"
legacy_import='import "modules/k41dock" as K41Dock'
new_import='import "../k41/modules/bottombar" as K41Bottombar'
new_instance='K41Bottombar.Dock {}'

# Install module and migrate only the exact K41Dock import/instance in Caelestia.
run_installer
cmp -s "$source" "$target"
[[ $(stat -c %a "$target") == 644 ]]
grep -Fqx "$new_import" "$shell"
grep -Eq '^[[:space:]]*K41Bottombar\.Dock[[:space:]]*\{[[:space:]]*\}[[:space:]]*
! grep -Fq "$legacy_import" "$shell"
grep -Fq 'ShellRoot {' "$shell"
compgen -G "$backup_root/*/shell.qml" >/dev/null

# A second run is idempotent and creates no additional backup.
before_count=("$backup_root"/*)
run_installer
after_count=("$backup_root"/*)
[[ ${#before_count[@]} -eq ${#after_count[@]} ]]

# Repair a modified canonical module without changing the Caelestia host.
printf 'locally-corrupted-module\n' >"$target"
run_installer
cmp -s "$source" "$target"
grep -Fqx "$new_import" "$shell"

# A failed first atomic replacement must leave both paths unchanged.
printf 'preserve-me-on-failure\n' >"$target"
cp -- "$shell" "$tmp/shell.before-failure"
fakebin="$tmp/fakebin"
mkdir -p "$fakebin"
real_mv="$(command -v mv)"
cat >"$fakebin/mv" <<EOF
#!/usr/bin/env bash
marker="$tmp/mv-failed-once"
if [[ ! -e \$marker ]]; then
    : >"\$marker"
    exit 1
fi
exec "$real_mv" "\$@"
EOF
chmod 0755 "$fakebin/mv"
if HOME="$home" XDG_CONFIG_HOME="$config" XDG_STATE_HOME="$state" PATH="$fakebin:$PATH" \
    bash "$fixture/$workstream/scripts/k41-implement-bottombar.sh"; then
    printf 'FAIL: injected atomic replacement failure unexpectedly succeeded.\n' >&2
    exit 1
fi
grep -Fq 'preserve-me-on-failure' "$target"
cmp -s "$shell" "$tmp/shell.before-failure"

# Ambiguous host integration must fail closed without modifying the module or host.
printf 'custom-host-state\n' >>"$shell"
cp -- "$target" "$tmp/module.before-ambiguous"
if run_installer; then
    printf 'FAIL: ambiguous shell.qml unexpectedly accepted.\n' >&2
    exit 1
fi
cmp -s "$shell" <(cat "$tmp/shell.before-failure"; printf 'custom-host-state\n')
cmp -s "$target" "$tmp/module.before-ambiguous"

if grep -Eiq 'pacman[[:space:]]|systemctl[[:space:]]|sudo|rm[[:space:]].*k41dock' \
    "$fixture/$workstream/scripts/k41-implement-bottombar.sh"; then
    printf 'FAIL: installer contains an out-of-scope host/system/cleanup operation.\n' >&2
    exit 1
fi

printf 'PASS: K41 module deployment, Caelestia import migration, idempotency, repair, rollback, and fail-closed host handling.\n'
 "$shell"
! grep -Fq "$legacy_import" "$shell"
grep -Fq 'ShellRoot {' "$shell"
[[ -f "$backup_root"/*/shell.qml ]]

# A second run is idempotent and creates no additional backup.
before_count=("$backup_root"/*)
run_installer
after_count=("$backup_root"/*)
[[ ${#before_count[@]} -eq ${#after_count[@]} ]]

# Repair a modified canonical module without changing the Caelestia host.
printf 'locally-corrupted-module\n' >"$target"
run_installer
cmp -s "$source" "$target"
grep -Fqx "$new_import" "$shell"

# A failed first atomic replacement must leave both paths unchanged.
printf 'preserve-me-on-failure\n' >"$target"
cp -- "$shell" "$tmp/shell.before-failure"
fakebin="$tmp/fakebin"
mkdir -p "$fakebin"
real_mv="$(command -v mv)"
cat >"$fakebin/mv" <<EOF
#!/usr/bin/env bash
marker="$tmp/mv-failed-once"
if [[ ! -e \$marker ]]; then
    : >"\$marker"
    exit 1
fi
exec "$real_mv" "\$@"
EOF
chmod 0755 "$fakebin/mv"
if HOME="$home" XDG_CONFIG_HOME="$config" XDG_STATE_HOME="$state" PATH="$fakebin:$PATH" \
    bash "$fixture/$workstream/scripts/k41-implement-bottombar.sh"; then
    printf 'FAIL: injected atomic replacement failure unexpectedly succeeded.\n' >&2
    exit 1
fi
grep -Fq 'preserve-me-on-failure' "$target"
cmp -s "$shell" "$tmp/shell.before-failure"

# Ambiguous host integration must fail closed without modifying the module or host.
printf 'custom-host-state\n' >>"$shell"
cp -- "$target" "$tmp/module.before-ambiguous"
if run_installer; then
    printf 'FAIL: ambiguous shell.qml unexpectedly accepted.\n' >&2
    exit 1
fi
cmp -s "$shell" <(cat "$tmp/shell.before-failure"; printf 'custom-host-state\n')
cmp -s "$target" "$tmp/module.before-ambiguous"

if grep -Eiq 'pacman[[:space:]]|systemctl[[:space:]]|sudo|rm[[:space:]].*k41dock' \
    "$fixture/$workstream/scripts/k41-implement-bottombar.sh"; then
    printf 'FAIL: installer contains an out-of-scope host/system/cleanup operation.\n' >&2
    exit 1
fi

printf 'PASS: K41 module deployment, Caelestia import migration, idempotency, repair, rollback, and fail-closed host handling.\n'
