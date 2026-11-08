#!/usr/bin/env bash
# Caelestia/Quickshell runtime diagnostic for the ThinkPad X280 Hyprland session.
set -Eeuo pipefail
umask 077

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
if (( EUID == 0 )); then
  fail 'run as the regular desktop user, never with sudo.'
fi
if [[ -z ${HYPRLAND_INSTANCE_SIGNATURE:-} || -z ${WAYLAND_DISPLAY:-} ]]; then
  fail 'run this from a terminal inside the active Hyprland session.'
fi
command -v caelestia >/dev/null 2>&1 || fail 'caelestia CLI is missing from PATH.'
command -v qs >/dev/null 2>&1 || fail 'Quickshell CLI (qs) is missing from PATH.'

timestamp="$(date -u +'%Y%m%dT%H%M%SZ')"
report_root="$ROOT/reports/caelestia-diagnostics"
mkdir -p -- "$report_root"
run_dir="$report_root/$timestamp"
suffix=0
while ! mkdir -- "$run_dir" 2>/dev/null; do
  suffix=$((suffix + 1))
  run_dir="$report_root/$timestamp-$suffix"
done
chmod 0700 "$run_dir"
log="$run_dir/diagnostics.txt"
summary="$run_dir/summary.md"
checklist="$run_dir/manual-checklist.md"
: >"$log"
: >"$summary"
: >"$checklist"
chmod 0600 "$log" "$summary" "$checklist"

capture() {
  local label=$1 rc
  shift
  {
    printf '\n===== %s =====\nCOMMAND:' "$label"
    printf ' %q' "$@"
    printf '\n'
  } >>"$log"
  if "$@" >>"$log" 2>&1; then
    printf 'COMMAND EXIT: 0\n' >>"$log"
    return 0
  else
    rc=$?
    printf 'COMMAND EXIT: %s\n' "$rc" >>"$log"
  fi
}

is_caelestia_running() {
  pgrep -af '[q]uickshell.*caelestia|[q]s.*caelestia|[c]aelestia shell' >/dev/null 2>&1
}

started_by_test=0
start_result='not attempted'
if is_caelestia_running; then
  start_result='already running before test; left untouched'
else
  start_result='start command attempted'
  {
    printf '\n===== Start Caelestia shell =====\n'
    printf 'COMMAND: caelestia shell -d\n'
  } >>"$log"
  if caelestia shell -d >>"$log" 2>&1; then
    started_by_test=1
    printf 'START COMMAND EXIT: 0\n' >>"$log"
  else
    rc=$?
    printf 'START COMMAND EXIT: %s\n' "$rc" >>"$log"
    start_result="start command failed (exit $rc)"
  fi
  sleep 8
fi

running_after='no'
if is_caelestia_running; then
  running_after='yes'
fi

{
  printf '# Caelestia runtime diagnostic\n\n'
  printf -- '- Captured (UTC): %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Repository commit: %s\n' "$(git rev-parse HEAD 2>/dev/null || printf unknown)"
  printf -- '- Kernel: %s\n' "$(uname -sr)"
  printf -- '- Hyprland session: detected\n'
  printf -- '- Caelestia start action: %s\n' "$start_result"
  printf -- '- Caelestia/Quickshell process detected after check: %s\n' "$running_after"
  printf -- '- Started by this test: %s\n' "$([[ $started_by_test == 1 ]] && printf yes || printf no)"
  printf -- '- Collection result: **COMPLETED** (not a full UI/physical PASS)\n'
  printf '\nReview all files for private information before committing. No configuration or package files are changed. If Caelestia was not running, the script attempts to start it and leaves it running for interactive testing.\n'
} >>"$summary"

{
  printf '# Session and package information\n'
  printf 'Captured (UTC): %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  printf 'Repository commit: %s\n' "$(git rev-parse HEAD 2>/dev/null || printf unknown)"
  printf 'Kernel: %s\n' "$(uname -sr)"
  printf 'Hyprland: %s\n' "$(hyprctl version 2>&1 | head -n 3)"
  printf 'Wayland display: %s\n' "$WAYLAND_DISPLAY"
  printf 'Hyprland instance: present (value intentionally omitted)\n'
} >>"$log"

capture 'Installed Caelestia and Quickshell packages' pacman -Q caelestia-shell caelestia-cli quickshell quickshell-git
capture 'Caelestia CLI help/version' caelestia --help
capture 'Quickshell CLI version' qs --version
capture 'Caelestia shell IPC command discovery' caelestia shell -s
capture 'Quickshell CLI help' qs --help
capture 'Caelestia process list' pgrep -af '[q]uickshell.*caelestia|[q]s.*caelestia|[c]aelestia shell'
capture 'Caelestia shell runtime log' qs -c caelestia log
capture 'Recent user journal errors' journalctl --user -b -p err --no-pager -n 80

{
  printf '# Manual Caelestia acceptance checklist\n\n'
  printf 'Isi setiap item dengan PASS, FAIL, atau NOT TESTED. Untuk FAIL, catat gejala dan langkah reproduksi.\n\n'
  cat <<'CHECKLIST'
| Check | Result | Notes |
|---|---|---|
| Caelestia process remains running after startup | NOT TESTED | |
| Top bar/panel appears and remains responsive | NOT TESTED | |
| Launcher opens and accepts keyboard input | NOT TESTED | |
| Dashboard/sidebar opens and closes | NOT TESTED | |
| Notification display works | NOT TESTED | |
| Quick settings/widgets render without QML errors | NOT TESTED | |
| Wallpaper/theme integration works | NOT TESTED | |
| Audio/network/battery indicators show plausible state | NOT TESTED | |
| No repeated crash/restart or visible rendering glitches | NOT TESTED | |

## Overall Caelestia result

NOT TESTED

## Failure details

None recorded.
CHECKLIST
} >>"$checklist"

chmod 0600 "$log" "$summary" "$checklist"
printf 'Caelestia diagnostic report created: %s\n' "$run_dir"
printf 'Review diagnostics.txt, summary.md, and manual-checklist.md before committing/pushing.\n'
printf 'The script does not stop Caelestia; it leaves the shell running for visual checks.\n'
