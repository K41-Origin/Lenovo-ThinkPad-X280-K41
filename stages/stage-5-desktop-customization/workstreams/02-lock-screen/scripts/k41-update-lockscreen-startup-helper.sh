#!/usr/bin/env bash
# Safely update the user-local Caelestia lock startup helper from Workstream 02.
# The existing helper is backed up before the single user-local executable is replaced.
set -Eeuo pipefail
umask 077

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
info() { printf 'INFO: %s\n' "$*"; }

(( EUID != 0 )) || die 'Run as the regular desktop user, never with sudo.'
[[ $# -eq 0 ]] || die 'This updater takes no arguments.'
[[ -n ${HOME:-} && $HOME == /* && -d $HOME ]] || die 'HOME is missing or invalid.'

for command_name in git stat date mkdir cp chmod install bash mktemp mv cmp sha256sum; do
    command -v "$command_name" >/dev/null 2>&1 || die "Required command is unavailable: $command_name"
done

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(git -C "$script_dir" rev-parse --show-toplevel 2>/dev/null)" ||
    die 'Run this updater from a Git checkout.'
repo_root="$(cd -- "$repo_root" && pwd -P)"
[[ $(git -C "$repo_root" branch --show-current) == main ]] ||
    die 'Updater only runs from the main branch.'
[[ $(stat -c %u -- "$repo_root") == "$EUID" ]] ||
    die 'Repository checkout is not owned by the current user.'

source_helper="$repo_root/stages/stage-5-desktop-customization/workstreams/02-lock-screen/scripts/k41-lock-caelestia-after-start.sh"
bin_root="$HOME/.local/bin"
target="$bin_root/k41-lock-caelestia-after-start"
state_root="$HOME/.local/state"
k41_state="$state_root/k41"
lock_state="$k41_state/lockscreen"
backup_root="$lock_state/helper-backups"

[[ -f $source_helper && ! -L $source_helper && -s $source_helper ]] ||
    die "Workstream 02 lock helper source is missing or unsafe: $source_helper"
bash -n "$source_helper" || die 'Workstream 02 lock helper has invalid Bash syntax.'

for path in "$HOME/.local" "$bin_root" "$state_root" "$k41_state" "$lock_state" "$backup_root"; do
    [[ ! -L $path ]] || die "Refusing symlinked user path: $path"
    [[ ! -e $path || -d $path ]] || die "User path is not a directory: $path"
    if [[ -e $path ]]; then
        [[ $(stat -c %u -- "$path") == "$EUID" ]] || die "User path is not owned by the current account: $path"
    fi
done

mkdir -p -- "$bin_root" "$backup_root"
[[ -d $bin_root && ! -L $bin_root && $(stat -c %u -- "$bin_root") == "$EUID" ]] ||
    die 'Cannot establish a user-owned ~/.local/bin directory.'
[[ -d $backup_root && ! -L $backup_root && $(stat -c %u -- "$backup_root") == "$EUID" ]] ||
    die 'Cannot establish a user-owned helper backup directory.'

if [[ -e $target || -L $target ]]; then
    [[ -f $target && ! -L $target ]] || die "Installed helper is not a regular file: $target"
    [[ $(stat -c %u -- "$target") == "$EUID" ]] || die 'Installed helper is not owned by the current user.'
    if cmp -s "$source_helper" "$target"; then
        info 'Installed lock helper already matches Workstream 02 source; no changes made.'
        exit 0
    fi
fi

stamp="$(date -u +'%Y%m%dT%H%M%SZ')"
backup=""
if [[ -f $target ]]; then
    backup="$backup_root/k41-lock-caelestia-after-start-$stamp-${BASHPID}.sh"
    [[ ! -e $backup && ! -L $backup ]] || die "Backup already exists: $backup"
    cp -p -- "$target" "$backup"
    chmod 0600 "$backup"
    info "Existing helper backed up to: $backup"
else
    info 'No installed helper existed; installing the Workstream 02 helper.'
fi

temporary="$(mktemp "$bin_root/.k41-lock-caelestia-after-start.XXXXXX")" ||
    die 'Cannot create temporary helper in ~/.local/bin.'
cleanup() {
    [[ -z ${temporary:-} || ! -e $temporary ]] || rm -f -- "$temporary"
}
trap cleanup EXIT

install -m 0755 -- "$source_helper" "$temporary"
bash -n "$temporary" || die 'Staged helper failed Bash syntax validation.'
cmp -s "$source_helper" "$temporary" || die 'Staged helper differs from repository source.'
mv -f -- "$temporary" "$target"
temporary=""

cmp -s "$source_helper" "$target" || die 'Installed helper failed byte-for-byte verification.'
[[ -x $target && ! -L $target && $(stat -c %u -- "$target") == "$EUID" ]] ||
    die 'Installed helper has unexpected type, ownership, or executable state.'

info 'Workstream 02 lock startup helper updated and verified.'
info "Installed helper: $target"
info "SHA-256: $(sha256sum "$target" | awk '{print $1}')"
[[ -z $backup ]] || info "Rollback copy: $backup"
info 'No system service, package, Plymouth, getty, PAM, authentication, bootloader, or initramfs state was changed.'
