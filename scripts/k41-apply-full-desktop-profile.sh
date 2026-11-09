#!/usr/bin/env bash
# Apply the complete K41 Caelestia visual profile and wallpaper.
# User-level only; backs up the active shell configuration and scheme state.
set -Eeuo pipefail
umask 077

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
info() { printf 'INFO: %s\n' "$*"; }
usage() {
    printf 'Usage:\n  %s\n  %s --rollback BACKUP_DIRECTORY\n' "$0" "$0"
}

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd -- "$script_dir/.." && pwd -P)"
profile_file="$repo_root/config/desktop-customization/caelestia-shell.json"
wallpaper_source="$repo_root/assets/wallpapers/k41-obsidian-1280x720.jpg.base64"
config_root="${XDG_CONFIG_HOME:-$HOME/.config}"
state_root="${XDG_STATE_HOME:-$HOME/.local/state}"
shell_file="$config_root/caelestia/shell.json"
scheme_file="$state_root/caelestia/scheme.json"
backup_root="$state_root/k41/desktop-profile/backups"
report_root="$repo_root/reports/desktop-profile"
wallpaper_dir="$HOME/Pictures/Wallpapers"
timestamp="$(date -u +'%Y%m%dT%H%M%SZ')"
mode="apply"
rollback_dir=""

if [[ ${1:-} == "--rollback" ]]; then
    [[ $# -eq 2 ]] || { usage >&2; exit 2; }
    mode="rollback"
    rollback_dir=$2
elif [[ $# -ne 0 ]]; then
    usage >&2
    exit 2
fi

[[ $EUID -ne 0 ]] || die 'Run as the regular desktop user; do not use sudo.'
[[ -n ${HOME:-} && -d $HOME ]] || die 'HOME must point to an existing directory.'
for cmd in python3 timeout caelestia cp mkdir date tee cmp chmod grep; do
    command -v "$cmd" >/dev/null 2>&1 || die "Required command not found: $cmd"
done

if [[ $mode == "rollback" ]]; then
    [[ -d $rollback_dir && -f $rollback_dir/shell.json && -f $rollback_dir/scheme.json ]] \
        || die 'Backup directory must contain shell.json and scheme.json.'
    [[ -f $shell_file && -f $scheme_file ]] || die 'Current Caelestia config/state files are missing.'
    cp -a -- "$rollback_dir/shell.json" "$shell_file"
    cp -a -- "$rollback_dir/scheme.json" "$scheme_file"
    info 'Restored shell.json and scheme.json from backup.'
    info 'Restarting Caelestia to load restored settings.'
    timeout 10s caelestia shell -r -d
    info 'Configuration rollback complete.'
    info 'Wallpaper rollback is manual: select the previous wallpaper from Caelestia >wallpaper.'
    exit 0
fi

[[ -r $profile_file && -r $wallpaper_source ]] || die 'Profile JSON or wallpaper asset is missing.'
[[ -f $shell_file && -f $scheme_file ]] || die 'Expected existing Caelestia shell.json and scheme.json; refusing to create an unverified configuration.'
[[ -d $config_root/caelestia && -d $state_root/caelestia ]] || die 'Caelestia config/state directories are missing.'

# Validate profile and existing user JSON before making any changes.
python3 - "$profile_file" "$shell_file" "$scheme_file" "$wallpaper_source" <<'PY'
import base64, binascii, json, pathlib, sys
for name in sys.argv[1:4]:
    path = pathlib.Path(name)
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        raise SystemExit(f"Invalid JSON in {path}: {type(exc).__name__}: {exc}")
    if not isinstance(value, dict):
        raise SystemExit(f"Expected a JSON object in {path}")
wallpaper_path = pathlib.Path(sys.argv[4])
try:
    payload = base64.b64decode(wallpaper_path.read_text(encoding="ascii").strip(), validate=True)
except (UnicodeError, binascii.Error) as exc:
    raise SystemExit(f"Invalid base64 wallpaper asset {wallpaper_path}: {exc}")
if not payload.startswith(b"\xff\xd8\xff"):
    raise SystemExit(f"Wallpaper asset is not a JPEG: {wallpaper_path}")
print(f"PASS: wallpaper asset preflight ({len(payload)} decoded bytes).")
PY

scheme_help="$(timeout 8s caelestia scheme set -h 2>&1)" || die 'Unable to inspect Caelestia scheme command.'
grep -q -- 'monochrome' <<<"$scheme_help" || die 'Installed Caelestia CLI does not expose the monochrome variant.'
wallpaper_help="$(timeout 8s caelestia wallpaper -h 2>&1)" || die 'Unable to inspect Caelestia wallpaper command.'
grep -Eq -- '(-f|--file)' <<<"$wallpaper_help" || die 'Installed Caelestia CLI does not expose the documented wallpaper file option.'

mkdir -p -- "$report_root" "$backup_root" "$wallpaper_dir"
report_dir="$report_root/$timestamp"
suffix=0
while ! mkdir -- "$report_dir" 2>/dev/null; do
    suffix=$((suffix + 1))
    report_dir="$report_root/$timestamp-$suffix"
done
log_file="$report_dir/run.log"
summary_file="$report_dir/summary.txt"
exec > >(tee -a "$log_file") 2>&1

backup_dir=""
wallpaper_target=""
wallpaper_applied=0
status="FAILED"
restart_status="NOT_RUN"
runtime_log_status="NOT_RUN"

write_summary() {
    local rc=$1
    {
        printf 'K41 Full Desktop Profile\n'
        printf 'Timestamp UTC: %s\n' "$timestamp"
        printf 'Status: %s\n' "$status"
        printf 'Scheme: caelestia / dark / monochrome\n'
        printf 'Wallpaper: %s\n' "${wallpaper_target:-NOT_APPLIED}"
        printf 'Wallpaper applied: %s\n' "$wallpaper_applied"
        printf 'Shell restart: %s\n' "$restart_status"
        printf 'Runtime log: %s\n' "$runtime_log_status"
        printf 'Backup: %s\n' "${backup_dir:-NOT_CREATED}"
        printf 'Report: reports/desktop-profile/%s/\n' "$(basename -- "$report_dir")"
        printf 'Rollback restores shell.json and scheme.json; wallpaper selection is manual.\n'
    } >"$summary_file"
}

on_exit() {
    local rc=$?
    trap - EXIT
    if (( rc != 0 )) && [[ -n $backup_dir && $wallpaper_applied -eq 0 ]]; then
        info 'Failure before wallpaper activation; restoring original shell and scheme files.'
        cp -a -- "$backup_dir/shell.json" "$shell_file" || true
        cp -a -- "$backup_dir/scheme.json" "$scheme_file" || true
    fi
    if (( rc == 0 )); then
        if [[ $restart_status == "CONFIRMED" && $runtime_log_status == "OK" ]]; then
            status="SUCCESS"
        else
            status="SUCCESS_WITH_WARNINGS"
        fi
    else
        status="FAILED (exit $rc)"
    fi
    write_summary "$rc"
    info "Report: reports/desktop-profile/$(basename -- "$report_dir")/"
}
trap on_exit EXIT

info "K41 full desktop profile started (UTC $timestamp)"
info 'This profile changes Caelestia appearance, bar, dashboard, launcher, lock screen, sidebar, notifications, utilities and wallpaper.'
info 'It preserves existing authentication settings and does not edit shell-tokens.json, Hyprland binds, packages or system services.'
printf 'Apply the full K41 Obsidian profile? [y/N] '
IFS= read -r answer
[[ $answer =~ ^[Yy]([Ee][Ss])?$ ]] || die 'Cancelled by user.'

backup_dir="$backup_root/$timestamp"
suffix=0
while ! mkdir -- "$backup_dir" 2>/dev/null; do
    suffix=$((suffix + 1))
    backup_dir="$backup_root/$timestamp-$suffix"
done
chmod 0700 "$backup_dir"
cp -a -- "$shell_file" "$backup_dir/shell.json"
cp -a -- "$scheme_file" "$backup_dir/scheme.json"
info "Private backup created: ${backup_dir#"$HOME"/}"

# Merge recursively so unrelated user preferences and unknown future keys survive.
python3 - "$profile_file" "$shell_file" <<'PY'
import json, os, pathlib, stat, sys, tempfile
profile_path, target_path = map(pathlib.Path, sys.argv[1:])
profile = json.loads(profile_path.read_text(encoding="utf-8"))
target = json.loads(target_path.read_text(encoding="utf-8"))
def merge(dst, src):
    for key, value in src.items():
        if isinstance(value, dict) and isinstance(dst.get(key), dict):
            merge(dst[key], value)
        else:
            dst[key] = value
merge(target, profile)
fd, temporary = tempfile.mkstemp(prefix=".k41-shell-", dir=target_path.parent)
try:
    with os.fdopen(fd, "w", encoding="utf-8") as stream:
        json.dump(target, stream, indent=2, ensure_ascii=False)
        stream.write("\n")
    os.chmod(temporary, stat.S_IMODE(target_path.stat().st_mode))
    os.replace(temporary, target_path)
except BaseException:
    try: os.unlink(temporary)
    except FileNotFoundError: pass
    raise
# Read back the file and verify the sections that this profile owns.
check = json.loads(target_path.read_text(encoding="utf-8"))
required = {
    "bar": ["entries", "clock", "workspaces"],
    "dashboard": ["showMedia", "showPerformance"],
    "launcher": ["maxShown", "useFuzzy"],
    "lock": ["useWallpaper", "hideNotifs"],
    "sidebar": ["enabled"],
    "utilities": ["quickToggles"]
}
for section, keys in required.items():
    if not isinstance(check.get(section), dict):
        raise SystemExit(f"Missing profile section: {section}")
    for key in keys:
        if key not in check[section]:
            raise SystemExit(f"Missing profile setting: {section}.{key}")
if check["lock"].get("useWallpaper") is not True:
    raise SystemExit("Lock screen wallpaper setting did not persist.")
print("PASS: merged Caelestia profile and required component settings verified.")
PY

if ! timeout 15s caelestia scheme set -n caelestia -m dark -v monochrome; then
    die 'Could not apply Caelestia dark monochrome scheme.'
fi
scheme_output="$(timeout 8s caelestia scheme get 2>&1)" || die 'Could not read active Caelestia scheme.'
grep -Eiq 'Variant:[[:space:]]*monochrome' <<<"$scheme_output" || die 'Active scheme did not report monochrome.'

# Avoid overwriting an existing wallpaper with the same name.
wallpaper_target="$wallpaper_dir/k41-obsidian-1280x720.jpg"
if [[ -e $wallpaper_target ]]; then
    wallpaper_target="$wallpaper_dir/k41-obsidian-1280x720-$timestamp.jpg"
fi
python3 - "$wallpaper_source" "$wallpaper_target" <<'PY'
import base64, pathlib, sys
source, target = map(pathlib.Path, sys.argv[1:])
data = base64.b64decode(source.read_text(encoding="ascii").strip(), validate=True)
if not data.startswith(b"\xff\xd8\xff"):
    raise SystemExit("Wallpaper payload is not a JPEG file.")
target.parent.mkdir(parents=True, exist_ok=True)
target.write_bytes(data)
with target.open("rb") as stream:
    if stream.read(3) != b"\xff\xd8\xff":
        raise SystemExit("Written wallpaper failed JPEG signature verification.")
print(f"PASS: decoded JPEG wallpaper ({len(data)} bytes).")
PY
info "Wallpaper asset installed at: $wallpaper_target"
if ! timeout 25s caelestia wallpaper -f "$wallpaper_target"; then
    die 'Caelestia could not activate the wallpaper; original shell and scheme files will be restored.'
fi
wallpaper_applied=1
info 'PASS: Caelestia wallpaper command returned successfully.'

info 'Restarting Caelestia with the upstream-supported detached restart.'
if timeout 12s caelestia shell -r -d; then
    restart_status="COMMAND_RETURNED"
else
    restart_status="COMMAND_FAILED"
    info 'WARNING: restart command did not return successfully.'
fi

info 'Collecting Caelestia runtime log.'
if timeout 20s caelestia shell -l; then
    runtime_log_status="OK"
else
    runtime_log_status="FAILED"
fi

if [[ $restart_status == "COMMAND_RETURNED" ]] && grep -Fq 'Configuration Loaded' "$log_file"; then
    restart_status="CONFIRMED"
fi

info 'Visual components configured: lock screen, bar/taskbar, dashboard, launcher, sidebar, notifications, OSD and utility quick toggles.'
info 'Open Caelestia panels with the existing Hyprland shortcuts; use SUPER+L to test lock screen if that binding is present.'
info "Rollback command: bash scripts/k41-apply-full-desktop-profile.sh --rollback '$backup_dir'"
