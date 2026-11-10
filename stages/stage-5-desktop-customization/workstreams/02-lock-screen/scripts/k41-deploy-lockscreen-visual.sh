#!/usr/bin/env bash
# Deploy the K41-owned lock-screen visual module into the user's Quickshell tree.
# This does NOT modify Caelestia's shell entrypoint or activate the module.
set -Eeuo pipefail
umask 077

readonly SCRIPT_NAME=${0##*/}
readonly RELATIVE_MODULE_PATH="modules/lockscreen"
readonly MARKER=".k41-lockscreen-managed"
readonly SOURCE_FILES=(LockSurface.qml Content.qml Center.qml center/PasswordInput.qml)

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
info() { printf 'INFO: %s\n' "$*"; }
usage() {
    cat <<USAGE
Usage:
  bash $SCRIPT_NAME --install
  bash $SCRIPT_NAME --status
  bash $SCRIPT_NAME --rollback BACKUP_DIRECTORY

Install copies only the Stage 5 visual module to:
  ~/.config/quickshell/k41/$RELATIVE_MODULE_PATH

No sudo is required. This script does not edit Caelestia's shell.qml,
PAM/authentication, session-lock policy, Hyprland configuration, or services.
USAGE
}

[[ $EUID -ne 0 ]] || die "Do not run this script with sudo or as root."
[[ -n ${HOME:-} && $HOME == /* && -d $HOME ]] || die "HOME is missing or invalid."
command -v realpath >/dev/null 2>&1 || die "realpath is required."
command -v sha256sum >/dev/null 2>&1 || die "sha256sum is required."
command -v install >/dev/null 2>&1 || die "install is required."
command -v cmp >/dev/null 2>&1 || die "cmp is required."
command -v mktemp >/dev/null 2>&1 || die "mktemp is required."
command -v date >/dev/null 2>&1 || die "date is required."
command -v cp >/dev/null 2>&1 || die "cp is required."
command -v mv >/dev/null 2>&1 || die "mv is required."
command -v rm >/dev/null 2>&1 || die "rm is required."
command -v stat >/dev/null 2>&1 || die "stat is required."

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(realpath -- "$script_dir/../../../../..")"
source_root="$repo_root/stages/stage-5-desktop-customization/workstreams/02-lock-screen/modules/lockscreen"
config_root="${XDG_CONFIG_HOME:-$HOME/.config}"
state_root="${XDG_STATE_HOME:-$HOME/.local/state}"
quickshell_root="$config_root/quickshell"
k41_root="$quickshell_root/k41"
target_root="$k41_root/$RELATIVE_MODULE_PATH"
backup_root="$state_root/k41/lockscreen/backups"

[[ $config_root == "$HOME/.config" && $state_root == "$HOME/.local/state" ]] ||
    die "Non-default XDG paths are not supported by this migration yet."
[[ -d $source_root && ! -L $source_root ]] || die "Stage 5 source directory not found: $source_root"
[[ $(stat -c %u "$repo_root") == "$EUID" ]] || die "Repository checkout must be owned by the current user."

# Reject symlinked path components to prevent writes outside the intended home.
assert_no_symlink_components() {
    local path=$1 current="" part
    local -a parts=()
    IFS=/ read -r -a parts <<< "$path"
    for part in "${parts[@]}"; do
        [[ -z $part ]] && continue
        current="$current/$part"
        [[ ! -L $current ]] || die "Refusing symlink path component: $current"
    done
}
assert_no_symlink_components "$config_root"
assert_no_symlink_components "$quickshell_root"
assert_no_symlink_components "$k41_root"
assert_no_symlink_components "$target_root"
assert_no_symlink_components "$state_root"
assert_no_symlink_components "$backup_root"

for relative in "${SOURCE_FILES[@]}"; do
    [[ -s $source_root/$relative && ! -L $source_root/$relative ]] ||
        die "Missing, empty, or symlinked source file: $relative"
done
[[ ! -e $source_root/Pam.qml && ! -e $source_root/pam ]] ||
    die "Authentication implementation must not be deployed as part of this visual module."

for path in "$quickshell_root" "$k41_root" "$target_root" "$backup_root"; do
    if [[ -e $path && ! -d $path ]]; then
        die "Expected directory but found another file type: $path"
    fi
    if [[ -d $path && $(stat -c %u "$path") != "$EUID" ]]; then
        die "Directory is not owned by current user: $path"
    fi
done

command_name=${1:---status}
case "$command_name" in
    --status)
        if [[ -d $target_root && -f $target_root/$MARKER ]]; then
            printf 'DEPLOYED: %s\n' "$target_root"
            (cd -- "$target_root" && sha256sum -c MANIFEST.sha256)
            printf 'ACTIVATION: NOT VERIFIED; Caelestia host integration is not modified by this script.\n'
        elif [[ -e $target_root ]]; then
            die "Target exists but is not marked as K41-managed; refusing to inspect/replace unknown content: $target_root"
        else
            printf 'NOT DEPLOYED: %s\n' "$target_root"
        fi
        exit 0
        ;;
    --install)
        [[ $# -eq 1 ]] || { usage >&2; exit 2; }
        ;;
    --rollback)
        [[ $# -eq 2 ]] || { usage >&2; exit 2; }
        rollback_dir=$2
        [[ -d $rollback_dir && ! -L $rollback_dir ]] ||
            die "Backup path is invalid or outside $backup_root."
        rollback_dir="$(realpath -e -- "$rollback_dir")"
        backup_root="$(realpath -e -- "$backup_root")"
        [[ $rollback_dir == "$backup_root/"* ]] || die "Backup path resolves outside $backup_root."
        [[ $(stat -c %u "$rollback_dir") == "$EUID" ]] || die "Backup is not owned by current user."
        [[ -f $rollback_dir/manifest && -f $rollback_dir/backup-kind ]] ||
            die "Backup metadata is incomplete."
        [[ $(<"$rollback_dir/backup-kind") == "k41-lockscreen-visual-v1" ]] ||
            die "Unrecognized backup format."
        [[ -d $target_root && -f $target_root/$MARKER ]] ||
            die "Current target is not an installed K41-managed module; refusing rollback."
        (cd -- "$target_root" && sha256sum -c MANIFEST.sha256 >/dev/null) ||
            die "Current target differs from the managed manifest; preserve and inspect it before rollback."
        if [[ -d $rollback_dir/previous ]]; then
            restore_stage="$k41_root/.lockscreen-rollback.$$.tmp"
            [[ ! -e $restore_stage && ! -L $restore_stage ]] || die "Rollback staging path already exists."
            cp -a -- "$rollback_dir/previous" "$restore_stage"
            [[ -d $restore_stage && ! -L $restore_stage ]] || die "Could not stage previous module."
            retired="$k41_root/.lockscreen-retired.$$.tmp"
            mv -- "$target_root" "$retired"
            if ! mv -- "$restore_stage" "$target_root"; then
                mv -- "$retired" "$target_root"
                die "Rollback switch failed; original deployment restored."
            fi
            rm -rf -- "$retired"
            info "Previous module restored from: $rollback_dir"
        else
            retired="$k41_root/.lockscreen-retired.$$.tmp"
            mv -- "$target_root" "$retired"
            rm -rf -- "$retired"
            info "K41 visual module removed; there was no prior target to restore."
        fi
        exit 0
        ;;
    *)
        usage >&2
        exit 2
        ;;
esac

mkdir -p -- "$quickshell_root" "$k41_root" "$backup_root"
for path in "$quickshell_root" "$k41_root" "$backup_root"; do
    [[ ! -L $path && -d $path && $(stat -c %u "$path") == "$EUID" ]] ||
        die "Unsafe directory after creation: $path"
done

if [[ -e $target_root ]]; then
    [[ -d $target_root && ! -L $target_root && -f $target_root/$MARKER ]] ||
        die "Target already exists and is not a recognized K41-managed module: $target_root"
    (cd -- "$target_root" && sha256sum -c MANIFEST.sha256 >/dev/null) ||
        die "Existing managed module has local modifications; refusing to overwrite it."
    if (cd -- "$target_root" && sha256sum -c MANIFEST.sha256 >/dev/null 2>&1); then
        source_manifest="$(mktemp)"
        target_manifest="$(mktemp)"
        trap 'rm -f -- "$source_manifest" "$target_manifest"' EXIT
        (cd -- "$source_root" && sha256sum "${SOURCE_FILES[@]}") > "$source_manifest"
        (cd -- "$target_root" && sha256sum "${SOURCE_FILES[@]}") > "$target_manifest"
        if cmp -s "$source_manifest" "$target_manifest"; then
            info "Already up to date: $target_root"
            printf 'ACTIVATION: NOT VERIFIED; host integration remains a separate step.\n'
            exit 0
        fi
    fi
fi

stamp="$(date -u +'%Y%m%dT%H%M%SZ')"
backup_dir="$backup_root/$stamp"
suffix=0
while ! mkdir -- "$backup_dir" 2>/dev/null; do
    suffix=$((suffix + 1))
    backup_dir="$backup_root/$stamp-$suffix"
done
printf '%s\n' "k41-lockscreen-visual-v1" > "$backup_dir/backup-kind"
if [[ -d $target_root ]]; then
    cp -a -- "$target_root" "$backup_dir/previous"
    printf '%s\n' "previous-target=$target_root" > "$backup_dir/manifest"
else
    printf '%s\n' "previous-target=absent" > "$backup_dir/manifest"
fi

stage="$k41_root/.lockscreen-stage.$$.tmp"
[[ ! -e $stage && ! -L $stage ]] || die "Staging path already exists: $stage"
mkdir -p -- "$stage/center"
cleanup_stage() { [[ ! -d $stage ]] || rm -rf -- "$stage"; }
trap cleanup_stage EXIT

for relative in "${SOURCE_FILES[@]}"; do
    install -m 0644 -- "$source_root/$relative" "$stage/$relative"
done
printf '%s\n' "K41 Stage 5 visual module; deployment marker only, not host activation." > "$stage/$MARKER"
(
    cd -- "$stage"
    sha256sum "${SOURCE_FILES[@]}" > MANIFEST.sha256
    sha256sum -c MANIFEST.sha256
)
for relative in "${SOURCE_FILES[@]}"; do
    cmp -s "$source_root/$relative" "$stage/$relative" ||
        die "Staged file verification failed: $relative"
done

retired=""
if [[ -d $target_root ]]; then
    retired="$k41_root/.lockscreen-retired.$$.tmp"
    [[ ! -e $retired && ! -L $retired ]] || die "Retired path already exists: $retired"
    mv -- "$target_root" "$retired"
fi
if ! mv -- "$stage" "$target_root"; then
    [[ -z $retired || ! -d $retired ]] || mv -- "$retired" "$target_root"
    die "Atomic deployment switch failed; previous target restored."
fi
stage=""
if [[ -n $retired && -d $retired ]]; then
    rm -rf -- "$retired"
fi

info "Visual module deployed successfully: $target_root"
info "Backup: $backup_dir"
info "No Caelestia entrypoint, authentication, PAM, session-lock, Hyprland, or system service files were changed."
printf 'ACTIVATION: NOT VERIFIED. This script intentionally does not edit Caelestia shell.qml.\n'
printf 'NEXT: verify the supported host import/integration point before enabling this module.\n'
