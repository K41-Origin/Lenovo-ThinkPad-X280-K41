#!/usr/bin/env bash
# Deploy a pinned, user-local Caelestia source tree with the K41 lock layout.
set -Eeuo pipefail
umask 077

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
info() { printf 'INFO: %s\n' "$*"; }
usage() {
    printf 'Usage:\n  sudo bash %s\n  sudo bash %s --rollback BACKUP_DIRECTORY\n' "$0" "$0"
}

readonly UPSTREAM_REPO="https://github.com/caelestia-dots/shell.git"
readonly UPSTREAM_REVISION="d999d4878ee4cec134168e60d913714566a8cfa6"
readonly EXPECTED_PACKAGE_VERSION="2.5.0-1"

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd -- "$script_dir/.." && pwd -P)"
source_root="$repo_root/config/quickshell/caelestia/modules/lock"

# Require sudo at entry, then drop privileges before touching user files.
if [[ $EUID -eq 0 ]]; then
    [[ -n ${SUDO_USER:-} && $SUDO_USER != root ]] ||
        die 'Run with sudo from your regular desktop account.'
    command -v runuser >/dev/null 2>&1 || die 'runuser is required.'
    command -v getent >/dev/null 2>&1 || die 'getent is required.'
    passwd_entry="$(getent passwd "$SUDO_USER")" || die "Cannot resolve sudo user: $SUDO_USER"
    IFS=: read -r _ _ target_uid _ _ target_home _ <<<"$passwd_entry"
    [[ $target_uid =~ ^[0-9]+$ && $target_uid -ne 0 && $target_home == /* ]] ||
        die 'Could not safely resolve a non-root user.'

    command -v install >/dev/null 2>&1 || die 'install command is required.'
    target_config="$target_home/.config/quickshell/caelestia"
    target_state="$target_home/.local/state/k41/lockscreen/backups"
    for path in "$target_config" "$target_state"; do
        current=
        IFS=/ read -r -a parts <<<"$path"
        for part in "${parts[@]}"; do
            [[ -z $part ]] && continue
            current="$current/$part"
            [[ ! -L $current ]] || die "Refusing symlink path component: $current"
        done
    done
    target_gid="$(id -g "$SUDO_USER")"
    install -d -o "$target_uid" -g "$target_gid" -- "$target_config" "$target_state"
    chown "$target_uid:$target_gid" -- "$target_config" "$target_state"

    exec runuser --user "$SUDO_USER" -- env \
        HOME="$target_home" \
        XDG_CONFIG_HOME="$target_home/.config" \
        XDG_STATE_HOME="$target_home/.local/state" \
        K41_SUDO_REEXEC=1 \
        bash "$0" "$@"
fi

[[ ${K41_SUDO_REEXEC:-} == 1 && $EUID -ne 0 ]] ||
    die 'This installer must be started with sudo from the regular desktop account.'

log_dir="$repo_root/reports/lockscreen-apply"
for path in "$repo_root/reports" "$log_dir"; do
    current=
    IFS=/ read -r -a parts <<<"$path"
    for part in "${parts[@]}"; do
        [[ -z $part ]] && continue
        current="$current/$part"
        [[ ! -L $current ]] || die "Refusing symlink report path component: $current"
    done
done
mkdir -p -- "$log_dir"
[[ -d $log_dir && ! -L $log_dir && -w $log_dir ]] || die "Unsafe or unwritable report directory: $log_dir"
[[ $(stat -c %u "$repo_root") == "$EUID" ]] || die "Repository checkout is not owned by the invoking user: $repo_root"
log_file="$log_dir/$(date -u +'%Y%m%dT%H%M%SZ')-apply.log"
[[ ! -e $log_file && ! -L $log_file ]] || die "Refusing to overwrite report: $log_file"
: > "$log_file"
exec > >(tee -a "$log_file") 2>&1

finish_log() {
    local rc=$1
    printf '\n========== EXECUTION SUMMARY ==========\n'
    printf 'Finished : %s\n' "$(date --iso-8601=seconds)"
    printf 'Exit code: %s\n' "$rc"
    (( rc == 0 )) && printf 'Result   : SUCCESS\n' || printf 'Result   : FAILED\n'
    printf 'Log file : %s\n' "$log_file"
}
trap 'finish_log "$?"' EXIT

printf '========== K41 LOCKSCREEN SOURCE DEPLOYMENT ==========\n'
printf 'User     : %s (UID %s)\n' "$USER" "$EUID"
printf 'Repo     : %s\n' "$repo_root"
printf 'Report   : %s\n' "$log_file"

config_root="${XDG_CONFIG_HOME:-$HOME/.config}"
state_root="${XDG_STATE_HOME:-$HOME/.local/state}"
target_root="$config_root/quickshell/caelestia"
backup_root="$state_root/k41/lockscreen/backups"
mode=apply
rollback_dir=""
if [[ ${1:-} == --rollback ]]; then
    [[ $# -eq 2 ]] || { usage >&2; exit 2; }
    mode=rollback
    rollback_dir=$2
elif [[ $# -ne 0 ]]; then
    usage >&2
    exit 2
fi

[[ $config_root == "$HOME/.config" && $state_root == "$HOME/.local/state" ]] ||
    die 'Unexpected XDG paths; this installer targets the invoking user home.'
[[ -d $target_root && ! -L $target_root ]] || die "Invalid target directory: $target_root"
[[ -d $backup_root && ! -L $backup_root ]] || die "Invalid backup directory: $backup_root"
[[ $(stat -c %u "$target_root") == "$EUID" ]] || die "Target directory is not owned by $USER."
[[ $(stat -c %u "$backup_root") == "$EUID" ]] || die "Backup directory is not owned by $USER."
[[ -x $config_root && -x $config_root/quickshell && -x $state_root && -x $state_root/k41 && -x $state_root/k41/lockscreen ]] ||
    die 'A parent directory is not traversable; inspect ownership and mode before proceeding.'
for path in "$config_root" "$config_root/quickshell" "$target_root" "$state_root" "$backup_root"; do
    current=
    IFS=/ read -r -a parts <<<"$path"
    for part in "${parts[@]}"; do
        [[ -z $part ]] && continue
        current="$current/$part"
        [[ ! -L $current ]] || die "Refusing symlink path component: $current"
    done
done

for cmd in git pacman stat find cmp cp mv mkdir mktemp date rm tee; do
    command -v "$cmd" >/dev/null 2>&1 || die "Required command not found: $cmd"
done
for name in Content.qml Center.qml; do
    [[ -s $source_root/$name && ! -L $source_root/$name ]] || die "Override source missing or unsafe: $name"
done

if [[ $mode == rollback ]]; then
    [[ -d $rollback_dir && ! -L $rollback_dir && -d $rollback_dir/preexisting && ! -L $rollback_dir/preexisting ]] ||
        die 'Backup is invalid or does not contain the original user configuration.'
    [[ $rollback_dir == "$backup_root/"* ]] || die 'Backup is outside the managed backup root.'
    [[ $(stat -c %u "$rollback_dir") == "$EUID" ]] || die 'Backup must be owned by the current user.'
    [[ $(git -C "$target_root" rev-parse HEAD 2>/dev/null) == "$UPSTREAM_REVISION" ]] ||
        die 'Current local shell is not the managed pinned checkout; refusing destructive rollback.'
    cmp -s "$target_root/modules/lock/Content.qml" "$source_root/Content.qml" ||
        die 'Content.qml has local changes; refusing destructive rollback.'
    cmp -s "$target_root/modules/lock/Center.qml" "$source_root/Center.qml" ||
        die 'Center.qml has local changes; refusing destructive rollback.'
    git -C "$target_root" diff --quiet -- . ':!modules/lock/Content.qml' ':!modules/lock/Center.qml' ||
        die 'Other tracked source files have local changes; refusing destructive rollback.'
    [[ -z $(git -C "$target_root" ls-files --others --exclude-standard) ]] ||
        die 'Untracked files exist in the local shell tree; refusing destructive rollback.'
    rm -rf -- "$target_root"
    cp -a -- "$rollback_dir/preexisting" "$target_root"
    info "Rollback restored the exact pre-install user directory from $rollback_dir."
    exit 0
fi

package_line="$(pacman -Q caelestia-shell 2>/dev/null)" || die 'caelestia-shell package is not installed.'
package_version="${package_line#* }"
[[ $package_version == "$EXPECTED_PACKAGE_VERSION" ]] ||
    die "Installed caelestia-shell is $package_version; this source overlay is pinned for $EXPECTED_PACKAGE_VERSION. Re-audit upstream compatibility before proceeding."

# An existing local source tree is accepted only if it is exactly this managed
# deployment. Never merge over unknown user QML or silently overwrite changes.
if [[ -f $target_root/shell.qml ]]; then
    [[ $(git -C "$target_root" rev-parse HEAD 2>/dev/null || true) == "$UPSTREAM_REVISION" ]] ||
        die 'A shell.qml already exists but is not the expected pinned upstream checkout; inspect it before replacing anything.'
    cmp -s "$target_root/modules/lock/Content.qml" "$source_root/Content.qml" &&
        cmp -s "$target_root/modules/lock/Center.qml" "$source_root/Center.qml" ||
        die 'The existing local shell has different lock overrides; refusing to overwrite local work.'
    info 'The pinned local Caelestia source and K41 lock overrides are already installed; no files changed.'
    exit 0
fi

# The previous installer created only these two inert files. Refuse to replace
# any other local content because it may be unrelated user work.
while IFS= read -r -d '' file; do
    rel="${file#"$target_root"/}"
    case "$rel" in
        modules/lock/Content.qml|modules/lock/Center.qml) ;;
        *) die "Unexpected pre-existing user file: $rel. Preserve/review it before deployment." ;;
    esac
done < <(find "$target_root" -type f -print0)
while IFS= read -r -d '' link; do
    die "Symlink found in existing user shell tree: $link"
done < <(find "$target_root" -type l -print0)

stamp="$(date -u +'%Y%m%dT%H%M%SZ')"
backup_dir="$backup_root/$stamp"
suffix=0
while ! mkdir -- "$backup_dir" 2>/dev/null; do
    suffix=$((suffix + 1))
    backup_dir="$backup_root/$stamp-$suffix"
done
cp -a -- "$target_root" "$backup_dir/preexisting"
printf 'Upstream repository: %s\nUpstream revision: %s\nPackage version: %s\n' \
    "$UPSTREAM_REPO" "$UPSTREAM_REVISION" "$package_version" > "$backup_dir/manifest"

staging="$(mktemp -d "$config_root/quickshell/.k41-caelestia-stage.XXXXXX")"
old_root="$config_root/quickshell/.k41-caelestia-old-$stamp"
[[ ! -e $old_root && ! -L $old_root ]] || die "Refusing existing deployment staging path: $old_root"
replace_started=0
cleanup() {
    local rc=$?
    trap - EXIT
    if (( rc != 0 && replace_started == 1 )); then
        info 'Deployment failed after replacement began; restoring the previous user shell directory.'
        rm -rf -- "$target_root"
        if [[ -d $old_root ]]; then
            mv -- "$old_root" "$target_root"
        elif [[ -d $backup_dir/preexisting ]]; then
            cp -a -- "$backup_dir/preexisting" "$target_root"
        fi
    fi
    [[ -z $staging || ! -d $staging ]] || rm -rf -- "$staging"
    finish_log "$rc"
    exit "$rc"
}
trap cleanup EXIT

git -C "$staging" init --quiet
git -C "$staging" remote add origin "$UPSTREAM_REPO"
info "Fetching audited upstream revision $UPSTREAM_REVISION."
git -C "$staging" fetch --quiet --depth 1 origin "$UPSTREAM_REVISION"
git -C "$staging" checkout --quiet --detach FETCH_HEAD
[[ $(git -C "$staging" rev-parse HEAD) == "$UPSTREAM_REVISION" ]] ||
    die 'Fetched upstream revision does not match the audited revision.'
for required in shell.qml modules/lock/Lock.qml modules/lock/LockSurface.qml modules/lock/Content.qml modules/lock/Center.qml; do
    [[ -s $staging/$required && ! -L $staging/$required ]] || die "Upstream source is missing required file: $required"
done

cp -- "$source_root/Content.qml" "$staging/modules/lock/Content.qml"
cp -- "$source_root/Center.qml" "$staging/modules/lock/Center.qml"
cmp -s "$staging/modules/lock/Content.qml" "$source_root/Content.qml" || die 'Content override verification failed.'
cmp -s "$staging/modules/lock/Center.qml" "$source_root/Center.qml" || die 'Center override verification failed.'

info 'Complete upstream QML source tree fetched and pinned; K41 lock overrides applied.'
info 'This fixes the previous inert two-file directory: the local shell.qml is now present, so Quickshell can resolve the user-local config instead of falling back to /etc/xdg.'
printf 'Backup: %s\n' "$backup_dir"
printf 'Install local source tree at: %s\n' "$target_root"
printf 'Apply this complete source tree? [y/N] '
IFS= read -r answer
[[ $answer =~ ^[Yy]([Ee][Ss])?$ ]] || die 'Cancelled; active configuration remains unchanged and backup is retained.'

replace_started=1
mv -- "$target_root" "$old_root"
mv -- "$staging" "$target_root"
staging=""
rm -rf -- "$old_root"
replace_started=0

info 'Complete pinned Caelestia source tree installed under the user config directory.'
info 'The package-managed /etc/xdg tree, PAM, authentication, Hyprland configuration, and system services were not modified.'
info 'Restart from the active Hyprland terminal as the regular user: caelestia shell -r -d'
info 'Then confirm the restart log names ~/.config/quickshell/caelestia/shell.qml, not /etc/xdg/quickshell/caelestia/shell.qml.'
info "Rollback: sudo bash scripts/k41-apply-lockscreen-design.sh --rollback '$backup_dir'"
info 'No visual/runtime acceptance is claimed until lock/unlock and visual checks pass on the X280.'
