#!/usr/bin/env bash
set -Eeuo pipefail

root="$(git -C "$(dirname -- "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
script="$root/stages/stage-5-desktop-customization/workstreams/02-lock-screen/scripts/k41-deploy-lockscreen-visual.sh"
source="$root/stages/stage-5-desktop-customization/workstreams/02-lock-screen/modules/lockscreen"
revision="d999d4878ee4cec134168e60d913714566a8cfa6"
origin="https://github.com/caelestia-dots/shell.git"

[[ -s $script ]] || { printf 'FAIL: deployment script missing.\n' >&2; exit 1; }
bash -n "$script"
# Log publishing must use a separate clone and must not mutate the user's checkout.
grep -q 'git clone --quiet --branch main --single-branch' "$script" || {
    printf 'FAIL: deployment log publisher must use an independent clone.\\n' >&2
    exit 1
}
! grep -Eq 'git -C "\$repo_root" (fetch|worktree)' "$script" || {
    printf 'FAIL: publisher must not fetch/register worktrees in the user's checkout.\\n' >&2
    exit 1
}
! grep -q 'rc=1' <(sed -n '/if ! publish_logs; then/,/fi/p' "$script") || {
    printf 'FAIL: log publication failure must not change deployment exit status.\\n' >&2
    exit 1
}
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
    repo=$2
    shift 2
    case ${1:-} in
        rev-parse)
            case ${2:-} in
                --is-inside-work-tree) printf 'true\n'; exit 0 ;;
                HEAD) printf 'd999d4878ee4cec134168e60d913714566a8cfa6\n'; exit 0 ;;
            esac
            ;;
        remote)
            [[ ${2:-} == get-url && ${3:-} == origin ]] || exit 1
            printf 'https://github.com/caelestia-dots/shell.git\n'
            exit 0
            ;;
        show)
            exec /usr/bin/git -C "$repo" show "$@"
            ;;
    esac
fi
exec /usr/bin/git "$@"
MOCKGIT
cat > "$fakebin/caelestia" <<'MOCKCAELESTIA'
#!/usr/bin/env bash
set -Eeuo pipefail
printf '%s\n' "$*" >> "$K41_TEST_RELOAD_LOG"
[[ "$*" == "shell -r -d" && ${K41_TEST_RELOAD_FAIL:-0} != 1 ]]
MOCKCAELESTIA
cat > "$fakebin/sha256sum" <<'MOCKSHA256'
#!/usr/bin/env bash
set -Eeuo pipefail
if [[ ${K41_TEST_LEGACY_MODE:-0} == 1 && $# -eq 2 && $1 == -- ]]; then
    case $2 in
        "$K41_TEST_LEGACY_ROOT/Content.qml")
            printf '%s  %s\\n' '20264d13d2ee31510168aa96a61f4a754a194844bba54268e0858fa3ec540ab4' "$2"; exit 0 ;;
        "$K41_TEST_LEGACY_ROOT/Center.qml")
            printf '%s  %s\\n' '74e1f98643f5c6abee60efb211ccd4a4d65e0af21f0c4e3344ae6cb56347e562' "$2"; exit 0 ;;
        "$K41_TEST_LEGACY_ROOT/center/PasswordInput.qml")
            printf '%s  %s\\n' 'e7bb8981fdb5a83552277fe024bd56a60f26060e6e987c3a24fe6a880439bb5d' "$2"; exit 0 ;;
    esac
fi
exec /usr/bin/sha256sum "$@"
MOCKSHA256
chmod 0755 "$fakebin/git" "$fakebin/caelestia" "$fakebin/sha256sum"
reload_log="$tmp/reload.log"
PATH="$fakebin:$PATH" K41_TEST_RELOAD_LOG="$reload_log" K41_LOCKSCREEN_LOG_DIR="$tmp/deploy-logs" K41_LOCKSCREEN_TEST_MODE=1 \
    env -u XDG_CONFIG_HOME -u XDG_STATE_HOME HOME="$home" \
    WAYLAND_DISPLAY=wayland-test HYPRLAND_INSTANCE_SIGNATURE=test-session \
    bash "$script"

for file in LockSurface.qml Content.qml Center.qml center/PasswordInput.qml; do
    cmp -s "$source/$file" "$lock/$file" || {
        printf 'FAIL: visual file not deployed: %s\n' "$file" >&2
        exit 1
    }
done
[[ -s "$tmp/deploy-logs/latest.log" ]] || {
    printf 'FAIL: persistent latest deployment log was not written.\n' >&2
    exit 1
}
mapfile -t deployment_logs < <(find "$tmp/deploy-logs/history" -maxdepth 1 -type f -name 'deploy-*.log' -print)
[[ ${#deployment_logs[@]} -eq 1 ]] || {
    printf 'FAIL: expected one timestamped deployment log.\n' >&2
    exit 1
}
grep -q 'Caelestia reload command completed' "$tmp/deploy-logs/latest.log" || {
    printf 'FAIL: log does not record successful reload invocation.\n' >&2
    exit 1
}
[[ $(<"$reload_log") == "shell -r -d" ]] || {
    printf 'FAIL: Caelestia reload command was not called.\n' >&2
    exit 1
}
backup_root="$home/.local/state/k41/lockscreen/backups"
mapfile -t backups < <(find "$backup_root" -mindepth 1 -maxdepth 1 -type d -print)
[[ ${#backups[@]} -eq 1 ]] || {
    printf 'FAIL: expected one backup directory, found %s.\n' "${#backups[@]}" >&2
    exit 1
}
(cd "${backups[0]}" && sha256sum -c MANIFEST.sha256 >/dev/null)
# A failed reload must restore all four upstream visual files and try reloading them.
git -C "$host" checkout -- modules/lock/LockSurface.qml modules/lock/Content.qml modules/lock/Center.qml modules/lock/center/PasswordInput.qml
if PATH="$fakebin:$PATH" K41_TEST_RELOAD_LOG="$reload_log" K41_TEST_RELOAD_FAIL=1 K41_LOCKSCREEN_LOG_DIR="$tmp/deploy-logs" K41_LOCKSCREEN_TEST_MODE=1 \
    env -u XDG_CONFIG_HOME -u XDG_STATE_HOME HOME="$home" \
    WAYLAND_DISPLAY=wayland-test HYPRLAND_INSTANCE_SIGNATURE=test-session \
    bash "$script" >/dev/null 2>&1; then
    printf 'FAIL: deployment should fail when Caelestia reload fails.\n' >&2
    exit 1
fi
grep -q 'restoring the four original visual files' "$tmp/deploy-logs/latest.log" || {
    printf 'FAIL: failed deployment and rollback are not recorded in latest.log.\n' >&2
    exit 1
}
grep -q 'exit status 1' "$tmp/deploy-logs/latest.log" || {
    printf 'FAIL: failed deployment exit status is not recorded.\n' >&2
    exit 1
}
for file in LockSurface.qml Content.qml Center.qml center/PasswordInput.qml; do
    /usr/bin/git -C "$host" show "HEAD:modules/lock/$file" | cmp - "$lock/$file" || {
        printf 'FAIL: original file was not restored after reload failure: %s\n' "$file" >&2
        exit 1
    }
done

# Exact audited legacy K41 revisions are accepted and upgraded.
printf '// prior K41 deployment fixture\\n' > "$lock/Content.qml"
printf '// prior K41 deployment fixture\\n' > "$lock/Center.qml"
printf '// prior K41 deployment fixture\\n' > "$lock/center/PasswordInput.qml"
PATH="$fakebin:$PATH" K41_TEST_RELOAD_LOG="$reload_log" \
    K41_TEST_LEGACY_MODE=1 K41_TEST_LEGACY_ROOT="$lock" \
    K41_LOCKSCREEN_LOG_DIR="$tmp/deploy-logs" K41_LOCKSCREEN_TEST_MODE=1 \
    env -u XDG_CONFIG_HOME -u XDG_STATE_HOME HOME="$home" \
    WAYLAND_DISPLAY=wayland-test HYPRLAND_INSTANCE_SIGNATURE=test-session \
    bash "$script"
for file in LockSurface.qml Content.qml Center.qml center/PasswordInput.qml; do
    cmp -s "$source/$file" "$lock/$file" || {
        printf 'FAIL: audited legacy deployment was not upgraded: %s\\n' "$file" >&2
        exit 1
    }
done
grep -q 'Recognized exact legacy K41 deployment' "$tmp/deploy-logs/latest.log" || {
    printf 'FAIL: exact legacy K41 recognition was not recorded.\\n' >&2
    exit 1
}

# An unrecognized local edit must still be refused without being overwritten.
printf '// unknown local edit — preserve me\\n' > "$lock/Content.qml"
if PATH="$fakebin:$PATH" K41_TEST_RELOAD_LOG="$reload_log" \
    K41_TEST_LEGACY_MODE=0 K41_LOCKSCREEN_LOG_DIR="$tmp/deploy-logs" K41_LOCKSCREEN_TEST_MODE=1 \
    env -u XDG_CONFIG_HOME -u XDG_STATE_HOME HOME="$home" \
    WAYLAND_DISPLAY=wayland-test HYPRLAND_INSTANCE_SIGNATURE=test-session \
    bash "$script" >/dev/null 2>&1; then
    printf 'FAIL: deployment overwrote an unrecognized local edit.\\n' >&2
    exit 1
fi
grep -q 'Unrecognized local modifications at modules/lock/Content.qml' "$tmp/deploy-logs/latest.log" || {
    printf 'FAIL: unknown local edit refusal was not recorded.\\n' >&2
    exit 1
}
grep -q 'unknown local edit' "$lock/Content.qml" || {
    printf 'FAIL: unknown local edit was modified despite refusal.\\n' >&2
    exit 1
}

if PATH="$fakebin:$PATH" K41_TEST_RELOAD_LOG="$reload_log" \
    env -u XDG_CONFIG_HOME -u XDG_STATE_HOME HOME="$home" \
    WAYLAND_DISPLAY=wayland-test HYPRLAND_INSTANCE_SIGNATURE=test-session \
    bash "$script" --install >/dev/null 2>&1; then
    printf 'FAIL: script accepted an unsupported option.\n' >&2
    exit 1
fi

printf 'PASS: automatic deployment, upstream provenance guard, exact legacy K41 migration, unknown-edit refusal, four-file backup/checksum, QML replacement, Caelestia reload invocation, and persistent deployment logs.\n'
printf 'NOTE: the CI fixture does not execute a real Quickshell session or verify lock/unlock rendering.\n'
