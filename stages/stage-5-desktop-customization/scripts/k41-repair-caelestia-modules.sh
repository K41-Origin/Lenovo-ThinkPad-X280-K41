#!/usr/bin/env bash
# Restore a missing Caelestia upstream QML module from the package-owned tree.
set -Eeuo pipefail
umask 077

readonly SCRIPT_NAME=${0##*/}
mode=dry-run

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
info() { printf 'INFO: %s\n' "$*"; }
usage() {
  cat <<USAGE
Usage: $SCRIPT_NAME [--dry-run|--apply|--check]

Restore only the missing upstream modules/dashboard directory from
/etc/xdg/quickshell/caelestia into the user's Quickshell configuration.

  --dry-run  Inspect and show the planned action (default).
  --apply    Copy the module after validating its package-owned source.
  --check    Verify that the local Dashboard module directory exists.
USAGE
}

while (($#)); do
  case "$1" in
    --dry-run) mode=dry-run ;;
    --apply) mode=apply ;;
    --check) mode=check ;;
    --help|-h) usage; exit 0 ;;
    *) die "Unknown argument: $1" ;;
  esac
  shift
done

[[ $EUID -ne 0 ]] || die 'Run as the regular desktop user; do not use sudo.'
command -v pacman >/dev/null 2>&1 || die 'pacman is required to verify the upstream source owner.'

config_root=${XDG_CONFIG_HOME:-$HOME/.config}
local_root="$config_root/quickshell/caelestia"
local_modules="$local_root/modules"
local_dashboard="$local_modules/dashboard"
source_root=${K41_CAELESTIA_UPSTREAM_ROOT:-/etc/xdg/quickshell/caelestia}
source_dashboard="$source_root/modules/dashboard"

[[ -d $local_root && ! -L $local_root ]] || die "Local Caelestia config directory missing or symlinked: $local_root"
[[ -d $local_modules && ! -L $local_modules ]] || die "Local modules directory missing or symlinked: $local_modules"

if [[ $mode == check ]]; then
  [[ -d $local_dashboard && ! -L $local_dashboard ]] || die "Dashboard module is missing: $local_dashboard"
  find "$local_dashboard" -type f -name '*.qml' -print -quit | grep -q . \
    || die "Dashboard module contains no QML files: $local_dashboard"
  info "Dashboard module exists: $local_dashboard"
  exit 0
fi

[[ -d $source_root && ! -L $source_root ]] || die "Upstream source root missing or symlinked: $source_root"
[[ -d $source_dashboard && ! -L $source_dashboard ]] || die "Upstream Dashboard source missing or symlinked: $source_dashboard"

# Reject symlinks and special files so the repair cannot import arbitrary paths.
if find "$source_dashboard" -mindepth 1 \( -type l -o ! -type d -a ! -type f \) -print -quit | grep -q .; then
  die "Upstream Dashboard source contains symlinks or special files: $source_dashboard"
fi
source_qml=$(find "$source_dashboard" -type f -name '*.qml' -print -quit)
[[ -n $source_qml ]] || die "Upstream Dashboard source contains no QML files: $source_dashboard"

# The canonical Arch package install path is /etc/xdg/quickshell/caelestia.
# Require pacman ownership evidence for the source tree before copying it.
pacman -Qo "$source_qml" >/dev/null 2>&1 \
  || die "Source QML is not owned by an installed pacman package: $source_qml"

if [[ -e $local_dashboard || -L $local_dashboard ]]; then
  die "Destination already exists; refusing to merge or overwrite it: $local_dashboard"
fi

info "Source: $source_dashboard"
info "Destination: $local_dashboard"
info 'Only modules/dashboard will be restored; dashboard.enabled remains unchanged.'

if [[ $mode == dry-run ]]; then
  info 'DRY-RUN: no files changed. Re-run with --apply to restore the module.'
  exit 0
fi

stage=$(mktemp -d "$local_modules/.k41-dashboard-repair.XXXXXX")
cleanup() { rm -rf -- "$stage"; }
trap cleanup EXIT
cp -a -- "$source_dashboard" "$stage/dashboard"

# Verify staged content before exposing it to Quickshell.
[[ -d $stage/dashboard && ! -L $stage/dashboard ]] || die 'Staged Dashboard directory is invalid.'
find "$stage/dashboard" -type f -name '*.qml' -print -quit | grep -q . \
  || die 'Staged Dashboard directory contains no QML files.'

# Atomic rename: never partially populate the live module directory.
mv -Tn -- "$stage/dashboard" "$local_dashboard"
[[ ! -e $stage/dashboard && -d $local_dashboard ]] || die 'Destination appeared during repair; refusing to overwrite it.'
info "RESTORED $local_dashboard"
info 'Run --check, then launch `qs -c caelestia` from the active Wayland session.'
