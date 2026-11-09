#!/usr/bin/env bash
# Apply the first K41 Stage 5 appearance layer and save a push-ready run report.
set -Eeuo pipefail
umask 077

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
info() { printf 'INFO: %s\n' "$*"; }
display_path() {
    case "$1" in
        "$HOME"/*) printf '~/%s' "${1#"$HOME"/}" ;;
        *) printf '%s' "$1" ;;
    esac
}

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd -- "$script_dir/.." && pwd -P)"
hypr_source="$repo_root/config/desktop-customization/hyprland-appearance.lua"
fuzzel_source="$repo_root/config/desktop-customization/fuzzel.ini"
hypr_target="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprland.lua"
fuzzel_target="${XDG_CONFIG_HOME:-$HOME/.config}/fuzzel/fuzzel.ini"
state_root="${XDG_STATE_HOME:-$HOME/.local/state}/k41/desktop-customization/backups"
report_root="$repo_root/reports/desktop-customization"
timestamp="$(date -u +'%Y%m%dT%H%M%SZ')"
mkdir -p -- "$report_root"
report_dir="$report_root/$timestamp"
suffix=0
while ! mkdir -- "$report_dir" 2>/dev/null; do
    suffix=$((suffix + 1))
    report_dir="$report_root/$timestamp-$suffix"
done
log_file="$report_dir/run.log"
summary_file="$report_dir/summary.txt"
detected_launcher="NOT_CHECKED"
backup_dir="NOT_CREATED"
run_status="FAILED"
exec > >(tee -a "$log_file") 2>&1

on_exit() {
    local rc=$1
    if (( rc == 0 )); then run_status="SUCCESS"; else run_status="FAILED (exit $rc)"; fi
    {
        printf 'K41 Desktop Customization Run\n'
        printf 'Timestamp UTC: %s\n' "$timestamp"
        printf 'Status: %s\n' "$run_status"
        printf 'Detected launcher declaration: %s\n' "$detected_launcher"
        printf 'Backup: %s\n' "$(display_path "$backup_dir")"
        printf 'Log: reports/desktop-customization/%s/run.log\n' "$(basename -- "$report_dir")"
    } >"$summary_file"
    printf 'INFO: Run report: reports/desktop-customization/%s/\n' "$(basename -- "$report_dir")"
}
trap 'on_exit $?' EXIT

info "K41 desktop customization started (UTC $timestamp)"
info "Report directory: reports/desktop-customization/$(basename -- "$report_dir")"

[[ $EUID -ne 0 ]] || die 'Run as the regular desktop user; do not use sudo.'
[[ -n ${HOME:-} && -d $HOME ]] || die 'HOME is not set to an existing directory.'
command -v python3 >/dev/null 2>&1 || die 'python3 is required.'
command -v fuzzel >/dev/null 2>&1 || die 'Fuzzel is not installed.'
command -v foot >/dev/null 2>&1 || die 'Foot is not installed.'
command -v tee >/dev/null 2>&1 || die 'tee is required for the run log.'
[[ -r $hypr_source && -r $fuzzel_source ]] || die 'Customization source files are missing from the repository.'

if [[ ${1:-} == --rollback ]]; then
    [[ $# -eq 2 ]] || die 'Usage: bash scripts/k41-apply-desktop-customization.sh --rollback BACKUP_DIRECTORY'
    backup_dir=$2
    [[ -d $backup_dir && -f $backup_dir/hyprland.lua && -f $backup_dir/fuzzel.ini ]] || die 'Backup directory is incomplete.'
    [[ -f $hypr_target && -f $fuzzel_target ]] || die 'Current target configuration is missing.'
    printf 'Restore Hyprland and Fuzzel configuration from: %s\n' "$(display_path "$backup_dir")"
    read -r -p 'Continue? [y/N] ' answer
    [[ $answer == [yY] ]] || die 'Rollback cancelled.'
    cp -a -- "$backup_dir/hyprland.lua" "$hypr_target"
    cp -a -- "$backup_dir/fuzzel.ini" "$fuzzel_target"
    info 'Rollback files restored. Reload Hyprland or log out and back in to apply.'
    exit 0
fi

[[ $# -eq 0 ]] || die 'Unknown argument. Run without arguments to apply, or use --rollback BACKUP_DIRECTORY.'
[[ -f $hypr_target ]] || die 'Active Hyprland Lua config not found at ~/.config/hypr/hyprland.lua or configured XDG_CONFIG_HOME.'
[[ -f $fuzzel_target ]] || die "Existing Fuzzel config not found: $fuzzel_target"

# Discover the single local menu declaration rather than assuming its old value.
# This accepts whitespace and either quote style while refusing ambiguous configs.
launcher_info="$(python3 - "$hypr_target" <<'PY'
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
pattern = re.compile(r"""^([ \t]*local[ \t]+menu[ \t]*=[ \t]*)(["'])([^"'\n]+)\2([ \t]*(?:--.*)?)$""", re.MULTILINE)
matches = list(pattern.finditer(text))
if len(matches) != 1:
    candidates = [
        f"line {i}: local menu declaration candidate"
        for i, line in enumerate(text.splitlines(), 1)
        if re.search(r"\bmenu\b", line) and re.search(r"\blocal\b", line)
    ]
    print(f"ERROR: expected exactly one simple local menu string declaration; found {len(matches)}.", file=sys.stderr)
    if candidates:
        print("Candidate locations: " + ", ".join(candidates[:10]), file=sys.stderr)
    print("No configuration files were changed.", file=sys.stderr)
    raise SystemExit(2)
m = matches[0]
print(f"{m.group(3)}\t{m.start()}\t{m.end()}")
PY
)" || die 'Could not safely identify the launcher variable. The run log contains diagnostic details; configuration was not modified.'
detected_launcher="${launcher_info%%$'\t'*}"
info "Detected launcher declaration value: $detected_launcher"
! grep -Fq 'K41_OBSIDIAN_APPEARANCE_BEGIN' "$hypr_target" || die 'K41 appearance overlay already exists. Do not apply twice; inspect the active config or use its backup to roll back.'

printf '%s\n' 'This applies the first Graphite Monochrome layer:'
printf '%s\n' '  - Hyprland appearance only; existing binds, input, rules and autostart are preserved'
printf '%s\n' '  - SUPER+R launcher is set to installed Fuzzel'
printf '%s\n' '  - Fuzzel receives the repository Graphite configuration'
printf '%s\n' 'No packages, wallpaper, Caelestia, GTK, power, or hardware settings are changed.'
read -r -p 'Apply these changes? [y/N] ' answer
[[ $answer == [yY] ]] || die 'Cancelled without changes.'

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
info 'Private backup created.'

python3 - "$hypr_target" "$fuzzel_target" "$hypr_source" "$fuzzel_source" <<'PY'
import os
import pathlib
import re
import stat
import sys
import tempfile

hypr_path, fuzzel_path, overlay_path, fuzzel_source_path = map(pathlib.Path, sys.argv[1:])
hypr_text = hypr_path.read_text(encoding="utf-8")
overlay = overlay_path.read_text(encoding="utf-8").strip()
fuzzel_text = fuzzel_source_path.read_text(encoding="utf-8")
pattern = re.compile(r"""^([ \t]*local[ \t]+menu[ \t]*=[ \t]*)(["'])([^"'\n]+)\2([ \t]*(?:--.*)?)$""", re.MULTILINE)
matches = list(pattern.finditer(hypr_text))
if len(matches) != 1:
    raise SystemExit("Launcher declaration changed between preflight and apply; refusing to write.")
if "K41_OBSIDIAN_APPEARANCE_BEGIN" in hypr_text:
    raise SystemExit("K41 appearance marker already exists; refusing to write.")
if not overlay or not fuzzel_text:
    raise SystemExit("A source configuration is empty; refusing to write.")

m = matches[0]
replacement = f'{m.group(1)}"fuzzel"{m.group(4)}'
hypr_text = hypr_text[:m.start()] + replacement + hypr_text[m.end():]
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
info 'Configuration files updated.'
info 'Next: run hyprctl reload, then test SUPER+R.'
info 'If needed, rollback with the backup directory shown in this run log (or latest-backup state file).'
