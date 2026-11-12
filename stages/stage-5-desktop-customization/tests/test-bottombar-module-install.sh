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
mkdir -p "$fixture/$workstream/modules/bottombar" "$fixture/$workstream/scripts" "$home" "$config/quickshell/caelestia" "$config/caelestia"
cp -- "$root/$workstream/modules/bottombar/Dock.Qml" "$fixture/$workstream/modules/bottombar/Dock.Qml"
cp -- "$root/$workstream/scripts/k41-implement-bottombar.sh" "$fixture/$workstream/scripts/k41-implement-bottombar.sh"
git -C "$fixture" init -q

shell="$config/quickshell/caelestia/shell.qml"
config_json="$config/caelestia/shell.json"
cat >"$shell" <<'EOF'
import "modules/k41dock" as K41Dock
ShellRoot {
    K41Dock.K41Dock {}
}
EOF
printf '{"bar":{"entries":[]}}\n' >"$config_json"
shell_before="$(sha256sum "$shell" | awk '{print $1}')"
json_before="$(sha256sum "$config_json" | awk '{print $1}')"

run_installer() {
    HOME="$home" XDG_CONFIG_HOME="$config" XDG_STATE_HOME="$state" \
        bash "$fixture/$workstream/scripts/k41-implement-bottombar.sh"
}

target="$config/quickshell/caelestia/modules/k41dock/K41Dock.qml"
k41_target="$config/quickshell/k41/modules/bottombar/Dock.Qml"
source="$fixture/$workstream/modules/bottombar/Dock.Qml"

# First run installs only the module.
run_installer
cmp -s "$source" "$target"
[[ $(stat -c %a "$target") == 644 ]]
[[ ! -e $k41_target ]]

# Second run is idempotent and does not create another backup.
backup_root="$state/k41/backups/bottombar"
before_count=("$backup_root"/*)
run_installer
after_count=("$backup_root"/*)
[[ ${#before_count[@]} -eq ${#after_count[@]} ]]

# A modified module at the audited Caelestia host import path is backed up and repaired.
printf 'locally-corrupted-module\n' >"$target"
run_installer
cmp -s "$source" "$target"
repaired=0
for backup in "$backup_root"/*/K41Dock.qml; do
    if [[ -f $backup ]] && grep -Fq 'locally-corrupted-module' "$backup"; then
        repaired=1
        break
    fi
done
(( repaired == 1 ))

# Inject one atomic-replacement failure; the existing runtime file must be restored.
printf 'preserve-me-on-failure\n' >"$target"
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

# The installer must not alter host integration or Caelestia's JSON settings.
[[ $(sha256sum "$shell" | awk '{print $1}') == "$shell_before" ]]
[[ $(sha256sum "$config_json" | awk '{print $1}') == "$json_before" ]]

# The implementation has one operation only: no modes, cleanup, package or service actions.
if grep -Eiq 'pacman[[:space:]]|systemctl[[:space:]]|shell\.json|sed[[:space:]].*shell\.qml|--rollback|--check|--cleanup|sudo' \
    "$root/$workstream/scripts/k41-implement-bottombar.sh"; then
    printf 'FAIL: installer contains an out-of-scope feature or host mutation.\n' >&2
    exit 1
fi

printf 'PASS: Caelestia-host module install/repair, idempotency, backup, rollback, and host isolation.\n'
