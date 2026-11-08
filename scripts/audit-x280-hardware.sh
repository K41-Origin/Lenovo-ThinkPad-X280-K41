#!/usr/bin/env bash
# Read-only ThinkPad X280 hardware and power baseline collector.
set -Eeuo pipefail
umask 077

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"

usage() {
  cat <<'USAGE'
Usage: bash scripts/audit-x280-hardware.sh

Collects a read-only hardware, battery, thermal, graphics, network, and
power-management snapshot into reports/hardware-audit/<UTC timestamp>/.
Run as the regular desktop user, without sudo.

The script does not install packages, change services, modify configuration,
write to firmware, or perform storage operations. Review reports before sharing.
USAGE
}

case "${1-}" in
  "") ;;
  -h|--help) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac

if (( EUID == 0 )); then
  printf 'ERROR: run this collector as your regular user, not with sudo.\n' >&2
  exit 1
fi

timestamp="$(date -u +'%Y%m%dT%H%M%SZ')"
report_root="$ROOT/reports/hardware-audit"
mkdir -p -- "$report_root"
run_dir="$report_root/$timestamp"
suffix=0
while ! mkdir -- "$run_dir" 2>/dev/null; do
  suffix=$((suffix + 1))
  run_dir="$report_root/$timestamp-$suffix"
done
chmod 0700 "$run_dir"
summary="$run_dir/summary.md"
diagnostics="$run_dir/diagnostics.txt"
: >"$summary"
: >"$diagnostics"
chmod 0600 "$summary" "$diagnostics"

capture() {
  local label="$1" binary="$2" rc
  shift 2
  {
    printf '\n===== %s =====\n' "$label"
    printf 'COMMAND:'
    printf ' %q' "$binary" "$@"
    printf '\n'
  } >>"$diagnostics"
  if ! command -v "$binary" >/dev/null 2>&1; then
    printf 'SKIPPED: command not installed (%s)\n' "$binary" >>"$diagnostics"
    return 0
  fi
  if "$binary" "$@" >>"$diagnostics" 2>&1; then
    printf 'COMMAND EXIT: 0\n' >>"$diagnostics"
  else
    rc=$?
    printf 'COMMAND EXIT: %s (collection continues)\n' "$rc" >>"$diagnostics"
  fi
}

capture_file() {
  local label="$1" path="$2"
  {
    printf '\n===== %s =====\n' "$label"
    if [[ -r "$path" ]]; then
      cat -- "$path"
    else
      printf 'UNAVAILABLE: %s\n' "$path"
    fi
  } >>"$diagnostics"
}

{
  printf '# ThinkPad X280 hardware audit\n\n'
  printf -- '- Captured (UTC): %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Repository commit: %s\n' "$(git rev-parse HEAD 2>/dev/null || printf unknown)"
  printf -- '- Kernel: %s\n' "$(uname -sr)"
  printf -- '- Architecture: %s\n' "$(uname -m)"
  if [[ -r /etc/os-release ]]; then
    . /etc/os-release
    printf -- '- Distribution: %s\n' "${PRETTY_NAME:-unknown}"
  else
    printf -- '- Distribution: unknown\n'
  fi
  printf -- '- Collection result: **COMPLETED** (not a hardware acceptance PASS)\n'
  printf -- '- Detailed snapshot: diagnostics.txt\n'
  printf '\nThis collector is read-only and does not require sudo. It omits common unique identifiers such as DMI serials, disk serials, filesystem UUIDs, MAC addresses, and Wi-Fi SSIDs. Review both files before committing or sharing.\n'
} >>"$summary"

capture 'Kernel and operating system' uname -a
capture 'CPU topology and features' lscpu
capture 'Memory summary' free -h
capture 'DMI system identity (non-unique fields only)' bash -c '
  for field in sys_vendor product_name product_version bios_vendor bios_version bios_date board_vendor board_name; do
    file="/sys/class/dmi/id/$field"
    if [[ -r $file ]]; then printf "%s: " "$field"; cat "$file"; fi
  done
'
capture 'PCI devices and bound drivers' lspci -nnk
capture 'USB devices (no device serials requested)' lsusb
capture 'Block devices (serials and UUIDs intentionally excluded)' lsblk -e7 -o NAME,TYPE,SIZE,MODEL,TRAN,RM,RO,FSTYPE,MOUNTPOINTS
capture 'Graphics renderer' glxinfo -B
capture 'Vulkan summary' vulkaninfo --summary
capture 'Network device state (SSID and MAC omitted)' nmcli -t -f DEVICE,TYPE,STATE device status
capture 'Radio block state' rfkill list
capture 'Brightness device inventory' brightnessctl -l
capture 'Sensor summary' sensors
capture 'Root filesystem mount' findmnt -n -o TARGET,FSTYPE,OPTIONS /

{
  printf '\n===== Battery and power-supply snapshot =====\n'
  found=0
  for device in /sys/class/power_supply/*; do
    [[ -d $device ]] || continue
    found=1
    printf '[%s]\n' "${device##*/}"
    for field in type status present technology manufacturer model_name capacity       energy_now energy_full energy_full_design charge_now charge_full charge_full_design       power_now current_now voltage_now cycle_count charge_control_start_threshold       charge_control_end_threshold; do
      if [[ -r $device/$field ]]; then
        printf '%s: %s\n' "$field" "$(cat "$device/$field")"
      fi
    done
  done
  ((found == 1)) || printf 'No power-supply devices found.\n'
} >>"$diagnostics"

{
  printf '\n===== Thermal zones =====\n'
  found=0
  for zone in /sys/class/thermal/thermal_zone*; do
    [[ -r $zone/temp ]] || continue
    found=1
    printf '%s (%s): %s millidegrees C\n' "${zone##*/}"       "$(cat "$zone/type" 2>/dev/null || printf unknown)" "$(cat "$zone/temp")"
  done
  ((found == 1)) || printf 'No readable thermal zones found.\n'
  printf '\n===== Fan and hwmon inventory =====\n'
  for hwmon in /sys/class/hwmon/hwmon*; do
    [[ -d $hwmon ]] || continue
    printf '[%s] name=%s\n' "${hwmon##*/}" "$(cat "$hwmon/name" 2>/dev/null || printf unknown)"
    for input in "$hwmon"/temp*_input "$hwmon"/fan*_input; do
      [[ -r $input ]] || continue
      printf '%s: %s\n' "${input##*/}" "$(cat "$input")"
    done
  done
} >>"$diagnostics"

{
  printf '\n===== Power-management service state =====\n'
  for service in tlp power-profiles-daemon tuned thermald upower bluetooth NetworkManager; do
    printf '[%s]\n' "$service"
    if command -v systemctl >/dev/null 2>&1; then
      systemctl show "$service" -p LoadState -p ActiveState -p UnitFileState --no-pager 2>&1 || true
    else
      printf 'systemctl unavailable\n'
    fi
  done
  printf '\n===== User-session services =====\n'
  for service in power-profiles-daemon.service pipewire.service wireplumber.service; do
    printf '[%s]\n' "$service"
    if command -v systemctl >/dev/null 2>&1; then
      systemctl --user show "$service" -p LoadState -p ActiveState --no-pager 2>&1 || true
    else
      printf 'systemctl unavailable\n'
    fi
  done
} >>"$diagnostics"

capture_file 'Kernel module: i915' /sys/module/i915/version
capture 'Loaded relevant kernel modules' lsmod
capture 'Kernel command line (review before sharing)' bash -c 'sed -E "s/(rd\.luks\.name=)[^ ]+/\1[REDACTED]/g; s/(cryptdevice=)[^ ]+/\1[REDACTED]/g" /proc/cmdline'

chmod 0600 "$summary" "$diagnostics"
printf 'Hardware audit report created: %s\n' "$run_dir"
printf 'Collection completed; no hardware tuning or acceptance result is implied.\n'
printf 'Review diagnostics.txt for privacy before committing/pushing the report.\n'
