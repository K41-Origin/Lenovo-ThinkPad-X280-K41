#!/usr/bin/env bash
# Automated health validation for the K41 ThinkPad X280 Hyprland desktop.
# Read-only: writes private reports only. It cannot validate physical/UI behavior.
set -Eeuo pipefail
umask 077

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"

die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }
(( EUID != 0 )) || die 'Run as the regular desktop user; never use sudo.'
[[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} && -n ${WAYLAND_DISPLAY:-} ]] ||
  die 'Run from a terminal inside the active Hyprland session.'

for required in bash date mkdir chmod uname pacman systemctl journalctl grep awk sed pgrep cp cat id df git; do
  command -v "$required" >/dev/null 2>&1 || die "Required command missing: $required"
done
[[ -f "$ROOT/scripts/test-desktop-x280.sh" ]] || die 'Desktop diagnostic collector is missing.'
[[ -f "$ROOT/scripts/test-caelestia-x280.sh" ]] || die 'Caelestia diagnostic collector is missing.'

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
log="$run_dir/validation.log"
checks="$run_dir/checks.tsv"
summary="$run_dir/summary.md"
: >"$log"
: >"$checks"
chmod 0600 "$log" "$checks"

pass_count=0
warn_count=0
fail_count=0
skip_count=0
record() {
  local status=$1 name=$2 detail=$3
  printf '%s\t%s\t%s\n' "$status" "$name" "$detail" >>"$checks"
  printf '[%s] %s — %s\n' "$status" "$name" "$detail"
  case "$status" in
    PASS) pass_count=$((pass_count + 1)) ;;
    WARN) warn_count=$((warn_count + 1)) ;;
    FAIL) fail_count=$((fail_count + 1)) ;;
    SKIP) skip_count=$((skip_count + 1)) ;;
  esac
}
capture() {
  local label=$1 output_file=$2 rc
  shift 2
  {
    printf '\n===== %s =====\nCOMMAND:' "$label"
    printf ' %q' "$@"
    printf '\n'
  } >>"$log"
  if "$@" >"$output_file" 2>&1; then
    rc=0
  else
    rc=$?
  fi
  cat -- "$output_file" >>"$log"
  printf 'COMMAND EXIT: %s\n' "$rc" >>"$log"
  return "$rc"
}
command_path() { command -v "$1" 2>/dev/null || true; }

tmp="$run_dir/.tmp"
mkdir -m 0700 -- "$tmp"
trap 'rm -rf -- "$tmp"' EXIT

printf 'K41 X280 automated desktop validation\nReport: %s\n' "$run_dir"
{
  printf 'Captured UTC: %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  printf 'Repository commit: %s\n' "$(git rev-parse HEAD 2>/dev/null || printf unknown)"
  printf 'Kernel: %s\n' "$(uname -sr)"
  printf 'Architecture: %s\n' "$(uname -m)"
  printf 'User: %s\n' "$(id -un)"
  printf 'Session type: %s\n' "${XDG_SESSION_TYPE:-unknown}"
  printf 'Wayland display: present (value omitted)\n'
  printf 'Hyprland instance: present (value omitted)\n'
} >"$run_dir/environment.txt"

# 1. Platform and session contract.
[[ -r /etc/arch-release ]] && record PASS 'Arch Linux' 'Arch release marker present' ||
  record FAIL 'Arch Linux' 'Expected /etc/arch-release'
[[ $(uname -m) == x86_64 ]] && record PASS 'Architecture' 'x86_64' ||
  record FAIL 'Architecture' "Unsupported architecture: $(uname -m)"
[[ ${XDG_SESSION_TYPE:-} == wayland ]] && record PASS 'Wayland session' 'XDG_SESSION_TYPE=wayland' ||
  record WARN 'Wayland session' "XDG_SESSION_TYPE=${XDG_SESSION_TYPE:-unset}"
command -v hyprctl >/dev/null 2>&1 && record PASS 'Hyprland CLI' "$(command_path hyprctl)" ||
  record FAIL 'Hyprland CLI' 'hyprctl not found'
command -v qs >/dev/null 2>&1 && record PASS 'Quickshell CLI' "$(command_path qs)" ||
  record FAIL 'Quickshell CLI' 'qs not found'
command -v caelestia >/dev/null 2>&1 && record PASS 'Caelestia CLI' "$(command_path caelestia)" ||
  record FAIL 'Caelestia CLI' 'caelestia not found'

# 2. Required package inventory. Optional utilities are warnings, not hard failures.
required_packages=(hyprland quickshell-git caelestia-shell caelestia-cli pipewire wireplumber pipewire-pulse xdg-desktop-portal xdg-desktop-portal-hyprland)
for package in "${required_packages[@]}"; do
  if pacman -Q "$package" >"$tmp/package" 2>&1; then
    record PASS "Package: $package" "$(cat "$tmp/package")"
  else
    record FAIL "Package: $package" 'Not installed according to pacman'
  fi
done
for package in mesa vulkan-intel brightnessctl upower networkmanager; do
  if pacman -Q "$package" >"$tmp/package" 2>&1; then
    record PASS "Optional package: $package" "$(cat "$tmp/package")"
  else
    record WARN "Optional package: $package" 'Not installed; feature coverage may be reduced'
  fi
done

# 3. Hyprland live state and configuration.
if capture 'Hyprland configuration errors' "$tmp/hypr-config-errors" hyprctl configerrors; then
  if ! grep -q '[^[:space:]]' "$tmp/hypr-config-errors"; then
    record PASS 'Hyprland configuration' 'hyprctl configerrors returned no diagnostic text'
  else
    record FAIL 'Hyprland configuration' 'hyprctl configerrors returned non-whitespace diagnostics; inspect validation.log'
  fi
else
  record FAIL 'Hyprland configuration query' 'hyprctl configerrors failed'
fi
if capture 'Hyprland monitor state' "$tmp/monitors" hyprctl monitors && [[ -s $tmp/monitors ]]; then
  record PASS 'Monitor enumeration' 'Hyprland returned at least one monitor'
else
  record FAIL 'Monitor enumeration' 'No monitor data returned'
fi
if capture 'Hyprland input device state' "$tmp/devices" hyprctl devices && [[ -s $tmp/devices ]]; then
  record PASS 'Input device enumeration' 'Hyprland returned input-device data'
else
  record WARN 'Input device enumeration' 'No input-device data returned'
fi
if pgrep -x Hyprland >/dev/null 2>&1; then
  record PASS 'Hyprland process' 'Hyprland process exists'
else
  record WARN 'Hyprland process' 'Process name not found; session may use a different launcher/process title'
fi

# 4. Caelestia/Quickshell runtime and IPC.
caelestia_running=0
if pgrep -af '[q]s.*caelestia|[q]uickshell.*caelestia|[c]aelestia shell' >/dev/null 2>&1; then
  caelestia_running=1
  record PASS 'Caelestia process' 'Matching process detected'
else
  record FAIL 'Caelestia process' 'No matching Caelestia/Quickshell process'
fi
if (( caelestia_running == 1 )); then
  if capture 'Caelestia IPC target discovery' "$tmp/caelestia-ipc" caelestia shell -s && [[ -s $tmp/caelestia-ipc ]]; then
    record PASS 'Caelestia IPC' 'IPC target list returned data'
  else
    record FAIL 'Caelestia IPC' 'IPC discovery failed or returned no targets'
  fi
  if capture 'Caelestia runtime log' "$tmp/caelestia-log" qs -c caelestia log; then
    if grep -Eiq '(^|[[:space:]])(fatal|critical):|QML.*(Error|failed)|failed to load.*(QML|plugin|module)|TypeError:|ReferenceError:' "$tmp/caelestia-log"; then
      record WARN 'Caelestia runtime log' 'Actionable runtime/QML error signature found; inspect validation.log'
    elif grep -Eiq 'Source file does not exist|Read of .+ failed: File does not exist|org\.bluez|RTKit' "$tmp/caelestia-log"; then
      record WARN 'Caelestia runtime log' 'Optional resource or external-service warning found; inspect validation.log and repair report'
    else
      record PASS 'Caelestia runtime log' 'No actionable fatal/critical/QML runtime error signature found'
    fi
  else
    record WARN 'Caelestia runtime log' 'Could not retrieve Quickshell log'
  fi
else
  record SKIP 'Caelestia IPC' 'Skipped because no Caelestia process is running'
  record SKIP 'Caelestia runtime log' 'Skipped because no Caelestia process is running'
fi

# 5. User services and portals.
for unit in pipewire.service wireplumber.service; do
  if systemctl --user is-active --quiet "$unit"; then
    record PASS "User service: $unit" 'active'
  elif systemctl --user is-active --quiet "${unit%.service}.socket"; then
    record PASS "User service: $unit" 'socket active; service may be socket-activated'
  else
    record WARN "User service: $unit" 'not active; inspect service logs and audio behavior'
  fi
done
for unit in xdg-desktop-portal.service xdg-desktop-portal-hyprland.service; do
  if systemctl --user is-active --quiet "$unit"; then
    record PASS "Portal service: $unit" 'active'
  else
    record WARN "Portal service: $unit" 'not active at check time; portals may be D-Bus activated on demand'
  fi
done
if systemctl is-active --quiet NetworkManager.service; then
  record PASS 'NetworkManager service' 'active'
else
  record WARN 'NetworkManager service' 'not active'
fi
if capture 'Failed system units' "$tmp/failed-system-units" systemctl --failed --no-legend --plain; then
  failed_units="$(awk 'NF && $0 !~ /^0 loaded units listed/ {print}' "$tmp/failed-system-units")"
  if [[ -z $failed_units ]]; then
    record PASS 'System failed units' 'No failed system units reported'
  else
    record WARN 'System failed units' 'One or more failed units; inspect validation.log'
  fi
else
  record WARN 'System failed units' 'Could not query system unit state'
fi
if capture 'Failed user units' "$tmp/failed-user-units" systemctl --user --failed --no-legend --plain; then
  failed_user_units="$(awk 'NF && $0 !~ /^0 loaded units listed/ {print}' "$tmp/failed-user-units")"
  if [[ -z $failed_user_units ]]; then
    record PASS 'User failed units' 'No failed user units reported'
  else
    record WARN 'User failed units' 'One or more failed user units; inspect validation.log'
  fi
else
  record WARN 'User failed units' 'Could not query user unit state'
fi

# 6. Audio graph, network adapter, radio state.
if command -v wpctl >/dev/null 2>&1 && capture 'PipeWire graph' "$tmp/wpctl" wpctl status && grep -q 'Sinks:' "$tmp/wpctl" && grep -q 'Sources:' "$tmp/wpctl"; then
  record PASS 'PipeWire graph' 'wpctl returned audio graph sections'
else
  record WARN 'PipeWire graph' 'wpctl unavailable or no graph data'
fi
if command -v pactl >/dev/null 2>&1 && capture 'PulseAudio compatibility server' "$tmp/pactl" bash -o pipefail -c 'pactl info | sed -E "/^Cookie:/d"'; then
  record PASS 'PulseAudio compatibility' 'pactl info succeeded'
else
  record WARN 'PulseAudio compatibility' 'pactl unavailable or server query failed'
fi
if command -v nmcli >/dev/null 2>&1 && capture 'Network device state' "$tmp/network" nmcli -t -f DEVICE,TYPE,STATE device status; then
  if grep -qE 'wifi:connected|ethernet:connected' "$tmp/network"; then
    record PASS 'Network connectivity state' 'At least one Wi-Fi/Ethernet device reports connected'
  else
    record WARN 'Network connectivity state' 'No connected Wi-Fi/Ethernet device; may be intentional'
  fi
else
  record WARN 'Network device state' 'nmcli unavailable or query failed'
fi
if command -v rfkill >/dev/null 2>&1 && capture 'Radio block state' "$tmp/rfkill" rfkill list; then
  if grep -q 'Soft blocked: yes' "$tmp/rfkill" || grep -q 'Hard blocked: yes' "$tmp/rfkill"; then
    record WARN 'Radio block state' 'At least one radio is blocked; review whether intentional'
  else
    record PASS 'Radio block state' 'No soft/hard radio blocks reported'
  fi
else
  record WARN 'Radio block state' 'rfkill unavailable or query failed'
fi
if command -v lspci >/dev/null 2>&1 && lspci -nnk >"$tmp/pci" 2>&1; then
  if grep -q 'Kernel driver in use: i915' "$tmp/pci"; then
    record PASS 'Intel graphics driver' 'i915 is bound to a PCI graphics device'
  else
    record WARN 'Intel graphics driver' 'i915 binding not found; inspect PCI inventory'
  fi
else
  record WARN 'PCI hardware inventory' 'lspci unavailable or query failed'
fi
backlight_found=0
for backlight in /sys/class/backlight/*; do
  [[ -d $backlight ]] || continue
  backlight_found=1
  if [[ -r $backlight/brightness && -r $backlight/max_brightness ]]; then
    current="$(<"$backlight/brightness")"
    maximum="$(<"$backlight/max_brightness")"
    if [[ $current =~ ^[0-9]+$ && $maximum =~ ^[0-9]+$ ]] && (( maximum > 0 && current <= maximum )); then
      record PASS 'Backlight telemetry' "${backlight##*/}: ${current}/${maximum}"
    else
      record WARN 'Backlight telemetry' "${backlight##*/}: invalid or unreadable brightness values"
    fi
  else
    record WARN 'Backlight telemetry' "${backlight##*/}: brightness attributes unavailable"
  fi
done
(( backlight_found == 1 )) || record WARN 'Backlight telemetry' 'No backlight device found'

# 7. Resource and storage capacity snapshots.
if command -v free >/dev/null 2>&1 && free -b >"$tmp/memory" 2>&1; then
  available="$(awk '/^Mem:/ {print $7}' "$tmp/memory")"
  total="$(awk '/^Mem:/ {print $2}' "$tmp/memory")"
  if [[ $available =~ ^[0-9]+$ && $total =~ ^[0-9]+$ ]] && (( total > 0 )); then
    available_pct=$((available * 100 / total))
    if (( available_pct >= 10 )); then
      record PASS 'Memory availability' "$((available / 1024 / 1024)) MiB available (${available_pct}%)"
    else
      record WARN 'Memory availability' "$((available / 1024 / 1024)) MiB available (${available_pct}%)"
    fi
  else
    record WARN 'Memory availability' 'Could not parse free output'
  fi
else
  record WARN 'Memory availability' 'free command unavailable or query failed'
fi
if df -P "$ROOT" >"$tmp/df" 2>&1; then
  usage="$(awk 'NR==2 {gsub(/%/, "", $5); print $5}' "$tmp/df")"
  if [[ $usage =~ ^[0-9]+$ ]] && (( usage < 90 )); then
    record PASS 'Repository filesystem capacity' "${usage}% used"
  elif [[ $usage =~ ^[0-9]+$ ]] && (( usage < 97 )); then
    record WARN 'Repository filesystem capacity' "${usage}% used"
  else
    record FAIL 'Repository filesystem capacity' "At least 97% used or usage could not be parsed: ${usage:-unknown}"
  fi
else
  record WARN 'Repository filesystem capacity' 'df query failed'
fi
battery_found=0
for battery in /sys/class/power_supply/BAT*; do
  [[ -d $battery ]] || continue
  battery_found=1
  if [[ -r $battery/capacity ]]; then
    capacity="$(<"$battery/capacity")"
    if [[ $capacity =~ ^[0-9]+$ ]] && (( capacity >= 10 )); then
      record PASS 'Battery charge snapshot' "${battery##*/}: ${capacity}%"
    elif [[ $capacity =~ ^[0-9]+$ ]]; then
      record WARN 'Battery charge snapshot' "${battery##*/}: ${capacity}% (low charge)"
    else
      record WARN 'Battery charge snapshot' "${battery##*/}: capacity unreadable"
    fi
  else
    record WARN 'Battery charge snapshot' "${battery##*/}: capacity field unavailable"
  fi
  if [[ -r $battery/energy_full && -r $battery/energy_full_design ]]; then
    full="$(<"$battery/energy_full")"
    design="$(<"$battery/energy_full_design")"
    if [[ $full =~ ^[0-9]+$ && $design =~ ^[0-9]+$ ]] && (( design > 0 )); then
      health=$((full * 100 / design))
      if (( health >= 70 )); then
        record PASS 'Battery capacity health estimate' "${battery##*/}: ${health}% of design capacity"
      else
        record WARN 'Battery capacity health estimate' "${battery##*/}: ${health}% of design capacity"
      fi
    fi
  fi
done
(( battery_found == 1 )) || record WARN 'Battery telemetry' 'No BAT* sysfs device found'
thermal_found=0
for zone in /sys/class/thermal/thermal_zone*; do
  [[ -r $zone/temp ]] || continue
  raw="$(<"$zone/temp")"
  [[ $raw =~ ^-?[0-9]+$ ]] || continue
  thermal_found=1
  celsius=$((raw / 1000))
  zone_type=unknown
  [[ -r $zone/type ]] && zone_type="$(<"$zone/type")"
  if (( celsius < 85 )); then
    record PASS "Thermal: $zone_type" "${celsius}°C"
  elif (( celsius < 100 )); then
    record WARN "Thermal: $zone_type" "${celsius}°C (elevated; inspect under load)"
  else
    record FAIL "Thermal: $zone_type" "${celsius}°C (critical threshold)"
  fi
done
(( thermal_found == 1 )) || record WARN 'Thermal telemetry' 'No readable thermal zones found'

# 8. Supplemental inventories and journal evidence.
printf '\n===== Supplemental desktop collector =====\n' >>"$log"
if K41_REPORT_DIR="$run_dir/desktop" bash "$ROOT/scripts/test-desktop-x280.sh" >>"$log" 2>&1; then
  record PASS 'Supplemental desktop inventory' 'Collector completed; command-level errors remain in the report'
else
  record WARN 'Supplemental desktop inventory' 'Collector returned non-zero; inspect its report/log'
fi
printf '\n===== Supplemental Caelestia collector =====\n' >>"$log"
if (( caelestia_running == 1 )); then
  if K41_REPORT_DIR="$run_dir/caelestia" bash "$ROOT/scripts/test-caelestia-x280.sh" >>"$log" 2>&1; then
    record PASS 'Supplemental Caelestia inventory' 'Collector completed; running shell was left untouched'
  else
    record WARN 'Supplemental Caelestia inventory' 'Collector returned non-zero'
  fi
else
  record SKIP 'Supplemental Caelestia inventory' 'Skipped to avoid starting Caelestia during a read-only validation run'
fi

capture 'User journal errors (last 100)' "$tmp/user-journal" journalctl --user -b -p err --no-pager -n 100 || true
capture 'System journal errors (last 100; permission may be limited)' "$tmp/system-journal" journalctl -b -p err --no-pager -n 100 || true
capture 'Recent kernel warnings/errors (last 100)' "$tmp/kernel-journal" journalctl -k -b -p warning --no-pager -n 100 || true
cp -- "$tmp/user-journal" "$run_dir/user-journal-errors.txt" 2>/dev/null || :
cp -- "$tmp/system-journal" "$run_dir/system-journal-errors.txt" 2>/dev/null || :
cp -- "$tmp/kernel-journal" "$run_dir/kernel-journal-warnings.txt" 2>/dev/null || :
for journal_file in "$tmp/user-journal" "$tmp/system-journal" "$tmp/kernel-journal"; do
  journal_name=${journal_file##*/}
  if [[ ! -s $journal_file ]]; then
    record WARN "Journal: $journal_name" 'No entries returned or journal access unavailable'
  elif grep -Eiq 'not seeing messages|permission denied|failed to open.*journal|No journal files were found' "$journal_file"; then
    record WARN "Journal: $journal_name" 'Journal access appears limited; this source is not fully validated'
  elif grep -Eiq 'kernel BUG|Oops:|Kernel panic|general protection fault|Out of memory|oom-kill' "$journal_file"; then
    record FAIL "Journal: $journal_name" 'Critical kernel/memory failure signature found; inspect saved journal'
  elif grep -Eiq 'segfault|coredump|Out of memory|oom-kill|PAM _pam_init_handlers: no default config other|Bluetooth: hci[0-9]+: Reading supported features failed|Direct firmware load for regulatory\.db failed|MDS CPU bug present|MMIO Stale Data CPU bug present|VMSCAPE:' "$journal_file"; then
    record WARN "Journal: $journal_name" 'Actionable application, firmware, Bluetooth, PAM, or CPU-security warning found; inspect saved journal and repair report'
  elif grep -Eiq 'nl80211: kernel reports: multicast RX registrations are not supported|virt/tdx: TDX not supported|hpet_acpi_probe: no address or irqs in _CRS|ENERGY_PERF_BIAS:' "$journal_file"; then
    record PASS "Journal: $journal_name" 'Only recognized informational platform/driver messages detected'
  elif grep -Eiq 'Failed|failed|failure|QML.*Error|error:' "$journal_file"; then
    record WARN "Journal: $journal_name" 'Unclassified error-level journal entry found; inspect saved journal'
  else
    record PASS "Journal: $journal_name" 'No configured critical/actionable error signatures detected'
  fi
done
chmod 0600 "$run_dir"/*.txt "$log" "$checks" "$diagnostics" "$diagnostics_log"

# 9. Focused diagnostic evidence for future, evidence-based remediation.
# This section is read-only. Outputs are private because hardware/service details
# and journal messages may expose host-specific information.
diagnostics="$run_dir/diagnostics.tsv"
diagnostics_log="$run_dir/diagnostics.log"
printf 'STATUS\tDIAGNOSTIC\tEXIT_CODE\tOUTPUT_FILE\n' >"$diagnostics"
: >"$diagnostics_log"
chmod 0600 "$diagnostics" "$diagnostics_log"

diagnostic() {
  local label=$1 output_file=$2 rc=0
  shift 2
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'SKIP\t%s\tNA\t%s\n' "$label" "$output_file" >>"$diagnostics"
    printf '\n===== %s =====\nSKIPPED: command not installed (%s)\n' "$label" "$1" >>"$diagnostics_log"
    return 0
  fi
  printf '\n===== %s =====\nCOMMAND:' "$label" >>"$diagnostics_log"
  printf ' %q' "$@" >>"$diagnostics_log"
  printf '\n' >>"$diagnostics_log"
  if "$@" >"$run_dir/$output_file" 2>&1; then
    rc=0
  else
    rc=$?
  fi
  cat -- "$run_dir/$output_file" >>"$diagnostics_log"
  printf 'COMMAND EXIT: %s\n' "$rc" >>"$diagnostics_log"
  printf 'CAPTURED\t%s\t%s\t%s\n' "$label" "$rc" "$output_file" >>"$diagnostics"
}

diagnostic 'Kernel command line' 'kernel-cmdline.txt' cat /proc/cmdline
diagnostic 'CPU model and topology' 'cpu-info.txt' lscpu
diagnostic 'CPU vulnerability mitigations' 'cpu-vulnerabilities.txt' bash -c 'for f in /sys/devices/system/cpu/vulnerabilities/*; do [[ -r $f ]] || continue; printf "%s: " "${f##*/}"; cat "$f"; done'
diagnostic 'PCI devices and bound drivers' 'pci-detail.txt' lspci -nnk
diagnostic 'USB device inventory' 'usb-detail.txt' lsusb
diagnostic 'Loaded kernel modules relevant to desktop' 'modules.txt' bash -c 'grep -E "^(i915|xe|iwlwifi|btusb|bluetooth|thinkpad_acpi|snd_hda_intel|snd_sof|nvme) " /proc/modules || true'
diagnostic 'Firmware package metadata' 'firmware-package.txt' pacman -Qi linux-firmware
diagnostic 'Regulatory database package ownership' 'regulatory-owner.txt' pacman -Qo /usr/lib/firmware/regulatory.db
diagnostic 'Bluetooth package metadata' 'bluetooth-packages.txt' pacman -Qi bluez bluez-utils
diagnostic 'Bluetooth service properties' 'bluetooth-unit.txt' systemctl show bluetooth.service -p LoadState -p ActiveState -p SubState -p UnitFileState -p FragmentPath
diagnostic 'NetworkManager service properties' 'networkmanager-unit.txt' systemctl show NetworkManager.service -p LoadState -p ActiveState -p SubState -p UnitFileState
diagnostic 'Power profile service properties' 'power-profiles-unit.txt' systemctl show power-profiles-daemon.service -p LoadState -p ActiveState -p SubState -p UnitFileState
diagnostic 'Thermal hardware monitor inventory' 'hwmon.txt' bash -c 'for d in /sys/class/hwmon/hwmon*; do [[ -d $d ]] || continue; printf "DEVICE %s\n" "$d"; [[ -r $d/name ]] && cat "$d/name"; for f in "$d"/temp*_input "$d"/fan*_input "$d"/power*_input; do [[ -r $f ]] || continue; printf "%s=" "${f##*/}"; cat "$f"; done; done'
diagnostic 'ThinkPad ACPI interface' 'thinkpad-acpi.txt' bash -c 'for f in /sys/devices/platform/thinkpad_acpi/{fan_control,hotkey_mask,hotkey_all_mask}; do [[ -r $f ]] || continue; printf "%s=" "$f"; cat "$f"; done'
diagnostic 'PAM other policy metadata' 'pam-other.txt' stat /etc/pam.d/other
diagnostic 'Relevant installed package versions' 'desktop-package-versions.txt' pacman -Q hyprland quickshell-git caelestia-shell caelestia-cli pipewire wireplumber bluez bluez-utils linux-firmware
diagnostic 'Systemd failed unit details' 'failed-units-detail.txt' systemctl --failed --no-pager --full
diagnostic 'User systemd failed unit details' 'failed-user-units-detail.txt' systemctl --user --failed --no-pager --full

# Do not capture nmcli connection profiles, Wi-Fi SSIDs, MAC addresses from
# network configuration, environment variables, or full process command lines.
chmod 0600 "$diagnostics" "$diagnostics_log"

result=PASS
if (( fail_count > 0 )); then
  result=FAIL
elif (( warn_count > 0 )); then
  result=PASS_WITH_WARNINGS
fi
{
  printf '# K41 ThinkPad X280 automated desktop validation\n\n'
  printf -- '- Captured (UTC): %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Repository commit: %s\n' "$(git rev-parse HEAD 2>/dev/null || printf unknown)"
  printf -- '- Result: **%s**\n' "$result"
  printf -- '- Checks: %s PASS, %s WARN, %s FAIL, %s SKIP\n' "$pass_count" "$warn_count" "$fail_count" "$skip_count"
  printf '\n## Interpretation\n\n'
  printf 'This is automated software/runtime/log validation only. It cannot prove that the panel, launcher, widgets, keyboard, TrackPoint, touchpad, speakers, microphone, brightness keys, Wi-Fi reconnect, screenshot flow, or lock screen behave correctly in real interaction. No physical or visual test is claimed. A PASS means only that no configured automated failure condition was detected in this snapshot.\n'
  printf '\n## Report files\n\n'
  printf -- '- checks.tsv: machine-readable PASS/WARN/FAIL/SKIP results\n'
  printf -- '- validation.log: command output and detailed diagnostic collection\n'
  printf -- '- environment.txt: host/session metadata\n'
  printf -- '- desktop/ and caelestia/: supplemental diagnostic collectors\n'
  printf -- '- *-journal*.txt: recent journal evidence; may be permission-limited\n'
  printf '\nReview/redact all reports before pushing. Reports may contain usernames, hostnames, device identifiers, network state, paths, and log messages.\n'
} >"$summary"
chmod 0600 "$summary"
printf '\n--- Summary ---\n'
cat "$summary"
printf '\nReport: %s\n' "$run_dir"
(( fail_count == 0 ))
