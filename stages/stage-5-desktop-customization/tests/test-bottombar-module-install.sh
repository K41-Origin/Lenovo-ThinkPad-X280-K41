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
mkdir -p "$fixture/$workstream/modules/bottombar" "$fixture/$workstream/scripts" "$home" "$config/quickshell"
cp -- "$root/$workstream/modules/bottombar/Dock.Qml" "$fixture/$workstream/modules/bottombar/Dock.Qml"
cp -- "$root/$workstream/scripts/k41-implement-bottombar.sh" "$fixture/$workstream/scripts/k41-implement-bottombar.sh"
git -C "$fixture" init -q

run_installer() {
    HOME="$home" XDG_CONFIG_HOME="$config" XDG_STATE_HOME="$state" \
        bash "$fixture/$workstream/scripts/k41-implement-bottombar.sh"
}

source="$fixture/$workstream/modules/bottombar/Dock.Qml"
target="$config/quickshell/k41/modules/bottombar/Dock.Qml"
caelestia="$config/quickshell/caelestia"

# Install creates the dedicated K41 namespace and does not create a Caelestia host.
run_installer
cmp -s "$source" "$target"
[[ $(stat -c %a "$target") == 644 ]]
[[ ! -e $caelestia ]]

# A second run is idempotent and creates no additional backup.
backup_root="$state/k41/backups/bottombar"
before_count=("$backup_root"/*)
run_installer
after_count=("$backup_root"/*)
[[ ${#before_count[@]} -eq ${#after_count[@]} ]]

# A changed module at the K41 target is backed up and repaired.
printf 'locally-corrupted-module\n' >"$target"
run_installer
cmp -s "$source" "$target"
repaired=0
for backup in "$backup_root"/*/Dock.Qml; do
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

# Installer owns only the K41 module; no Caelestia host or system paths are changed.
[[ ! -e $caelestia ]]
if grep -Eiq 'pacman[[:space:]]|systemctl[[:space:]]|shell\.qml|shell\.json|--rollback|--check|--cleanup|sudo' \
    "$root/$workstream/scripts/k41-implement-bottombar.sh"; then
    printf 'FAIL: installer contains an out-of-scope host/system operation.\n' >&2
    exit 1
fi

printf 'PASS: K41 namespace install/repair, idempotency, backup, rollback, and Caelestia isolation.\n'
