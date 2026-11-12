#!/usr/bin/env bash
# Deploy and activate the Stage 5 K41 Lock Screen visuals in the active Caelestia tree.
# Run as the regular desktop user from anywhere inside the repository.
set -Eeuo pipefail
umask 077

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
info() { printf 'INFO: %s\n' "$*"; }


[[ $# -eq 0 ]] || die "This script has no options; run it without arguments."
[[ $EUID -ne 0 ]] || die "Run from the regular desktop account, never with sudo."
[[ -n ${HOME:-} && $HOME == /* && -d $HOME ]] || die "HOME is missing or invalid."
[[ -n ${WAYLAND_DISPLAY:-} ]] || die "No Wayland session detected; run this from the active Hyprland desktop."
[[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] || die "Hyprland session signature is missing; refusing to reload a non-active desktop."

for command_name in realpath stat git cmp install mktemp date cp mv rm sha256sum caelestia; do
    command -v "$command_name" >/dev/null 2>&1 || die "Required command not found: $command_name"
done

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(realpath -- "$script_dir/../../../../..")"
log_root="${K41_LOCKSCREEN_LOG_DIR:-$HOME/.local/state/k41/lockscreen/deployment-logs}"
[[ $log_root == /* ]] || die "Log directory must be an absolute path: $log_root"
assert_log_path() {
    local path=$1
    [[ ! -L $path ]] || die "Refusing symlinked log path: $path"
    if [[ -e $path ]]; then
        [[ -d $path && $(stat -c %u "$path") == "$EUID" ]] ||
            die "Log path is not a user-owned directory: $path"
    fi
}
for path in "$HOME/.local" "$HOME/.local/state" "$HOME/.local/state/k41" "$HOME/.local/state/k41/lockscreen" "$log_root"; do
    assert_log_path "$path"
done
mkdir -p -- "$log_root/history"
for path in "$HOME/.local" "$HOME/.local/state" "$HOME/.local/state/k41" "$HOME/.local/state/k41/lockscreen" "$log_root" "$log_root/history"; do
    assert_log_path "$path"
done
log_stamp="$(date -u +'%Y%m%dT%H%M%SZ')"
log_file="$log_root/history/deploy-$log_stamp-$.log"
: > "$log_file"
chmod 0600 "$log_file"
exec 3>&1 4>&2
exec > >(tee -a "$log_file") 2>&1
log_tee_pid=$!
on_error() {
    local rc=$?
    printf 'ERROR: command failed (exit=%s, line=%s): %s\n' "$rc" "$LINENO" "$BASH_COMMAND" >&2
    return "$rc"
}
trap on_error ERR
source_root="$repo_root/stages/stage-5-desktop-customization/workstreams/02-lock-screen/modules/lockscreen"
config_root="$HOME/.config"
host_root="$config_root/quickshell/caelestia"
lock_root="$host_root/modules/lock"
# Keep compatibility copies in both K41 namespaces. Caelestia remains the
# active host; these are source mirrors, not separate shell configurations.
legacy_k41_module_root="$config_root/quickshell/k41/modules/lockscreen"
caelestia_k41_module_root="$host_root/k41/modules/lockscreen"
state_root="$HOME/.local/state/k41/lockscreen/backups"
readonly upstream_url="https://github.com/caelestia-dots/shell.git"
readonly upstream_revision="d999d4878ee4cec134168e60d913714566a8cfa6"
readonly source_files=(LockSurface.qml Content.qml Center.qml center/PasswordInput.qml)
# Exact SHA-256 allowlist for three previously deployed K41 revisions.
# Captured by the X280 startup audit on 2026-11-12; each differed from the
# current K41 source only in its first descriptive comment line.
# Unknown local content remains protected by the default refusal below.
declare -Ar legacy_deployed_sha256=(
    ["Content.qml"]="20264d13d2ee31510168aa96a61f4a754a194844bba54268e0858fa3ec540ab4"
    ["Center.qml"]="74e1f98643f5c6abee60efb211ccd4a4d65e0af21f0c4e3344ae6cb56347e562"
    ["center/PasswordInput.qml"]="e7bb8981fdb5a83552277fe024bd56a60f26060e6e987c3a24fe6a880439bb5d"
)

[[ -d "$source_root" && ! -L "$source_root" ]] || die "Stage 5 visual source is missing: $source_root"
[[ $(stat -c %u "$repo_root") == "$EUID" ]] || die "Repository checkout is not owned by the current user."
[[ -d "$host_root" && ! -L "$host_root" && -s "$host_root/shell.qml" ]] ||
    die "Active user Caelestia source tree not found at $host_root. Refusing to create a partial Quickshell config overlay."
[[ -d "$lock_root" && ! -L "$lock_root" ]] || die "Caelestia lock module directory is missing: $lock_root"
[[ $(git -C "$host_root" rev-parse --is-inside-work-tree 2>/dev/null || true) == true ]] ||
    die "Caelestia user source tree is not a Git checkout; refusing to overwrite unknown files."
[[ $(git -C "$host_root" remote get-url origin 2>/dev/null || true) == "$upstream_url" ]] ||
    die "Caelestia source tree origin does not match the audited upstream repository."
[[ $(git -C "$host_root" rev-parse HEAD 2>/dev/null || true) == "$upstream_revision" ]] ||
    die "Caelestia source revision differs from the audited revision $upstream_revision; re-audit before deployment."

# Reject symlinked paths and unexpected ownership before writing any user files.
assert_safe_path() {
    local path=$1 current="" part
    local -a parts=()
    IFS=/ read -r -a parts <<< "$path"
    for part in "${parts[@]}"; do
        [[ -z $part ]] && continue
        current="$current/$part"
        [[ ! -L $current ]] || die "Refusing symlink path component: $current"
    done
}
for path in "$config_root" "$config_root/quickshell" "$host_root" "$host_root/modules" "$lock_root" "$host_root/k41" "$host_root/k41/modules" "$caelestia_k41_module_root" "$config_root/quickshell/k41" "$config_root/quickshell/k41/modules" "$legacy_k41_module_root" "$state_root"; do
    assert_safe_path "$path"
    if [[ -e $path ]]; then
        [[ -d $path && $(stat -c %u "$path") == "$EUID" ]] ||
            die "Path is not a user-owned directory: $path"
    fi
done

for relative in "${source_files[@]}"; do
    [[ -s "$source_root/$relative" && ! -L "$source_root/$relative" ]] ||
        die "Missing, empty, or symlinked visual source: $relative"
done

# Confirm required upstream lock host files remain present. They are not replaced.
for relative in Lock.qml Pam.qml LockSurface.qml Content.qml Center.qml center/PasswordInput.qml center/InputField.qml center/Clock.qml center/StateMessage.qml; do
    [[ -s "$lock_root/$relative" && ! -L "$lock_root/$relative" ]] ||
        die "Required Caelestia lock runtime dependency is missing: modules/lock/$relative"
done

# Accept only current K41 files, pristine pinned-upstream files, or exact
# hashes of audited legacy K41 deployments. Never accept arbitrary local edits.
for relative in "${source_files[@]}"; do
    destination="$lock_root/$relative"
    [[ -f "$destination" && ! -L "$destination" ]] ||
        die "Expected a regular upstream file at $destination"
    if cmp -s "$source_root/$relative" "$destination"; then
        info "Already current: modules/lock/$relative"
        continue
    fi

    upstream_file="$(mktemp)"
    if ! git -C "$host_root" show "HEAD:modules/lock/$relative" > "$upstream_file"; then
        rm -f -- "$upstream_file"
        die "File is not tracked by the pinned Caelestia checkout: modules/lock/$relative"
    fi
    if cmp -s "$upstream_file" "$destination"; then
        info "Approved upstream baseline: modules/lock/$relative"
        rm -f -- "$upstream_file"
        continue
    fi
    rm -f -- "$upstream_file"

    legacy_hash="${legacy_deployed_sha256[$relative]:-}"
    if [[ -n $legacy_hash ]]; then
        destination_hash="$(sha256sum -- "$destination")" ||
            die "Cannot calculate SHA-256 for modules/lock/$relative"
        destination_hash="${destination_hash%% *}"
        if [[ $destination_hash == "$legacy_hash" ]]; then
            info "Recognized exact legacy K41 deployment: modules/lock/$relative ($destination_hash)"
            continue
        fi
    fi

    die "Unrecognized local modifications at modules/lock/$relative; refusing to overwrite them."
done

mkdir -p -- "$state_root"
[[ -d "$state_root" && ! -L "$state_root" && $(stat -c %u "$state_root") == "$EUID" ]] ||
    die "Unsafe backup directory: $state_root"
stamp="$(date -u +'%Y%m%dT%H%M%SZ')"
backup="$state_root/$stamp"
suffix=0
while ! mkdir -- "$backup" 2>/dev/null; do
    suffix=$((suffix + 1))
    backup="$state_root/$stamp-$suffix"
done
mkdir -p -- "$backup/center"
for relative in "${source_files[@]}"; do
    install -m 0644 -- "$lock_root/$relative" "$backup/$relative"
done
# Snapshot any pre-existing K41 mirror files before updating either location.
mkdir -p -- "$backup/mirror-legacy" "$backup/mirror-caelestia"
for relative in "${source_files[@]}"; do
    for pair in "legacy:$legacy_k41_module_root" "caelestia:$caelestia_k41_module_root"; do
        label="${pair%%:*}"
        root="${pair#*:}"
        if [[ -e "$root/$relative" || -L "$root/$relative" ]]; then
            [[ -f "$root/$relative" && ! -L "$root/$relative" ]] || die "Unsafe existing mirror file: $root/$relative"
            install -D -m 0600 -- "$root/$relative" "$backup/mirror-$label/$relative"
        fi
    done
done
printf 'Caelestia origin: %s\nCaelestia revision: %s\n' "$upstream_url" "$upstream_revision" > "$backup/manifest"
(
    cd -- "$backup"
    sha256sum "${source_files[@]}" > MANIFEST.sha256
    sha256sum -c MANIFEST.sha256
)

stage="$(mktemp -d "$lock_root/.k41-lockscreen-stage.XXXXXX")"
changed=0
restore_originals() {
    local relative label root
    for relative in "${source_files[@]}"; do
        install -m 0644 -- "$backup/$relative" "$lock_root/$relative"
        for pair in "legacy:$legacy_k41_module_root" "caelestia:$caelestia_k41_module_root"; do
            label="${pair%%:*}"
            root="${pair#*:}"
            if [[ -f "$backup/mirror-$label/$relative" ]]; then
                install -D -m 0644 -- "$backup/mirror-$label/$relative" "$root/$relative"
            else
                rm -f -- "$root/$relative"
            fi
        done
    done
}
publish_logs() {
    local remote_url publish_tmp publish_repo publish_root uploaded_log
    if [[ ${K41_LOCKSCREEN_TEST_MODE:-0} == 1 ]]; then
        info "Test mode: remote log publication intentionally skipped."
        return 0
    fi
    remote_url="$(git -C "$repo_root" remote get-url origin 2>/dev/null)" ||
        { printf 'WARNING: cannot read repository origin; deployment log remains local.\n' >&2; return 1; }
    case "$remote_url" in
        https://github.com/K41-Origin/Lenovo-ThinkPad-X280-K41|https://github.com/K41-Origin/Lenovo-ThinkPad-X280-K41.git|git@github.com:K41-Origin/Lenovo-ThinkPad-X280-K41.git|ssh://git@github.com/K41-Origin/Lenovo-ThinkPad-X280-K41.git) ;;
        *) printf 'WARNING: repository origin is not the approved K41 GitHub repository; deployment log remains local.\n' >&2; return 1 ;;
    esac

    publish_tmp="$(mktemp -d "${TMPDIR:-/tmp}/k41-lockscreen-log-publish.XXXXXX")" || return 1
    publish_repo="$publish_tmp/repository"
    cleanup_publish() {
        rm -rf -- "$publish_tmp"
    }
    info "Publishing sanitized deployment log through an independent temporary clone."
    if ! git clone --quiet --branch main --single-branch "$remote_url" "$publish_repo"; then
        cleanup_publish
        printf 'WARNING: independent clone failed; deployment log remains local.\n' >&2
        return 1
    fi

    publish_root="$publish_repo/reports/lockscreen-deployment"
    if ! mkdir -p -- "$publish_root/history"; then
        cleanup_publish
        printf 'WARNING: cannot prepare report directory; deployment log remains local.\n' >&2
        return 1
    fi
    uploaded_log="$publish_root/history/$(basename -- "$log_file")"
    if ! sed -e "s|$HOME|~|g" -e "s|$repo_root|<K41_REPO>|g" "$log_file" > "$uploaded_log"; then
        cleanup_publish
        printf 'WARNING: log sanitization failed; deployment log remains local.\n' >&2
        return 1
    fi
    chmod 0644 "$uploaded_log"
    if ! cp -- "$uploaded_log" "$publish_root/latest.log"; then
        cleanup_publish
        printf 'WARNING: could not prepare latest deployment log; local log retained.\n' >&2
        return 1
    fi
    git -C "$publish_repo" config user.name "K41 Lock Screen Deployment Logger"
    git -C "$publish_repo" config user.email "k41-lockscreen-logger@users.noreply.github.com"
    if ! git -C "$publish_repo" add -- reports/lockscreen-deployment ||
       ! git -C "$publish_repo" commit --quiet -m "Record lockscreen deployment log"; then
        cleanup_publish
        printf 'WARNING: could not commit deployment log; local log retained.\n' >&2
        return 1
    fi
    if ! git -C "$publish_repo" push origin HEAD:main; then
        info "Push raced with another main update; rebasing the isolated log commit once."
        if ! git -C "$publish_repo" fetch --quiet --no-tags origin main ||
           ! git -C "$publish_repo" rebase --quiet FETCH_HEAD ||
           ! git -C "$publish_repo" push origin HEAD:main; then
            cleanup_publish
            printf 'WARNING: GitHub log publication failed; local log retained at %s.\n' "$log_file" >&2
            return 1
        fi
    fi
    cleanup_publish
    info "Deployment log published to reports/lockscreen-deployment/ on GitHub main."
    return 0
}

cleanup() {
    local rc=$?
    trap - EXIT ERR
    [[ -z ${stage:-} || ! -d $stage ]] || rm -rf -- "$stage"
    if (( rc != 0 && changed == 1 )); then
        info "Deployment failed; restoring the four original visual files from $backup."
        if restore_originals; then
            if command -v caelestia >/dev/null 2>&1; then
                caelestia shell -r -d >/dev/null 2>&1 || printf 'WARNING: restored files, but Caelestia reload after rollback failed.\n' >&2
            fi
        else
            printf 'CRITICAL: automatic restore failed; backup remains at %s\n' "$backup" >&2
        fi
    fi
    printf 'INFO: Deployment finished with exit status %s.\n' "$rc"
    exec 1>&3 2>&4
    exec 3>&- 4>&-
    wait "$log_tee_pid" || true
    if [[ -s $log_file ]]; then
        local latest_tmp="$log_root/.latest.log.$"
        if cp -- "$log_file" "$latest_tmp" && chmod 0600 "$latest_tmp" && mv -f -- "$latest_tmp" "$log_root/latest.log"; then
            printf 'INFO: Persistent deployment log: %s\n' "$log_file"
            printf 'INFO: Latest deployment log: %s/latest.log\n' "$log_root"
        else
            rm -f -- "$latest_tmp"
            printf 'WARNING: Could not update latest.log; timestamped log remains at %s\n' "$log_file" >&2
        fi
        if ! publish_logs; then
            printf 'WARNING: sanitized deployment log could not be published; deployment result is unchanged.\n' >&2
        fi
    fi
    exit "$rc"
}
trap cleanup EXIT

mkdir -p -- "$stage/center"
for relative in "${source_files[@]}"; do
    install -m 0644 -- "$source_root/$relative" "$stage/$relative"
    cmp -s "$source_root/$relative" "$stage/$relative" ||
        die "Staging verification failed: $relative"
done
(
    cd -- "$stage"
    sha256sum "${source_files[@]}" > MANIFEST.sha256
    sha256sum -c MANIFEST.sha256
)

changed=1
for relative in "${source_files[@]}"; do
    mv -f -- "$stage/$relative" "$lock_root/$relative"
done
# Mirror the exact four visual sources into both K41 module namespaces.
mkdir -p -- "$legacy_k41_module_root/center" "$caelestia_k41_module_root/center"
for relative in "${source_files[@]}"; do
    install -D -m 0644 -- "$source_root/$relative" "$legacy_k41_module_root/$relative"
    install -D -m 0644 -- "$source_root/$relative" "$caelestia_k41_module_root/$relative"
done
for relative in "${source_files[@]}"; do
    cmp -s "$source_root/$relative" "$lock_root/$relative" ||
        die "Post-deployment verification failed: Caelestia overlay $relative"
    cmp -s "$source_root/$relative" "$legacy_k41_module_root/$relative" ||
        die "Post-deployment verification failed: legacy K41 mirror $relative"
    cmp -s "$source_root/$relative" "$caelestia_k41_module_root/$relative" ||
        die "Post-deployment verification failed: Caelestia K41 mirror $relative"
done
rm -rf -- "$stage"
stage=""

info "K41 Floating Password Card overlay deployed into Caelestia modules/lock/."
info "Four visual source files mirrored to: $legacy_k41_module_root and $caelestia_k41_module_root"
info "Original files backed up to: $backup"
info "Restarting Caelestia shell to activate the new QML."
if ! caelestia shell -r -d; then
    die "Caelestia reload command failed; original QML files will be restored."
fi
changed=0
info "Caelestia reload command completed. The new visual source is now selected by the existing modules/lock import."
info "Authentication, PAM, Lock.qml, session-lock protocol, Hyprland configuration, and system services were not changed."
info "Visual acceptance still requires observing a real lock/unlock cycle on the ThinkPad X280."
