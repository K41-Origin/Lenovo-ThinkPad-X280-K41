#!/usr/bin/env bash
# One-command functional validation for the active ThinkPad X280 Hyprland session.
set -Eeuo pipefail
umask 077

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
if (( EUID == 0 )); then
  fail 'run as the regular desktop user; do not use sudo.'
fi
[[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} && -n ${WAYLAND_DISPLAY:-} ]] ||
  fail 'run from a terminal inside the active Hyprland session.'
for command_name in bash date mkdir chmod stat qs caelestia sleep pgrep journalctl; do
  command -v "$command_name" >/dev/null 2>&1 || fail "required command is missing: $command_name"
done
[[ -x "$ROOT/scripts/test-desktop-x280.sh" ]] || fail 'desktop diagnostic collector is missing.'
[[ -x "$ROOT/scripts/test-caelestia-x280.sh" ]] || fail 'Caelestia diagnostic collector is missing.'

timestamp="$(date -u +'%Y%m%dT%H%M%SZ')"
report_root="$ROOT/reports/desktop-validation"
mkdir -p -- "$report_root"
run_dir="$report_root/$timestamp"
suffix=0
while ! mkdir -- "$run_dir" 2>/dev/null; do
  suffix=$((suffix + 1))
  run_dir="$report_root/$timestamp-$suffix"
done
chmod 0700 "$run_dir"
summary="$run_dir/summary.md"
checklist="$run_dir/manual-checklist.md"
log="$run_dir/validation.log"
: >"$summary"
: >"$checklist"
: >"$log"
chmod 0600 "$summary" "$checklist" "$log"

overall_rc=0
desktop_rc=0
caelestia_rc=0
restart_result='NOT TESTED — operator declined or skipped restart'
cache_result='NOT TESTED — Caelestia restart was not performed'

printf 'K41 desktop functional validation\n'
printf 'Report: %s\n\n' "$run_dir"
printf '%s\n' 'This script collects diagnostics and performs a controlled Caelestia restart only after your confirmation.'
printf '%s\n' 'Save your work. Restarting Caelestia briefly closes its panel/widgets; Hyprland itself is not restarted.'
printf '\n'

printf '%s\n' '--- Desktop diagnostics ---' | tee -a "$log"
if K41_REPORT_DIR="$run_dir/desktop" bash "$ROOT/scripts/test-desktop-x280.sh" >>"$log" 2>&1; then
  printf 'Desktop collector: PASS (collection completed)\n' | tee -a "$log"
else
  desktop_rc=$?
  overall_rc=1
  printf 'Desktop collector: FAIL (exit %s)\n' "$desktop_rc" | tee -a "$log"
fi

printf '\n%s\n' '--- Caelestia diagnostics ---' | tee -a "$log"
if K41_REPORT_DIR="$run_dir/caelestia" bash "$ROOT/scripts/test-caelestia-x280.sh" >>"$log" 2>&1; then
  printf 'Caelestia collector: PASS (collection completed)\n' | tee -a "$log"
else
  caelestia_rc=$?
  overall_rc=1
  printf 'Caelestia collector: FAIL (exit %s)\n' "$caelestia_rc" | tee -a "$log"
fi

printf '\n'
if [[ -t 0 ]]; then
  read -r -p 'Restart Caelestia now to verify cache creation and fresh runtime logs? [y/N] ' answer
else
  answer='n'
fi

if [[ $answer =~ ^[Yy]$ ]]; then
  printf '%s\n' 'Restarting Caelestia shell...' | tee -a "$log"
  if qs -c caelestia kill >>"$log" 2>&1; then
    sleep 2
    if caelestia shell -d >>"$log" 2>&1; then
      sleep 5
      if pgrep -af '[q]uickshell.*caelestia|[q]s.*caelestia|[c]aelestia shell' >/dev/null 2>&1; then
        restart_result='PASS — Caelestia process detected after restart'
      else
        restart_result='FAIL — start command returned success but no Caelestia process was detected'
        overall_rc=1
      fi
    else
      restart_result='FAIL — caelestia shell -d returned non-zero'
      overall_rc=1
    fi
  else
    restart_result='FAIL — qs -c caelestia kill returned non-zero'
    overall_rc=1
  fi

  {
    printf '\n===== Cache directory ownership after restart =====\n'
    for cache_path in "$HOME/.cache" "$HOME/.cache/mesa_shader_cache" "$HOME/.cache/caelestia" "$HOME/.cache/caelestia/imagecache" "$HOME/.cache/ddcutil"; do
      if [[ -e $cache_path || -L $cache_path ]]; then
        stat -c '%n | type=%F | owner=%U:%G | mode=%a' -- "$cache_path"
      else
        printf 'ABSENT (not automatically a failure): %s\n' "$cache_path"
      fi
    done
    printf '\n===== Fresh Caelestia runtime log =====\n'
    qs -c caelestia log
    printf '\n===== Recent user errors =====\n'
    journalctl --user -b -p err --no-pager -n 60
  } >>"$log" 2>&1 || {
    cache_result='INCOMPLETE — one or more cache/log inspection commands failed; inspect validation.log'
    overall_rc=1
  }
  if [[ $restart_result == PASS* ]]; then
    cache_result='COLLECTED — inspect validation.log for ownership, permission errors, and cache paths; directory absence alone is not a failure'
  fi
else
  printf '%s\n' 'Caelestia restart skipped by operator.' | tee -a "$log"
fi

{
  printf '# K41 ThinkPad X280 desktop validation\n\n'
  printf -- '- Captured (UTC): %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Repository commit: %s\n' "$(git rev-parse HEAD 2>/dev/null || printf unknown)"
  printf -- '- Kernel: %s\n' "$(uname -sr)"
  printf -- '- Desktop collector exit: %s\n' "$desktop_rc"
  printf -- '- Caelestia collector exit: %s\n' "$caelestia_rc"
  printf -- '- Caelestia restart: %s\n' "$restart_result"
  printf -- '- Cache/runtime evidence: %s\n' "$cache_result"
  printf -- '- Automated collection: COMPLETED WITH REVIEW REQUIRED\n'
  printf '\nCollection does not prove physical hardware or UI acceptance. Complete manual-checklist.md and inspect all reports before sharing. Reports may contain device, network, host, and log information; do not push them without review/redaction.\n'
  printf '\n## Report contents\n\n- `desktop/`: desktop inventory and generated checklist\n- `caelestia/`: Caelestia runtime diagnostics and generated checklist\n- `validation.log`: collector output and post-restart cache/runtime evidence\n- `manual-checklist.md`: consolidated physical acceptance checklist\n'
} >>"$summary"

cat >"$checklist" <<'CHECKLIST'
# Manual ThinkPad X280 desktop acceptance

For each row, replace NOT TESTED with PASS or FAIL and add concise evidence. If a feature is not required or unavailable, leave NOT TESTED and explain why. Do not mark a feature PASS merely because a device or process was detected.

| Check | Result | Notes / reproduction steps |
|---|---|---|
| Hyprland starts and remains stable | NOT TESTED | |
| Display resolution, scaling, refresh rate | NOT TESTED | |
| External display (if available) | NOT TESTED | |
| Keyboard typing and function/media keys | NOT TESTED | |
| TrackPoint pointer and buttons | NOT TESTED | |
| Touchpad pointer, click, tap, scroll, gestures | NOT TESTED | |
| Brightness keys and brightness control | NOT TESTED | |
| Volume/mute keys and speaker output | NOT TESTED | |
| Microphone input and recording/playback | NOT TESTED | |
| Wi-Fi disconnect/reconnect | NOT TESTED | |
| Bluetooth (only if required) | NOT TESTED | |
| Terminal opens and accepts input | NOT TESTED | |
| File manager opens and basic navigation works | NOT TESTED | |
| Launcher opens and accepts keyboard input | NOT TESTED | |
| Caelestia panel appears and remains responsive | NOT TESTED | |
| Caelestia dashboard, widgets, and indicators | NOT TESTED | |
| Notifications appear and dismiss | NOT TESTED | |
| Wallpaper/theme display | NOT TESTED | |
| Screenshot portal (if required) | NOT TESTED | |
| Screen-sharing portal (if required) | NOT TESTED | |
| Screen lock and unlock | NOT TESTED | |
| Logout returns to a usable TTY; login works again | NOT TESTED | |
| No repeated critical errors or crashes during normal use | NOT TESTED | |

## Overall Stage 4 result

NOT TESTED

## Failure details

None recorded. Add exact symptoms, reproduction steps, and approximate UTC time for each failure.
CHECKLIST

chmod 0600 "$summary" "$checklist" "$log"
printf '\nValidation report created: %s\n' "$run_dir"
printf '1. Complete: %s\n' "$checklist"
printf '2. Inspect and redact: %s\n' "$run_dir"
printf '3. Share only this reviewed report directory in your next push.\n'
printf 'Automated collection exit: %s (physical acceptance remains manual).\n' "$overall_rc"
exit "$overall_rc"
