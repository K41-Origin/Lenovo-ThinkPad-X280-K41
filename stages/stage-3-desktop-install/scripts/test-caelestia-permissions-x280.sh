#!/usr/bin/env bash
# Read-only Caelestia cache/state and Bluetooth diagnostic for ThinkPad X280.
set -Eeuo pipefail
umask 077

ROOT="$(git -C "$(dirname -- "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
cd "$ROOT"

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
if (( EUID == 0 )); then
  fail 'run as the regular desktop user, never with sudo.'
fi
if [[ -z ${HYPRLAND_INSTANCE_SIGNATURE:-} || -z ${WAYLAND_DISPLAY:-} ]]; then
  fail 'run this from a terminal inside the active Hyprland session.'
fi

timestamp="$(date -u +'%Y%m%dT%H%M%SZ')"
report_root="$ROOT/reports/stage-3-desktop-install/caelestia-permissions-diagnostics"
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
: >"$log"
: >"$summary"
chmod 0600 "$log" "$summary"

# A failed optional diagnostic command is evidence, not a reason to stop collection.
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
  else
    rc=$?
    printf 'COMMAND EXIT: %s (collection continues)\n' "$rc" >>"$log"
  fi
  return 0
}

{
  printf '# Caelestia cache/state permissions diagnostic\n\n'
  printf -- '- Captured (UTC): %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Repository commit: %s\n' "$(git rev-parse HEAD 2>/dev/null || printf unknown)"
  printf -- '- Kernel: %s\n' "$(uname -sr)"
  printf -- '- Collection: **COMPLETED** (read-only; not a repair or acceptance test)\n'
  printf '\nInspect and redact private host/user information before committing this report. No ownership, permissions, files, packages, or services are changed.\n'
} >>"$summary"

{
  printf '# Identity and environment\n'
  printf 'Repository commit: %s\n' "$(git rev-parse HEAD 2>/dev/null || printf unknown)"
  printf 'User: %s (uid=%s gid=%s)\n' "$(id -un)" "$(id -u)" "$(id -g)"
  printf 'HOME: %s\n' "$HOME"
  printf 'Umask: '; umask
  printf 'Hyprland session: detected\n'
  printf 'XDG_CACHE_HOME: %s\n' "${XDG_CACHE_HOME:-<unset>}"
  printf 'XDG_STATE_HOME: %s\n' "${XDG_STATE_HOME:-<unset>}"
} >>"$log"

cache_root="${XDG_CACHE_HOME:-$HOME/.cache}"
state_root="${XDG_STATE_HOME:-$HOME/.local/state}"
paths=(
  "$HOME"
  "$cache_root"
  "$cache_root/mesa_shader_cache"
  "$cache_root/caelestia"
  "$cache_root/caelestia/imagecache"
  "$state_root"
  "$state_root/caelestia"
  "$state_root/caelestia/scheme.json"
  "$HOME/.cache/ddcutil"
  "$HOME/.cache/ddcutil/dsa"
)

for path in "${paths[@]}"; do
  capture "Path metadata: $path" stat -c 'path=%n type=%F owner=%U:%G uid=%u gid=%g mode=%a permissions=%A' -- "$path"
  capture "Path traversal: $path" namei -l -- "$path"
done

if command -v getfacl >/dev/null 2>&1; then
  for path in "$HOME" "$cache_root" "$cache_root/caelestia" "$state_root" "$state_root/caelestia"; do
    capture "ACL: $path" getfacl -p -- "$path"
  done
else
  printf '\n===== ACL inspection =====\ngetfacl is not installed; ACL details not collected.\n' >>"$log"
fi

capture 'Caelestia and Quickshell packages' pacman -Q caelestia-shell caelestia-cli quickshell-git
capture 'Bluetooth service status' systemctl status bluetooth.service --no-pager
capture 'Bluetooth service enabled state' systemctl is-enabled bluetooth.service
capture 'Bluetooth controller listing' bluetoothctl list
capture 'BlueZ D-Bus service ownership' busctl --system status org.bluez
capture 'Recent Caelestia/Quickshell user journal errors' journalctl --user -b -p err --no-pager -n 100

printf 'Caelestia permissions diagnostic report created: %s\n' "$run_dir"
printf 'Review summary.md and diagnostics.txt before committing/pushing. This script makes no repairs.\n'
