#!/usr/bin/env bash
# Capture a Caelestia restart from the active Wayland session.
set -Eeuo pipefail
umask 077

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

(( EUID != 0 )) || die 'Do not run with sudo; execute as the regular desktop user.'
[[ -n ${WAYLAND_DISPLAY:-} ]] || die 'WAYLAND_DISPLAY is unset. Run this from a terminal inside the active Wayland session.'
[[ -n ${XDG_RUNTIME_DIR:-} && -d $XDG_RUNTIME_DIR ]] || die 'XDG_RUNTIME_DIR is unset or invalid.'
command -v caelestia >/dev/null 2>&1 || die 'caelestia command was not found.'
command -v tee >/dev/null 2>&1 || die 'tee command was not found.'

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd -- "$script_dir/.." && pwd -P)"
[[ -d $repo_root/.git ]] || die "Run from a Git checkout; repository root not found: $repo_root"
[[ $(stat -c %u "$repo_root") == "$EUID" ]] || die 'Repository checkout is not owned by the current user.'

report_dir="$repo_root/reports/lockscreen-apply"
[[ ! -L $repo_root/reports && ! -L $report_dir ]] || die 'Refusing symlink report directory.'
mkdir -p -- "$report_dir"
[[ -d $report_dir && -w $report_dir ]] || die "Report directory is not writable: $report_dir"

timestamp="$(date -u +'%Y%m%dT%H%M%SZ')"
report="$report_dir/${timestamp}-session-restart.log"
[[ ! -e $report && ! -L $report ]] || die "Report already exists; refusing to overwrite: $report"
: > "$report" || die "Cannot create report: $report"

# Log only whether sensitive/session variables are present, never their values.
{
    printf '========== K41 CAELESTIA SESSION RESTART ==========\n'
    printf 'Timestamp (UTC): %s\n' "$timestamp"
    printf 'User UID: %s\n' "$EUID"
    printf 'Kernel: %s\n' "$(uname -sr)"
    printf 'Wayland session: present\n'
    printf 'Hyprland session signature: %s\n' "${HYPRLAND_INSTANCE_SIGNATURE:+present}"
    [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] || printf 'Hyprland session signature: absent\n'
    printf 'Wayland socket: '
    if [[ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]]; then
        printf 'present\n'
    else
        printf 'not found at expected runtime path\n'
    fi
    printf '\n========== RESTART OUTPUT ==========\n'
} >> "$report"

printf 'Running Caelestia restart in the current desktop session...\n'
set +e
caelestia shell -r -d 2>&1 | tee -a "$report"
command_status=${PIPESTATUS[0]}
set -e

{
    printf '\n========== SUMMARY ==========\n'
    printf 'Restart command exit code: %s\n' "$command_status"
    if (( command_status == 0 )); then
        printf 'Command result: EXITED SUCCESSFULLY (runtime behavior still requires visual/functional verification)\n'
    else
        printf 'Command result: FAILED\n'
    fi
    printf 'Report file: %s\n' "$report"
} | tee -a "$report"

printf '\nReport created: %s\n' "$report"
printf 'Review it for personal information, then commit and push it for analysis.\n'
exit "$command_status"
