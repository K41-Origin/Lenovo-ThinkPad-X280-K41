#!/usr/bin/env bash
# Install/rollback the K41 Caelestia lock-screen QML overrides for the regular user.
set -Eeuo pipefail
umask 077

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
info() { printf 'INFO: %s\n' "$*"; }
usage() {
    printf 'Usage:\n  bash %s [--no-restart]\n  bash %s --rollback BACKUP_DIRECTORY\n' "$0" "$0"
}

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd -- "$script_dir/.." && pwd -P)"
source_root="$repo_root/config/quickshell/caelestia/modules/lock"

# Require sudo at entry, then drop privileges before touching user files.
# All config/backup writes run as SUDO_USER, never as root.
if [[ $EUID -eq 0 ]]; then
    [[ -n ${SUDO_USER:-} && $SUDO_USER != root ]] ||
        die 'Run with sudo from your regular desktop account (sudo bash scripts/k41-apply-lockscreen-design.sh).'
    command -v runuser >/dev/null 2>&1 || die 'runuser is required (provided by util-linux).'
    command -v getent >/dev/null 2>&1 || die 'getent is required to resolve the invoking user.'
    passwd_entry="$(getent passwd "$SUDO_USER")" || die "Cannot resolve sudo user: $SUDO_USER"
    IFS=: read -r _ _ target_uid _ _ target_home _ <<<"$passwd_entry"
    [[ $target_uid =~ ^[0-9]+$ && $target_uid -ne 0 && $target_home == /* ]] ||
        die 'Could not safely resolve a non-root user home directory.'

    # Bootstrap only the two managed leaf directories as root, then hand
    # ownership of those leaves to the desktop user. Do not chown ~/.config,
    # ~/.local, or any existing parent tree.
    command -v install >/dev/null 2>&1 || die 'install command is required.'
    target_config="$target_home/.config/quickshell/caelestia/modules/lock"
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
    install -d -o "$target_uid" -g "$(id -g "$SUDO_USER")" -- "$target_config" "$target_state"
    chown "$target_uid:$(id -g "$SUDO_USER")" -- "$target_config" "$target_state"

    exec runuser --user "$SUDO_USER" -- env \
        HOME="$target_home" \
        XDG_CONFIG_HOME="$target_home/.config" \
        XDG_STATE_HOME="$target_home/.local/state" \
        K41_SUDO_REEXEC=1 \
        bash "$0" "$@"
fi

[[ ${K41_SUDO_REEXEC:-} == 1 ]] || die 'This installer must be started with sudo.'
config_root="${XDG_CONFIG_HOME:-$HOME/.config}"
state_root="${XDG_STATE_HOME:-$HOME/.local/state}"
target_root="$config_root/quickshell/caelestia/modules/lock"
backup_root="$state_root/k41/lockscreen/backups"
mode=apply
restart=ask
rollback_dir=""

if [[ ${1:-} == --rollback ]]; then
    [[ $# -eq 2 ]] || { usage >&2; exit 2; }
    mode=rollback
    rollback_dir=$2
elif [[ ${1:-} == --no-restart ]]; then
    [[ $# -eq 1 ]] || { usage >&2; exit 2; }
    restart=no
elif [[ $# -ne 0 ]]; then
    usage >&2
    exit 2
fi

[[ $EUID -ne 0 ]] || die 'Refusing to perform user-file operations as root.'
[[ $config_root == "$HOME/.config" && $state_root == "$HOME/.local/state" ]] ||
    die 'Unexpected XDG path; this sudo installer intentionally targets the invoking user home.'
[[ -d $target_root && ! -L $target_root ]] || die "Invalid target directory: $target_root"
[[ -d $backup_root && ! -L $backup_root ]] || die "Invalid backup directory: $backup_root"
[[ $(stat -c %u "$target_root") == "$EUID" ]] ||
    die "Managed lock directory is not owned by the invoking user: $target_root"
[[ $(stat -c %u "$backup_root") == "$EUID" ]] ||
    die "Managed backup directory is not owned by the invoking user: $backup_root"
[[ -x $config_root && -x $config_root/quickshell && -x $config_root/quickshell/caelestia && -x $config_root/quickshell/caelestia/modules ]] ||
    die "A parent directory in the config path is not traversable by $USER; inspect ownership/mode before proceeding."
[[ -x $state_root && -x $state_root/k41 && -x $state_root/k41/lockscreen ]] ||
    die "A parent directory in the backup path is not traversable by $USER; inspect ownership/mode before proceeding."
[[ $config_root == /* && $state_root == /* ]] || die 'XDG_CONFIG_HOME and XDG_STATE_HOME must be absolute paths.'
for cmd in mkdir cp mv mktemp date pacman stat rm chmod; do
    command -v "$cmd" >/dev/null 2>&1 || die "Required command not found: $cmd"
done
pacman -Q caelestia-shell >/dev/null 2>&1 || die 'caelestia-shell package is not installed.'
[[ -f /etc/xdg/quickshell/caelestia/modules/lock/Content.qml ]] ||
    die 'Expected upstream Caelestia QML package layout is missing; refusing to install overrides.'
for name in Content.qml Center.qml; do
    [[ -f $source_root/$name && ! -L $source_root/$name ]] || die "Override source is missing or unsafe: $name"
done

check_path_components() {
    local path=$1 current=
    IFS=/ read -r -a parts <<<"$path"
    for part in "${parts[@]}"; do
        [[ -z $part ]] && continue
        current="$current/$part"
        [[ ! -L $current ]] || die "Refusing symlink path component: $current"
    done
}
check_path_components "$config_root"
check_path_components "$config_root/quickshell"
check_path_components "$config_root/quickshell/caelestia"
check_path_components "$config_root/quickshell/caelestia/modules"
check_path_components "$target_root"
check_path_components "$state_root"
check_path_components "$backup_root"

if [[ $mode == rollback ]]; then
    [[ -d $rollback_dir && ! -L $rollback_dir && -f $rollback_dir/manifest ]] ||
        die 'Invalid backup directory or missing manifest.'
    [[ $rollback_dir == "$backup_root/"* ]] || die 'Backup is outside the managed K41 backup root.'
    [[ $(stat -c %u "$rollback_dir") == "$EUID" ]] || die 'Backup must be owned by the current user.'
    while IFS=' ' read -r state name; do
        case "$name" in Content.qml|Center.qml) ;; *) die "Unexpected manifest entry: $name" ;; esac
        target="$target_root/$name"
        case "$state" in
            present)
                [[ -f $rollback_dir/files/$name && ! -L $rollback_dir/files/$name ]] ||
                    die "Backup file missing or unsafe: $name"
                mkdir -p -- "$target_root"
                tmp="$(mktemp "$target_root/.k41-rollback.XXXXXX")"
                cp -- "$rollback_dir/files/$name" "$tmp"
                if [[ -e $target ]]; then chmod --reference="$target" "$tmp"; fi
                mv -f -- "$tmp" "$target"
                ;;
            absent) rm -f -- "$target" ;;
            *) die "Invalid backup state for $name" ;;
        esac
    done < "$rollback_dir/manifest"
    info 'Rollback complete. Restart Caelestia or log out/in to reload the original layout.'
    exit 0
fi

mkdir -p -- "$target_root" "$backup_root"
stamp="$(date -u +'%Y%m%dT%H%M%SZ')"
backup_dir="$backup_root/$stamp"
suffix=0
while ! mkdir -- "$backup_dir" 2>/dev/null; do
    suffix=$((suffix + 1))
    backup_dir="$backup_root/$stamp-$suffix"
done
mkdir -p -- "$backup_dir/files"
restore_on_failure=0
restore_backup() {
    local rc=$? state name target tmp
    trap - EXIT
    if (( rc != 0 && restore_on_failure == 1 )); then
        info "Installation failed; restoring previous override state from $backup_dir."
        while IFS=' ' read -r state name; do
            target="$target_root/$name"
            if [[ $state == present && -f $backup_dir/files/$name ]]; then
                tmp="$(mktemp "$target_root/.k41-recovery.XXXXXX")"
                cp -- "$backup_dir/files/$name" "$tmp"
                mv -f -- "$tmp" "$target"
            elif [[ $state == absent ]]; then
                rm -f -- "$target"
            fi
        done < "$backup_dir/manifest"
    fi
    exit "$rc"
}
trap restore_backup EXIT

for name in Content.qml Center.qml; do
    target="$target_root/$name"
    if [[ -L $target || ( -e $target && ! -f $target ) ]]; then
        die "Refusing non-regular override target: $target"
    fi
    if [[ -f $target ]]; then
        printf 'present %s\n' "$name" >> "$backup_dir/manifest"
        cp -a -- "$target" "$backup_dir/files/$name"
    else
        printf 'absent %s\n' "$name" >> "$backup_dir/manifest"
    fi
done

printf 'This installs two user-level QML overrides only. No package, PAM, authentication, system service, or upstream file is changed.\n'
printf 'Backup: %s\n' "$backup_dir"
printf 'Apply K41 minimal Floating Password Card layout? [y/N] '
IFS= read -r answer
[[ $answer =~ ^[Yy]([Ee][Ss])?$ ]] || die 'Cancelled; backup retained and active configuration unchanged.'

restore_on_failure=1
for name in Content.qml Center.qml; do
    tmp="$(mktemp "$target_root/.k41-install.XXXXXX")"
    cp -- "$source_root/$name" "$tmp"
    if [[ -e $target_root/$name ]]; then chmod --reference="$target_root/$name" "$tmp"; fi
    mv -f -- "$tmp" "$target_root/$name"
done
restore_on_failure=0

info "QML overrides installed for user $USER under $config_root/quickshell/caelestia/modules/lock/."
info 'Upstream LockSurface.qml, wallpaper selection/blur, WlSessionLock and PAM components remain untouched.'
info "Rollback: bash scripts/k41-apply-lockscreen-design.sh --rollback '$backup_dir'"

if [[ $restart == ask ]]; then
    printf 'Restart the running Caelestia shell now? This briefly closes/reloads shell widgets. [y/N] '
    IFS= read -r restart_answer
    if [[ $restart_answer =~ ^[Yy]([Ee][Ss])?$ ]]; then
        if command -v timeout >/dev/null 2>&1 && command -v caelestia >/dev/null 2>&1; then
            if timeout 15s caelestia shell -r -d; then
                info 'Restart command returned successfully; inspect the lock screen and runtime log.'
            else
                info 'WARNING: restart command failed or timed out; overrides remain installed. Log out/in or rollback.'
            fi
        else
            info 'WARNING: timeout/caelestia CLI unavailable; log out/in to load the overrides.'
        fi
    else
        info 'Restart skipped. Log out/in or restart Caelestia when ready.'
    fi
fi

info 'No visual/runtime acceptance is claimed until lock/unlock and visual checks pass on the X280.'
