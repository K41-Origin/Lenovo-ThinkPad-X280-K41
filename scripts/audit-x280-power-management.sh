#!/usr/bin/env bash
# Read-only ThinkPad X280 power-management baseline collector.
set -Eeuo pipefail
umask 077
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"
usage() {
  cat <<'USAGE'
Usage: bash scripts/audit-x280-power-management.sh
Collects CPU frequency/EPP, Intel pstate, platform profile, AC/battery,
power-profile daemon, and power-service state into reports/power-management-audit/.
Run as the regular desktop user, without sudo. This collector is read-only.
USAGE
}
case "${1-}" in "" ) ;; -h|--help) usage; exit 0 ;; *) usage >&2; exit 2 ;; esac
if (( EUID == 0 )); then
  printf 'ERROR: run this collector as your regular user, not with sudo.\n' >&2
  exit 1
fi
timestamp="$(date -u +'%Y%m%dT%H%M%SZ')"
report_root="$ROOT/reports/power-management-audit"
mkdir -p -- "$report_root"
run_dir="$report_root/$timestamp"
suffix=0
while ! mkdir -- "$run_dir" 2>/dev/null; do
  suffix=$((suffix + 1)); run_dir="$report_root/$timestamp-$suffix"
done
chmod 0700 "$run_dir"
summary="$run_dir/summary.md"; diagnostics="$run_dir/diagnostics.txt"
: >"$summary"; : >"$diagnostics"; chmod 0600 "$summary" "$diagnostics"
capture() {
  local label="$1" binary="$2" rc; shift 2
  { printf '\n===== %s =====\nCOMMAND:' "$label"; printf ' %q' "$binary" "$@"; printf '\n'; } >>"$diagnostics"
  if ! command -v "$binary" >/dev/null 2>&1; then
    printf 'SKIPPED: command not installed (%s)\n' "$binary" >>"$diagnostics"; return 0
  fi
  if "$binary" "$@" >>"$diagnostics" 2>&1; then
    printf 'COMMAND EXIT: 0\n' >>"$diagnostics"
  else
    rc=$?; printf 'COMMAND EXIT: %s (collection continues)\n' "$rc" >>"$diagnostics"
  fi
}
read_sysfs() {
  local label="$1" path="$2"
  printf '%s: ' "$label" >>"$diagnostics"
  if [[ -r "$path" ]]; then tr '\n' ' ' <"$path" >>"$diagnostics"; printf '\n' >>"$diagnostics"
  else printf 'UNAVAILABLE\n' >>"$diagnostics"; fi
}
{
  printf '# ThinkPad X280 power-management baseline\n\n'
  printf -- '- Captured (UTC): %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Repository commit: %s\n' "$(git rev-parse HEAD 2>/dev/null || printf unknown)"
  printf -- '- Kernel: %s\n' "$(uname -sr)"
  printf -- '- Collection result: **COMPLETED** (not a tuning or battery-life PASS)\n'
  printf -- '- Detailed snapshot: diagnostics.txt\n'
  printf '\nRead-only snapshot only. Review diagnostics before sharing. No tuning or service changes are performed.\n'
} >>"$summary"
{
  printf '===== CPU frequency policy =====\n'; count=0
  for policy in /sys/devices/system/cpu/cpufreq/policy*; do
    [[ -d "$policy" ]] || continue; count=$((count + 1)); printf '\n[%s]\n' "${policy##*/}"
    for field in scaling_driver scaling_governor scaling_available_governors scaling_min_freq scaling_max_freq scaling_cur_freq cpuinfo_min_freq cpuinfo_max_freq energy_performance_preference energy_performance_available_preferences; do
      read_sysfs "$field" "$policy/$field"
    done
  done
  ((count > 0)) || printf 'No cpufreq policy directories found.\n'
} >>"$diagnostics"
{
  printf '\n===== Intel pstate =====\n'
  for field in status mode no_turbo min_perf_pct max_perf_pct; do read_sysfs "$field" "/sys/devices/system/cpu/intel_pstate/$field"; done
  printf '\n===== ACPI platform profile =====\n'
  read_sysfs platform_profile /sys/firmware/acpi/platform_profile
  read_sysfs platform_profile_choices /sys/firmware/acpi/platform_profile_choices
  printf '\n===== CPU idle driver =====\n'
  read_sysfs cpuidle_current_driver /sys/devices/system/cpu/cpuidle/current_driver
  read_sysfs cpuidle_current_governor /sys/devices/system/cpu/cpuidle/current_governor
} >>"$diagnostics"
{
  printf '\n===== AC adapter and battery state =====\n'; found=0
  for device in /sys/class/power_supply/*; do
    [[ -d "$device" ]] || continue; type="$(cat "$device/type" 2>/dev/null || printf unknown)"
    case "$type" in
      Mains|USB|USB_C)
        found=1; printf '[%s] type=%s\n' "${device##*/}" "$type"; read_sysfs online "$device/online" ;;
      Battery)
        found=1; printf '[%s] type=%s\n' "${device##*/}" "$type"
        for field in status capacity energy_now energy_full energy_full_design power_now charge_control_start_threshold charge_control_end_threshold; do read_sysfs "$field" "$device/$field"; done ;;
    esac
  done
  ((found > 0)) || printf 'No AC/battery power-supply entries found.\n'
} >>"$diagnostics"
{
  printf '\n===== Power-management services =====\n'
  for service in power-profiles-daemon.service tlp.service tuned.service thermald.service systemd-logind.service; do
    printf '[%s]\n' "$service"
    if command -v systemctl >/dev/null 2>&1; then
      systemctl show "$service" -p LoadState -p ActiveState -p UnitFileState --no-pager 2>&1 || true
    else printf 'systemctl unavailable\n'; fi
  done
} >>"$diagnostics"
capture 'Power Profiles daemon active profile' powerprofilesctl get
capture 'Power Profiles daemon available profiles' powerprofilesctl list
capture 'TLP status (if installed)' tlp-stat -s
capture 'UPower device inventory' upower -e
chmod 0600 "$summary" "$diagnostics"
printf 'Power-management baseline report created: %s\n' "$run_dir"
printf 'Collection completed; no tuning, service changes, or acceptance result is implied.\n'
printf 'Review diagnostics.txt for host-specific information before committing/pushing.\n'
