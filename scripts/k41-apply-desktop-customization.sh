#!/usr/bin/env bash
# Apply the first K41 Stage 5 appearance layer to an existing user session.
set -Eeuo pipefail
umask 077

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
info() { printf 'INFO: %s\n' "$*"; }

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd -- "$script_dir/.." && pwd -P)"
hypr_source="$repo_root/config/desktop-customization/hyprland-appearance.lua"
fuzzel_source="$repo_root/config/desktop-customization/fuzzel.ini"
hypr_target="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprland.lua"
fuzzel_target="${XDG_CONFIG_HOME:-$HOME/.config}/fuzzel/fuzzel.ini"
state_root="${XDG_STATE_HOME:-$HOME/.local/state}/k41/desktop-customization/backups"

[[ $EUID -ne 0 ]] || die 'Run as the regular desktop user; do not use sudo.'
[[ -n ${HOME:-} && -d $HOME ]] || die 'HOME is not set to an existing directory.'
command -v python3 >/dev/null 2>&1 || die 'python3 is required.'
command -v fuzzel >/dev/null 2>&1 || die 'Fuzzel is not installed.'
command -v foot >/dev/null 2>&1 || die 'Foot is not installed.'
[[ -r $hypr_source && -r $fuzzel_source ]] || die 'Customization source files are missing from the repository.'

if [[ ${1:-} == --rollback ]]; then
    [[ $# -eq 2 ]] || die 'Usage: bash scripts/k41-apply-desktop-customization.sh --rollback BACKUP_DIRECTORY'
    backup_dir=$2
    [[ -d $backup_dir && -f $backup_dir/hyprland.lua && -f $backup_dir/fuzzel.ini ]] || die 'Backup directory is incomplete.'
    [[ -f $hypr_target && -f $fuzzel_target ]] || die 'Current target configuration is missing.'
    printf 'Restore Hyprland and Fuzzel configuration from:\n%s\n' "$backup_dir"
    read -r -p 'Continue? [y/N] ' answer
    [[ $answer == [yY] ]] || die 'Rollback cancelled.'
    cp -a -- "$backup_dir/hyprland.lua" "$hypr_target"
    cp -a -- "$backup_dir/fuzzel.ini" "$fuzzel_target"
    info 'Rollback files restored. Reload Hyprland or log out and back in to apply.'
    exit 0
fi

[[ $# -eq 0 ]] || die 'Unknown argument. Run without arguments to apply, or use --rollback BACKUP_DIRECTORY.'
[[ -f $hypr_target ]] || die "Active Hyprland Lua config not found: $hypr_target"
[[ -f $fuzzel_target ]] || die "Existing Fuzzel config not found: $fuzzel_target"
grep -Fq 'local menu = "hyprlauncher"' "$hypr_target" || die 'Expected launcher declaration was not found. Configuration differs from the audited baseline; refusing an automatic patch.'
! grep -Fq 'K41_OBSIDIAN_APPEARANCE_BEGIN' "$hypr_target" || die 'K41 appearance overlay already exists. Do not apply twice; inspect the active config or use its backup to roll back.'

printf '%s\n' 'This applies the first Graphite Monochrome layer:'
printf '%s\n' '  - Hyprland appearance only (existing binds, input, rules and autostart are preserved)'
printf '%s\n' '  - SUPER+R launcher changes from missing hyprlauncher to installed Fuzzel'
printf '%s\n' '  - Fuzzel receives the repository Graphite configuration'
printf '%s\n' 'No packages are installed. No wallpaper, Caelestia, GTK, power, or hardware settings are changed.'
read -r -p 'Apply these changes? [y/N] ' answer
[[ $answer == [yY] ]] || die 'Cancelled without changes.'

timestamp="$(date -u +'%Y%m%dT%H%M%SZ')"
mkdir -p -- "$state_root"
backup_dir="$state_root/$timestamp"
suffix=0
while ! mkdir -- "$backup_dir" 2>/dev/null; do
    suffix=$((suffix + 1))
    backup_dir="$state_root/$timestamp-$suffix"
done
chmod 0700 "$backup_dir"
cp -a -- "$hypr_target" "$backup_dir/hyprland.lua"
cp -a -- "$fuzzel_target" "$backup_dir/fuzzel.ini"

python3 - "$hypr_target" "$fuzzel_target" "$hypr_source" "$fuzzel_source" <<'PY'
import os
import pathlib
import stat
import sys
import tempfile

hypr_path, fuzzel_path, overlay_path, fuzzel_source_path = map(pathlib.Path, sys.argv[1:])
hypr_text = hypr_path.read_text(encoding="utf-8")
overlay = overlay_path.read_text(encoding="utf-8").strip()
fuzzel_text = fuzzel_source_path.read_text(encoding="utf-8")

needle = 'local menu = "hyprlauncher"'
if hypr_text.count(needle) != 1:
    raise SystemExit("Expected exactly one audited launcher declaration; no files changed.")
if "K41_OBSIDIAN_APPEARANCE_BEGIN" in hypr_text:
    raise SystemExit("K41 appearance marker already exists; no files changed.")
if not overlay or not fuzzel_text:
    raise SystemExit("A source configuration is empty; no files changed.")

hypr_text = hypr_text.replace(needle, 'local menu = "fuzzel"', 1)
hypr_text += (
    "\n\n-- K41_OBSIDIAN_APPEARANCE_BEGIN\n"
    + overlay
    + "\n-- K41_OBSIDIAN_APPEARANCE_END\n"
)

def atomic_write(path: pathlib.Path, content: str) -> None:
    mode = stat.S_IMODE(path.stat().st_mode)
    fd, temporary = tempfile.mkstemp(prefix=f".{path.name}.k41.", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as stream:
            stream.write(content)
            stream.flush()
            os.fsync(stream.fileno())
        os.chmod(temporary, mode)
        os.replace(temporary, path)
    except BaseException:
        try:
            os.unlink(temporary)
        except FileNotFoundError:
            pass
        raise

atomic_write(hypr_path, hypr_text)
atomic_write(fuzzel_path, fuzzel_text)
PY

printf '%s\n' "$backup_dir" >"$state_root/latest-backup"
chmod 0600 "$state_root/latest-backup"
info "Backup saved at: $backup_dir"
info 'Configuration files updated.'
info 'Next: run hyprctl reload, then test SUPER+R. If needed, use:'
printf 'bash "%s" --rollback "%s"\n' "$script_dir/$(basename -- "$0")" "$backup_dir"
