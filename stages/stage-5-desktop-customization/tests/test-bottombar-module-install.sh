#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(git -C "$(dirname -- "$0")" rev-parse --show-toplevel)"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
workstream="stages/stage-5-desktop-customization/workstreams/03-bottombar"
fixture="$tmp/repository"
home="$tmp/home"
config="$tmp/config"
state="$tmp/state"
mkdir -p "$fixture/$workstream/modules/bottombar" "$fixture/$workstream/scripts" \
    "$home" "$config/quickshell/caelestia"
cp -- "$repo_root/$workstream/modules/bottombar/Dock.qml" "$fixture/$workstream/modules/bottombar/Dock.qml"
cp -- "$repo_root/$workstream/scripts/k41-implement-bottombar.sh" "$fixture/$workstream/scripts/k41-implement-bottombar.sh"
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
target="$config/quickshell/caelestia/k41/modules/bottombar/Dock.qml"
legacy_target="$config/quickshell/k41/modules/bottombar/Dock.qml"
legacy_case="$config/quickshell/k41/modules/bottombar/Dock.Qml"
k41_root="$config/quickshell/k41"
backup_root="$state/k41/backups/bottombar"

# Simulate the existing X280 case-variant file. The installer must not use,
# overwrite, rename, or delete it; cleanup remains an explicit manual action.
printf 'legacy-case-variant-preserve-me\\n' >"$legacy_case"
cp -- "$legacy_case" "$tmp/legacy-case.before"
legacy_import='import "modules/k41dock" as K41Dock'
new_import='import qs.k41.modules.bottombar as K41Bottombar'

# Deploy the canonical K41 file and migrate the existing Caelestia reference.
run_installer
cmp -s "$source" "$target"
cmp -s "$source" "$legacy_target"
[[ $(stat -c %a "$target") == 644 ]]
[[ ! -e "$k41_root/shell.qml" && ! -e "$k41_root/qmldir" ]]
[[ ! -e "$k41_root/modules/qmldir" && ! -e "$k41_root/modules/bottombar/qmldir" ]]
cmp -s "$legacy_case" "$tmp/legacy-case.before"
[[ -f $legacy_case && ! -L $legacy_case ]]
grep -Fqx "$new_import" "$shell"
grep -Eq '^[[:space:]]*K41Bottombar\.Dock[[:space:]]*\{[[:space:]]*\}[[:space:]]*$' "$shell"
! grep -Fq "$legacy_import" "$shell"
grep -Fq 'ShellRoot {' "$shell"
compgen -G "$backup_root/*/shell.qml" >/dev/null

# Exact repeat is idempotent and leaves the legacy case-variant untouched.
before_count=("$backup_root"/*)
run_installer
after_count=("$backup_root"/*)
[[ ${#before_count[@]} -eq ${#after_count[@]} ]]
cmp -s "$legacy_case" "$tmp/legacy-case.before"

# Repair only the module when its runtime copy has drifted.
printf 'locally-corrupted-module\n' >"$target"
cp -- "$shell" "$tmp/shell.before-repair"
run_installer
cmp -s "$source" "$target"
cmp -s "$source" "$legacy_target"
cmp -s "$shell" "$tmp/shell.before-repair"

# Inject a failed module replacement; prior module and host must remain intact.
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
    printf 'FAIL: injected replacement failure unexpectedly succeeded.\n' >&2
    exit 1
fi
grep -Fq 'preserve-me-on-failure' "$target"
cmp -s "$shell" "$tmp/shell.before-failure"

# An unknown/manual host edit must fail closed and preserve both files.
printf '%s\n' "$legacy_import" >>"$shell"
cp -- "$target" "$tmp/module.before-ambiguous"
cp -- "$shell" "$tmp/shell.before-ambiguous"
if run_installer; then
    printf 'FAIL: ambiguous shell.qml unexpectedly accepted.\n' >&2
    exit 1
fi
cmp -s "$shell" "$tmp/shell.before-ambiguous"
cmp -s "$target" "$tmp/module.before-ambiguous"

if grep -Eiq 'pacman[[:space:]]|systemctl[[:space:]]|sudo|rm[[:space:]].*k41dock' \
    "$fixture/$workstream/scripts/k41-implement-bottombar.sh"; then
    printf 'FAIL: installer contains an out-of-scope system/cleanup operation.\n' >&2
    exit 1
fi

printf 'PASS: K41 deployment, Caelestia import migration, idempotency, repair, rollback, and fail-closed host handling.\n'
