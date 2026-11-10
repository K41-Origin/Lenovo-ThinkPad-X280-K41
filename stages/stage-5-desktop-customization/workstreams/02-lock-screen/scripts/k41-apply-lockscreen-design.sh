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
repo_root="$(cd -- "$script_dir/../../../../.." && pwd -P)"
source_root="$repo_root/stages/stage-5-desktop-customization/workstreams/02-lock-screen/k41-dots/modules/lock"

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

    # Repair only the exact legacy tree created by the earlier sudo-based
    # deployment. Every path and owner is checked before these three
    # directory entries are changed; never recurse into user files.
    target_parent="$target_home/.config/quickshell"
    if [[ -d $target_config && $(stat -c %u "$target_config") != "$target_uid" ]]; then
        [[ -d $target_parent && ! -L $target_parent && $(stat -c %u "$target_parent") == 0 ]] ||
            die "Unexpected owner/layout at $target_parent; refusing automatic repair."
        [[ $(stat -c %u "$target_config") == 0 &&
           -d $target_config/modules && ! -L $target_config/modules &&
           $(stat -c %u "$target_config/modules") == 0 &&
           -d $target_config/modules/lock && ! -L $target_config/modules/lock &&
           $(stat -c %u "$target_config/modules/lock") == "$target_uid" ]] ||
            die "Legacy lockscreen tree does not match the audited root-owned layout: $target_config"
        [[ ! -L $target_config/modules/lock/Content.qml &&
           ! -L $target_config/modules/lock/Center.qml &&
           -f $target_config/modules/lock/Content.qml &&
           -f $target_config/modules/lock/Center.qml &&
           $(stat -c %u "$target_config/modules/lock/Content.qml") == "$target_uid" &&
           $(stat -c %u "$target_config/modules/lock/Center.qml") == "$target_uid" ]] ||
            die "Legacy lock override files have unexpected type/owner: $target_config/modules/lock"
        mapfile -t legacy_entries < <(find "$target_config" -mindepth 1 -printf '%P\n' | LC_ALL=C sort)
        expected_entries=(
            modules
            modules/lock
            modules/lock/Center.qml
            modules/lock/Content.qml
        )
        [[ "${legacy_entries[*]}" == "${expected_entries[*]}" ]] ||
            die "Legacy tree contains additional content; refusing ownership repair: $target_config"
        info "Repairing verified legacy directory ownership (non-recursive): $target_parent, $target_config, and $target_config/modules."
        chown "$target_uid:$target_gid" -- "$target_parent" "$target_config" "$target_config/modules"
    fi

    for path in "$target_config" "$target_state"; do
        if [[ -e $path && ! -d $path ]]; then
            die "Managed path exists but is not a directory: $path"
        fi
        if [[ ! -d $path ]]; then
            install -d -o "$target_uid" -g "$target_gid" -- "$path"
        else
            [[ $(stat -c %u "$path") == "$target_uid" ]] ||
                die "Existing managed directory has unexpected owner; inspect manually: $path"
        fi
    done

    exec runuser --user "$SUDO_USER" -- env \
        HOME="$target_home" \
        XDG_CONFIG_HOME="$target_home/.config" \
        XDG_STATE_HOME="$target_home/.local/state" \
        K41_SUDO_REEXEC=1 \
        bash "$0" "$@"
fi

[[ ${K41_SUDO_REEXEC:-} == 1 && $EUID -ne 0 ]] ||
    die 'This installer must be started with sudo from the regular desktop account.'

log_dir="$repo_root/reports/stage-5-desktop-customization/02-lock-screen/lockscreen-apply"
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
info "K41-Dots canonical source: $source_root"

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
password_override="$source_root/center/PasswordInput.qml"
locksurface_override="$source_root/LockSurface.qml"
[[ -s $password_override && ! -L $password_override ]] || die 'PasswordInput override source missing or unsafe.'
[[ -s $locksurface_override && ! -L $locksurface_override ]] || die 'LockSurface override source missing or unsafe.'

if [[ $mode == rollback ]]; then
    [[ -d $rollback_dir && ! -L $rollback_dir && -d $rollback_dir/preexisting && ! -L $rollback_dir/preexisting ]] ||
        die 'Backup is invalid or does not contain the original user configuration.'
    [[ $rollback_dir == "$backup_root/"* ]] || die 'Backup is outside the managed backup root.'
    [[ $(stat -c %u "$rollback_dir") == "$EUID" ]] || die 'Backup must be owned by the current user.'
    [[ $(git -C "$target_root" rev-parse HEAD 2>/dev/null) == "$UPSTREAM_REVISION" ]] ||
        die 'Current local shell is not the managed pinned checkout; refusing destructive rollback.'
    [[ $(git -C "$target_root" remote get-url origin 2>/dev/null) == "$UPSTREAM_REPO" ]] ||
        die 'Current local shell has an unexpected upstream remote; refusing destructive rollback.'
    cmp -s "$target_root/modules/lock/Content.qml" "$source_root/Content.qml" ||
        die 'Content.qml has local changes; refusing destructive rollback.'
    cmp -s "$target_root/modules/lock/Center.qml" "$source_root/Center.qml" ||
        die 'Center.qml has local changes; refusing destructive rollback.'
    cmp -s "$target_root/modules/lock/center/PasswordInput.qml" "$password_override" ||
        die 'PasswordInput.qml has local changes; refusing destructive rollback.'
    cmp -s "$target_root/modules/lock/LockSurface.qml" "$locksurface_override" ||
        die 'LockSurface.qml has local changes; refusing destructive rollback.'
    git -C "$target_root" diff --quiet -- . ':!modules/lock/Content.qml' ':!modules/lock/Center.qml' ':!modules/lock/center/PasswordInput.qml' ':!modules/lock/LockSurface.qml' ||
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
    [[ $(git -C "$target_root" remote get-url origin 2>/dev/null || true) == "$UPSTREAM_REPO" ]] ||
        die 'The existing local shell has an unexpected upstream remote; refusing to modify it.'
    git -C "$target_root" diff --quiet -- . ':!modules/lock/Content.qml' ':!modules/lock/Center.qml' ':!modules/lock/center/PasswordInput.qml' ':!modules/lock/LockSurface.qml' ||
        die 'Other tracked source files have local changes; refusing to overwrite local work.'
    [[ -z $(git -C "$target_root" ls-files --others --exclude-standard) ]] ||
        die 'Untracked files exist in the local shell tree; refusing to overwrite local work.'
    [[ -d $target_root/modules/lock/center && ! -L $target_root/modules/lock/center &&
       -f $target_root/modules/lock/Content.qml && ! -L $target_root/modules/lock/Content.qml &&
       -f $target_root/modules/lock/Center.qml && ! -L $target_root/modules/lock/Center.qml &&
       -f $target_root/modules/lock/center/PasswordInput.qml && ! -L $target_root/modules/lock/center/PasswordInput.qml &&
       -f $target_root/modules/lock/LockSurface.qml && ! -L $target_root/modules/lock/LockSurface.qml ]] ||
        die 'One or more managed lock override targets are missing; inspect the local shell tree.'
    if cmp -s "$target_root/modules/lock/Content.qml" "$source_root/Content.qml" &&
       cmp -s "$target_root/modules/lock/Center.qml" "$source_root/Center.qml" &&
       cmp -s "$target_root/modules/lock/center/PasswordInput.qml" "$password_override" &&
       cmp -s "$target_root/modules/lock/LockSurface.qml" "$locksurface_override"; then
        info 'The pinned local Caelestia source and all K41 lock overrides are already installed; no files changed.'
        exit 0
    fi
    stamp="$(date -u +'%Y%m%dT%H%M%SZ')"
    update_backup="$backup_root/$stamp-overlay-update"
    suffix=0
    while ! mkdir -- "$update_backup" 2>/dev/null; do
        suffix=$((suffix + 1))
        update_backup="$backup_root/$stamp-overlay-update-$suffix"
    done
    cp -a -- "$target_root/modules/lock/Content.qml" "$target_root/modules/lock/Center.qml" "$update_backup/"
    mkdir -- "$update_backup/center"
    cp -a -- "$target_root/modules/lock/center/PasswordInput.qml" "$update_backup/center/"
    cp -a -- "$target_root/modules/lock/LockSurface.qml" "$update_backup/"
    printf 'Upstream revision: %s\nOverlay update backup for existing managed source tree.\n' "$UPSTREAM_REVISION" > "$update_backup/manifest"
    cp -- "$source_root/Content.qml" "$target_root/modules/lock/Content.qml"
    cp -- "$source_root/Center.qml" "$target_root/modules/lock/Center.qml"
    cp -- "$password_override" "$target_root/modules/lock/center/PasswordInput.qml"
    cp -- "$locksurface_override" "$target_root/modules/lock/LockSurface.qml"
    cmp -s "$target_root/modules/lock/Content.qml" "$source_root/Content.qml" &&
        cmp -s "$target_root/modules/lock/Center.qml" "$source_root/Center.qml" &&
        cmp -s "$target_root/modules/lock/center/PasswordInput.qml" "$password_override" &&
        cmp -s "$target_root/modules/lock/LockSurface.qml" "$locksurface_override" ||
        die 'Lock override deployment verification failed; restore from the reported overlay backup.'
    info "Updated K41 lock overrides in the pinned local source tree. Backup: $update_backup"
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
while IFS= read -r -d '' dir; do
    rel="${dir#"$target_root"/}"
    case "$rel" in modules|modules/lock) ;; *) die "Unexpected pre-existing user directory: $rel" ;; esac
done < <(find "$target_root" -mindepth 1 -type d -print0)

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
for required in shell.qml modules/lock/Lock.qml modules/lock/LockSurface.qml modules/lock/Content.qml modules/lock/Center.qml modules/lock/center/PasswordInput.qml; do
    [[ -s $staging/$required && ! -L $staging/$required ]] || die "Upstream source is missing required file: $required"
done

cp -- "$source_root/Content.qml" "$staging/modules/lock/Content.qml"
cp -- "$source_root/Center.qml" "$staging/modules/lock/Center.qml"
cp -- "$password_override" "$staging/modules/lock/center/PasswordInput.qml"
cp -- "$locksurface_override" "$staging/modules/lock/LockSurface.qml"
cmp -s "$staging/modules/lock/Content.qml" "$source_root/Content.qml" || die 'Content override verification failed.'
cmp -s "$staging/modules/lock/Center.qml" "$source_root/Center.qml" || die 'Center override verification failed.'
cmp -s "$staging/modules/lock/center/PasswordInput.qml" "$password_override" || die 'PasswordInput override verification failed.'
cmp -s "$staging/modules/lock/LockSurface.qml" "$locksurface_override" || die 'LockSurface override verification failed.'

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
info "Rollback: sudo bash stages/stage-5-desktop-customization/workstreams/02-lock-screen/scripts/k41-apply-lockscreen-design.sh --rollback '$backup_dir'"
info 'No visual/runtime acceptance is claimed until lock/unlock and visual checks pass on the X280.'
