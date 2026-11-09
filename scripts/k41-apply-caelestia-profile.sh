#!/usr/bin/env bash
# Apply the first supported Caelestia Graphite profile with backup and rollback.
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
config_root="${XDG_CONFIG_HOME:-$HOME/.config}"
state_root="${XDG_STATE_HOME:-$HOME/.local/state}"
shell_file="$config_root/caelestia/shell.json"
scheme_file="$state_root/caelestia/scheme.json"
backup_root="$state_root/k41/caelestia/backups"
report_root="$repo_root/reports/caelestia-customization"
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
for cmd in python3 tee cp mv mkdir date caelestia grep pgrep; do
    command -v "$cmd" >/dev/null 2>&1 || die "Required command not found: $cmd"
done

if [[ $mode == "rollback" ]]; then
    [[ -d $rollback_dir && -f $rollback_dir/shell.json && -f $rollback_dir/scheme.json ]] \
        || die 'Backup directory must contain shell.json and scheme.json.'
    [[ -f $shell_file && -f $scheme_file ]] || die 'Current Caelestia config/state files are missing.'
    info "Restoring Caelestia configuration from backup: ${rollback_dir#"$HOME"/}"
    for pair in "shell.json:$shell_file" "scheme.json:$scheme_file"; do
        name=${pair%%:*}
        target=${pair#*:}
        tmp="$(mktemp "${target}.k41-rollback.XXXXXX")"
        cp -- "$rollback_dir/$name" "$tmp"
        chmod --reference="$rollback_dir/$name" "$tmp"
        mv -f -- "$tmp" "$target"
    done
    info 'Rollback files restored. Restart the shell with: caelestia shell -r'
    exit 0
fi

command -v timeout >/dev/null 2>&1 || die 'timeout is required.'
[[ -f $profile_file ]] || die "Profile not found: $profile_file"
[[ -f $shell_file ]] || die "Active Caelestia config not found: $shell_file"
[[ -f $scheme_file ]] || die "Caelestia scheme state not found: $scheme_file"
[[ -d $config_root/caelestia && -d $state_root/caelestia ]] || die 'Caelestia config/state directories are missing.'

scheme_help="$(timeout 8s caelestia scheme set -h 2>&1)" || die 'Unable to inspect caelestia scheme set help.'
grep -q -- 'monochrome' <<<"$scheme_help" || die 'Installed Caelestia CLI does not expose the monochrome variant.'
grep -q -- 'caelestia' <<<"$scheme_help" || die 'Installed Caelestia CLI does not expose the caelestia scheme.'

python3 - "$profile_file" "$shell_file" "$scheme_file" <<'PY'
import json, pathlib, sys
for path in map(pathlib.Path, sys.argv[1:]):
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        raise SystemExit(f"Invalid JSON in {path.name}: {type(exc).__name__}: {exc}")
    if not isinstance(value, dict):
        raise SystemExit(f"{path.name} must contain a JSON object")
PY

mkdir -p -- "$report_root" "$backup_root"
report_dir="$report_root/$timestamp"
suffix=0
while ! mkdir -- "$report_dir" 2>/dev/null; do
    suffix=$((suffix + 1))
    report_dir="$report_root/$timestamp-$suffix"
done
log_file="$report_dir/run.log"
summary_file="$report_dir/summary.txt"
exec > >(tee -a "$log_file") 2>&1

status="FAILED"
backup_dir=""
restart_status="NOT_RUN"
shell_log_status="NOT_RUN"
warning_count=0
error_count=0
fatal_count=0
config_loaded_count=0
quickshell_process_count=0

write_summary() {
    local rc=$1
    if (( rc != 0 )); then status="FAILED (exit $rc)"; fi
    {
        printf 'K41 Caelestia Customization\n'
        printf 'Timestamp UTC: %s\n' "$timestamp"
        printf 'Status: %s\n' "$status"
        printf 'Scheme: caelestia / dark / monochrome\n'
        printf 'Shell restart: %s\n' "$restart_status"
        printf 'Shell runtime log: %s\n' "$shell_log_status"
        printf 'WARN/WARNING log lines: %s\n' "$warning_count"
        printf 'ERROR log lines: %s\n' "$error_count"
        printf 'FATAL log lines: %s\n' "$fatal_count"
        printf 'Configuration Loaded entries: %s\n' "$config_loaded_count"
        printf 'Quickshell processes observed: %s\n' "$quickshell_process_count"
        printf 'Backup: %s\n' "${backup_dir:-not-created}"
        printf 'Report: reports/caelestia-customization/%s/\n' "$(basename -- "$report_dir")"
        printf 'Mode: user configuration only; no packages or system services changed.\n'
    } >"$summary_file"
}

on_exit() {
    local rc=$?
    trap - EXIT
    if (( rc != 0 )) && [[ -n $backup_dir && -f $backup_dir/shell.json && -f $backup_dir/scheme.json ]]; then
        info 'Failure detected after backup; restoring original Caelestia files.'
        cp -- "$backup_dir/shell.json" "$shell_file" || true
        cp -- "$backup_dir/scheme.json" "$scheme_file" || true
    fi
    if [[ -f $log_file ]]; then
        read -r warning_count error_count fatal_count config_loaded_count < <(
            python3 - "$log_file" <<'PY'
import pathlib, re, sys
text = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace")
text = re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", text)
lines = text.splitlines()
warnings = sum(bool(re.search(r"\bWARN(?:ING)?\b", line, re.I)) for line in lines)
errors = sum(bool(re.search(r"\bERROR\b", line, re.I)) for line in lines)
fatals = sum(bool(re.search(r"\bFATAL\b", line, re.I)) for line in lines)
loaded = sum("Configuration Loaded" in line for line in lines)
print(warnings, errors, fatals, loaded)
PY
        )
        quickshell_process_count="$(pgrep -xc quickshell 2>/dev/null || true)"
        warning_count="${warning_count:-0}"
        error_count="${error_count:-0}"
        fatal_count="${fatal_count:-0}"
        config_loaded_count="${config_loaded_count:-0}"
        quickshell_process_count="${quickshell_process_count:-0}"
    fi
    if (( rc == 0 )); then
        if [[ $restart_status == UNCONFIRMED* || $restart_status == COMMAND_FAILED* || $shell_log_status == FAILED* ]] \
            || (( warning_count > 0 || error_count > 0 || fatal_count > 0 )); then
            status="SUCCESS_WITH_WARNINGS"
        elif [[ $restart_status == "NOT_RUN" ]]; then
            status="SUCCESS_RESTART_NOT_RUN"
        else
            status="SUCCESS"
        fi
    fi
    write_summary "$rc"
    info "Report: reports/caelestia-customization/$(basename -- "$report_dir")/"
}
trap on_exit EXIT

info "K41 Caelestia customization started (UTC $timestamp)"
info 'Changes: Rubik UI typography, CaskaydiaCove Mono, Caelestia dark monochrome scheme.'
info 'No shell tokens, wallpaper, package, service, or upstream package files are modified.'
printf 'Apply this profile? [y/N] '
IFS= read -r answer
[[ $answer =~ ^[Yy]([Ee][Ss])?$ ]] || die 'Cancelled by user.'

backup_dir="$backup_root/$timestamp"
suffix=0
while ! mkdir -- "$backup_dir" 2>/dev/null; do
    suffix=$((suffix + 1))
    backup_dir="$backup_root/$timestamp-$suffix"
done
cp -a -- "$shell_file" "$backup_dir/shell.json"
cp -a -- "$scheme_file" "$backup_dir/scheme.json"
info "Private backup created: ${backup_dir#"$HOME"/}"

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
PY

if ! timeout 15s caelestia scheme set -n caelestia -m dark -v monochrome; then
    info 'Scheme command failed; restoring both backed-up files.'
    cp -- "$backup_dir/shell.json" "$shell_file"
    cp -- "$backup_dir/scheme.json" "$scheme_file"
    die 'Caelestia scheme change failed; original files restored.'
fi
scheme_output="$(timeout 8s caelestia scheme get 2>&1)" || {
    cp -- "$backup_dir/shell.json" "$shell_file"
    cp -- "$backup_dir/scheme.json" "$scheme_file"
    die 'Could not verify active scheme; original files restored.'
}
if ! grep -Eiq 'Variant:[[:space:]]*monochrome' <<<"$scheme_output"; then
    cp -- "$backup_dir/shell.json" "$shell_file"
    cp -- "$backup_dir/scheme.json" "$scheme_file"
    die 'Active scheme did not report monochrome; original files restored.'
fi

python3 - "$shell_file" <<'PY'
import json, pathlib, sys
data = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
font = data.get("appearance", {}).get("font", {})
expected = {
    "clock": "Rubik", "workspaces": "Rubik", "headline": "Rubik",
    "title": "Rubik", "body": "Rubik", "label": "Rubik",
    "mono": "CaskaydiaCove NF",
}
for key, value in expected.items():
    actual = font.get(key)
    actual = actual.get("family") if isinstance(actual, dict) else actual
    if actual != value:
        raise SystemExit(f"Font setting verification failed: {key}")
print("PASS: merged typography settings verified.")
PY
info 'Caelestia profile applied and scheme variant verified.'

printf 'Restart Caelestia now and collect its runtime log? [Y/n] '
IFS= read -r restart_answer
if [[ -z $restart_answer || $restart_answer =~ ^[Yy]([Ee][Ss])?$ ]]; then
    info 'Running caelestia shell -r with a 30-second safety bound.'
    set +e
    timeout 30s caelestia shell -r
    restart_rc=$?
    set -e
    if (( restart_rc == 0 )); then
        restart_status="COMMAND_RETURNED"
        info 'Caelestia restart command returned successfully.'
    elif (( restart_rc == 124 )); then
        restart_status="FOREGROUND_TIMEOUT"
        info 'Restart command remained active for 30 seconds; runtime/process checks will determine whether the shell loaded.'
    else
        restart_status="COMMAND_FAILED (exit $restart_rc)"
        info "WARNING: Caelestia restart command exited with $restart_rc; profile files remain applied."
    fi

    info 'Collecting Caelestia runtime log with: caelestia shell -l'
    set +e
    timeout 20s caelestia shell -l
    shell_log_rc=$?
    set -e
    if (( shell_log_rc == 0 )); then
        shell_log_status="OK"
    else
        shell_log_status="FAILED (exit $shell_log_rc)"
        info "WARNING: Caelestia runtime log collector returned $shell_log_rc."
    fi

    if (( restart_rc == 124 )); then
        if grep -Fq 'Configuration Loaded' "$log_file" && [[ "$(pgrep -xc quickshell 2>/dev/null || true)" =~ ^[1-9][0-9]*$ ]]; then
            restart_status="CONFIRMED_AFTER_FOREGROUND_TIMEOUT"
            info 'PASS: runtime configuration loaded and a Quickshell process is present after the bounded restart.'
        else
            restart_status="UNCONFIRMED_AFTER_TIMEOUT"
            info 'WARNING: restart timed out and independent runtime confirmation was incomplete.'
        fi
    fi
else
    restart_status="SKIPPED_BY_USER"
    shell_log_status="SKIPPED_BY_USER"
    info 'Shell restart and runtime log collection skipped by user.'
fi

info 'Review WARN/WARNING/ERROR/FATAL counts and matching lines in run.log.'
info 'Rollback command: bash scripts/k41-apply-caelestia-profile.sh --rollback <backup-directory>'
