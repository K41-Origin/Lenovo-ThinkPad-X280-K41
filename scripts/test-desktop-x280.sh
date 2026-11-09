#!/usr/bin/env bash
# Read-only diagnostic collector for a running ThinkPad X280 Hyprland desktop.
set -Eeuo pipefail
umask 077

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"

if (( EUID == 0 )); then
  printf 'ERROR: run this as your regular desktop user, not with sudo.\n' >&2
  exit 1
fi

timestamp="$(date -u +'%Y%m%dT%H%M%SZ')"
if [[ -n ${K41_REPORT_DIR:-} ]]; then
  run_dir=$K41_REPORT_DIR
  mkdir -p -- "$run_dir"
else
  report_root="$ROOT/reports/desktop-diagnostics"
  mkdir -p -- "$report_root"
  run_dir="$report_root/$timestamp"
  suffix=0
  while ! mkdir -- "$run_dir" 2>/dev/null; do
    suffix=$((suffix + 1))
    run_dir="$report_root/$timestamp-$suffix"
  done
fi
chmod 0700 "$run_dir"
diag="$run_dir/diagnostics.txt"
summary="$run_dir/summary.md"
coverage="$run_dir/coverage-limitations.md"
: >"$diag"
: >"$summary"
: >"$coverage"
chmod 0600 "$diag" "$summary" "$coverage"

capture() {
  local label=$1 rc
  shift
  {
    printf '\n===== %s =====\n' "$label"
    printf 'COMMAND:'
    printf ' %q' "$@"
    printf '\n'
  } >>"$diag"
  if [[ $label == 'PulseAudio compatibility server' ]]; then
    # pactl info includes the local PulseAudio authentication cookie; never publish it.
    if "$@" 2>&1 | sed -E '/^Cookie:/d' >>"$diag"; then
      printf 'COMMAND EXIT: 0\n' >>"$diag"
    else
      rc=$?
      printf 'COMMAND EXIT: %s (diagnostic unavailable or command reported an error)\n' "$rc" >>"$diag"
    fi
  elif "$@" >>"$diag" 2>&1; then
    printf 'COMMAND EXIT: 0\n' >>"$diag"
  else
    rc=$?
    printf 'COMMAND EXIT: %s (diagnostic unavailable or command reported an error)\n' "$rc" >>"$diag"
  fi
}

{
  printf '# ThinkPad X280 desktop diagnostic collection\n\n'
  printf -- '- Captured (UTC): %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Repository commit: %s\n' "$(git rev-parse HEAD 2>/dev/null || printf unknown)"
  printf -- '- Repository worktree: %s\n' "$(if [[ -z $(git status --porcelain 2>/dev/null) ]]; then printf clean; else printf 'has local changes'; fi)"
  printf -- '- Kernel: %s\n' "$(uname -sr)"
  printf -- '- Architecture: %s\n' "$(uname -m)"
  if [[ -r /etc/os-release ]]; then
    . /etc/os-release
    printf -- '- Distribution: %s\n' "${PRETTY_NAME:-unknown}"
  else
    printf -- '- Distribution: unknown (/etc/os-release unavailable)\n'
  fi
  printf -- '- Current session: %s\n' "${XDG_SESSION_TYPE:-unknown}"
  printf -- '- Wayland display detected: %s\n' "${WAYLAND_DISPLAY:+yes}"
  printf -- '- Hyprland instance detected: %s\n' "${HYPRLAND_INSTANCE_SIGNATURE:+yes}"
  printf -- '- Collection result: **COMPLETED** (this is not a hardware PASS)\n'
  printf -- '- Diagnostic details: diagnostics.txt\n'
  printf -- '- Coverage limits: coverage-limitations.md\n'
  printf '\nThis collector is read-only: it does not install packages, change services, edit configuration, or run privileged commands. Review all files for private information before committing/pushing.\n'
} >>"$summary"

{
  printf '# Environment and session\n'
  printf 'Captured (UTC): %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  printf 'Repository commit: %s\n' "$(git rev-parse HEAD 2>/dev/null || printf unknown)"
  printf 'Kernel: %s\n' "$(uname -sr)"
  printf 'Architecture: %s\n' "$(uname -m)"
  printf '\n'
} >>"$diag"

capture 'Installed desktop packages' pacman -Q hyprland quickshell quickshell-git caelestia-shell caelestia-cli pipewire pipewire-audio pipewire-pulse wireplumber xdg-desktop-portal xdg-desktop-portal-hyprland xdg-desktop-portal-gtk mesa vulkan-intel
{
  printf '\n===== Executable availability =====\n'
  for binary in start-hyprland Hyprland hyprctl qs caelestia foot thunar wofi wpctl pactl nmcli rfkill lspci lsusb brightnessctl upower; do
    if command -v "$binary" >/dev/null 2>&1; then
      printf 'FOUND: %s -> %s\n' "$binary" "$(command -v "$binary")"
    else
      printf 'MISSING: %s\n' "$binary"
    fi
  done
} >>"$diag"

if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
  capture 'Hyprland system information' hyprctl systeminfo
  capture 'Connected monitors' hyprctl monitors
  capture 'Input devices' hyprctl devices
  capture 'Hyprland configuration validation' hyprctl configerrors
  capture 'Quickshell processes' pgrep -af quickshell
  capture 'Caelestia processes' pgrep -af caelestia
else
  printf '\n===== Hyprland runtime checks =====\nHyprland session not detected in this shell; runtime checks were not run. Run this script from a terminal inside the active Hyprland session.\n' >>"$diag"
fi

capture 'User audio devices and PipeWire graph' wpctl status
capture 'PulseAudio compatibility server' pactl info
capture 'User PipeWire/WirePlumber service state' systemctl --user --no-pager --plain status pipewire.service pipewire-pulse.service wireplumber.service
capture 'Network device state (connection names omitted)' nmcli -t -f DEVICE,TYPE,STATE device status
capture 'Radio block state' rfkill list
capture 'PCI graphics, network, and audio hardware' lspci -nnk
capture 'USB devices' lsusb
capture 'Brightness device inventory' brightnessctl -l
capture 'Power supply device list' upower -e

{
  printf '\n===== Battery and thermal sysfs snapshot =====\n'
  found=0
  for battery in /sys/class/power_supply/BAT*; do
    [[ -d $battery ]] || continue
    found=1
    printf '[%s]\n' "${battery##*/}"
    for field in status capacity energy_now energy_full power_now voltage_now; do
      if [[ -r $battery/$field ]]; then
        printf '%s: %s\n' "$field" "$(cat "$battery/$field")"
      fi
    done
  done
  ((found == 1)) || printf 'No BAT* sysfs device found.\n'
  for zone in /sys/class/thermal/thermal_zone*; do
    [[ -r $zone/temp ]] || continue
    printf '%s (%s): %s millidegrees C\n' "${zone##*/}" "$(cat "$zone/type" 2>/dev/null || printf unknown)" "$(cat "$zone/temp")"
  done
} >>"$diag"

capture 'User journal errors from this boot (last 60)' journalctl --user -b -p err --no-pager -n 60
capture 'System journal errors from this boot (last 60; may be permission-limited)' journalctl -b -p err --no-pager -n 60

cat >"$coverage" <<'COVERAGE'
# Stage 4 desktop validation coverage limits

This collector gathers software, device-enumeration, service, and journal evidence only.
It does not perform or request visual/physical acceptance checks.

The following behaviors are not established by this report: panel appearance, keyboard
and pointing-device interaction, brightness/media keys, speaker/microphone I/O, Wi-Fi
reconnection, Bluetooth pairing, portal UI interaction, or lock-screen interaction.
No physical/visual PASS is claimed. Stage 4 remains limited to automated runtime/log
evidence; hardware tuning and suspend/resume are separate later-stage work.
COVERAGE
chmod 0600 "$diag" "$summary" "$coverage"
printf 'Diagnostic report created: %s\n' "$run_dir"
printf 'Review diagnostics, summary, and coverage limitations before sharing.\n'
printf 'Collection completed; Stage 4 reports automated evidence only and makes no physical/visual acceptance claim.\n'
