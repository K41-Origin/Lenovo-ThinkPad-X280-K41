#!/usr/bin/env bash
set -Eeuo pipefail

root="$(git -C "$(dirname -- "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
script="$root/stages/stage-5-desktop-customization/workstreams/02-lock-screen/scripts/k41-deploy-lockscreen-visual.sh"
source="$root/stages/stage-5-desktop-customization/workstreams/02-lock-screen/modules/lockscreen"
revision="d999d4878ee4cec134168e60d913714566a8cfa6"
origin="https://github.com/caelestia-dots/shell.git"

[[ -s $script ]] || { printf 'FAIL: deployment script missing.\n' >&2; exit 1; }
bash -n "$script"
! grep -Eq -- '--(install|status|rollback)' "$script" || {
    printf 'FAIL: deployment script must not expose install/status/rollback options.\n' >&2
    exit 1
}
for file in LockSurface.qml Content.qml Center.qml center/PasswordInput.qml; do
    [[ -s $source/$file ]] || { printf 'FAIL: missing visual source: %s\n' "$file" >&2; exit 1; }
done

tmp="$(mktemp -d)"
cleanup() { rm -rf -- "$tmp"; }
trap cleanup EXIT
home="$tmp/home"
mkdir -m 700 -- "$home"
host="$home/.config/quickshell/caelestia"
lock="$host/modules/lock"
mkdir -p "$lock/center"
printf 'import Quickshell\nShellRoot {}\n' > "$host/shell.qml"
for file in Lock.qml LockSurface.qml Content.qml Center.qml center/PasswordInput.qml center/InputField.qml; do
    printf '// upstream fixture: %s\n' "$file" > "$lock/$file"
done

git -C "$host" init --quiet
git -C "$host" config user.name "K41 Test"
git -C "$host" config user.email "k41-test@example.invalid"
git -C "$host" add .
git -C "$host" commit --quiet -m "fixture upstream Caelestia tree"
git -C "$host" remote add origin "$origin"

# Stub only the audited host provenance and shell reload command; all file work
# is performed against the isolated HOME fixture.
fakebin="$tmp/bin"
mkdir -p "$fakebin"
cat > "$fakebin/git" <<'MOCKGIT'
#!/usr/bin/env bash
set -Eeuo pipefail
if [[ ${1:-} == -C ]]; then
    shift
    repo=$1
    shift
    case "${1:-} ${2:-} ${3:-}" in
        "rev-parse --is-inside-work-tree") printf 'true\n'; exit 0 ;;
        "remote get-url origin") printf 'https://github.com/caelestia-dots/shell.git\n'; exit 0 ;;
        "rev-parse HEAD") printf 'd999d4878ee4cec134168e60d913714566a8cfa6\n'; exit 0 ;;
        show\ HEAD:*)
            file=${2#HEAD:}
            cat "$repo/$file"
            exit 0
            ;;
    esac
fi
exec /usr/bin/git "$@"
MOCKGIT
cat > "$fakebin/caelestia" <<'MOCKCAELESTIA'
#!/usr/bin/env bash
set -Eeuo pipefail
printf '%s\n' "$*" >> "$K41_TEST_RELOAD_LOG"
[[ "$*" == "shell -r -d" ]]
MOCKCAELESTIA
chmod 0755 "$fakebin/git" "$fakebin/caelestia"
reload_log="$tmp/reload.log"
PATH="$fakebin:$PATH" K41_TEST_RELOAD_LOG="$reload_log" \
    env -u XDG_CONFIG_HOME -u XDG_STATE_HOME HOME="$home" \
    WAYLAND_DISPLAY=wayland-test HYPRLAND_INSTANCE_SIGNATURE=test-session \
    bash "$script"

for file in LockSurface.qml Content.qml Center.qml center/PasswordInput.qml; do
    cmp -s "$source/$file" "$lock/$file" || {
        printf 'FAIL: visual file not deployed: %s\n' "$file" >&2
        exit 1
    }
done
[[ $(<"$reload_log") == "shell -r -d" ]] || {
    printf 'FAIL: Caelestia reload command was not called.\n' >&2
    exit 1
}
backup_root="$home/.local/state/k41/lockscreen/backups"
mapfile -t backups < <(find "$backup_root" -mindepth 1 -maxdepth 1 -type d -print)
[[ ${#backups[@]} -eq 1 ]] || {
    printf 'FAIL: expected one backup directory, found ${#backups[@]}.\n' >&2
    exit 1
}
(cd "${backups[0]}" && sha256sum -c MANIFEST.sha256 >/dev/null)

if PATH="$fakebin:$PATH" K41_TEST_RELOAD_LOG="$reload_log" \
    env -u XDG_CONFIG_HOME -u XDG_STATE_HOME HOME="$home" \
    WAYLAND_DISPLAY=wayland-test HYPRLAND_INSTANCE_SIGNATURE=test-session \
    bash "$script" --install >/dev/null 2>&1; then
    printf 'FAIL: script accepted an unsupported option.\n' >&2
    exit 1
fi

printf 'PASS: automatic deployment, upstream provenance guard, four-file backup/checksum, QML replacement, and Caelestia reload invocation.\n'
printf 'NOTE: the CI fixture does not execute a real Quickshell session or verify lock/unlock rendering.\n'
