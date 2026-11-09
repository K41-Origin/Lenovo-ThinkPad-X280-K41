#!/usr/bin/env bash
# Evidence-based automatic remediation for the K41 ThinkPad X280 desktop.
set -Eeuo pipefail
umask 077
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"

if (($#)); then
  if (($# == 1)) && [[ $1 == -h || $1 == --help ]]; then
    printf 'Usage: bash scripts/k41-desktop-repair.sh\n'
    exit 0
  fi
  printf 'ERROR: no repair-mode options are supported.\n' >&2
  exit 2
fi
(( EUID != 0 )) || { printf 'ERROR: run as regular user, never sudo.\n' >&2; exit 2; }
[[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} && -n ${WAYLAND_DISPLAY:-} ]] ||
  { printf 'ERROR: run inside active Hyprland session.\n' >&2; exit 2; }
for cmd in date mkdir chmod pacman systemctl grep awk tee stat; do
  command -v "$cmd" >/dev/null 2>&1 || { printf 'ERROR: missing command: %s\n' "$cmd" >&2; exit 2; }
done
[[ -f "$ROOT/scripts/k41-desktop-validation.sh" ]] || { printf 'ERROR: validator missing.\n' >&2; exit 2; }

stamp="$(date -u +'%Y%m%dT%H%M%SZ')"
report_root="$ROOT/reports/desktop-repair"
mkdir -p -- "$report_root"
report_dir="$report_root/$stamp"
n=0
while ! mkdir -- "$report_dir" 2>/dev/null; do n=$((n + 1)); report_dir="$report_root/$stamp-$n"; done
chmod 0700 "$report_dir"
log_file="$report_dir/repair.log"
actions_file="$report_dir/actions.tsv"
: >"$log_file"
printf 'STATUS\tACTION\tDETAIL\n' >"$actions_file"
chmod 0600 "$log_file" "$actions_file"

pass_count=0 warn_count=0 fail_count=0 skip_count=0 sudo_ready=0
record() {
  local status=$1 action=$2 detail=$3
  printf '%s\t%s\t%s\n' "$status" "$action" "$detail" >>"$actions_file"
  printf '[%s] %s — %s\n' "$status" "$action" "$detail" | tee -a "$log_file"
  case "$status" in
    PASS) pass_count=$((pass_count + 1)) ;;
    WARN) warn_count=$((warn_count + 1)) ;;
    FAIL) fail_count=$((fail_count + 1)) ;;
    SKIP) skip_count=$((skip_count + 1)) ;;
  esac
}
log() { printf '%s\n' "$*" | tee -a "$log_file"; }
privileged() {
  if (( sudo_ready == 0 )); then
    command -v sudo >/dev/null 2>&1 || { record FAIL 'Privilege escalation' 'sudo unavailable'; return 1; }
    sudo -v || { record FAIL 'Privilege escalation' 'sudo authentication failed'; return 1; }
    sudo_ready=1
  fi
  sudo "$@"
}

log "K41 ThinkPad X280 automatic desktop repair"
log "UTC: $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
log "Repository commit: $(git rev-parse HEAD 2>/dev/null || printf unknown)"
log "Report: $report_dir"
log "Policy: narrowly scoped repairs; no PAM, kernel, or desktop configuration rewrites."
log ""

# Caelestia upstream's post-install action uses this default scheme.
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/caelestia"
scheme_file="$state_dir/scheme.json"
if [[ -s $scheme_file ]]; then
  record PASS 'Caelestia scheme' 'existing scheme preserved'
elif command -v caelestia >/dev/null 2>&1; then
  if caelestia scheme set -n caelestia >>"$log_file" 2>&1 && [[ -s $scheme_file ]]; then
    record PASS 'Caelestia scheme' 'initialized using upstream default scheme'
  else
    record WARN 'Caelestia scheme' 'CLI did not create scheme.json; no synthetic file written'
  fi
else
  record WARN 'Caelestia scheme' 'scheme.json missing and Caelestia CLI unavailable'
fi

# The pushed X280 report identifies Intel Wireless 8265 and an hci0 radio.
missing_packages=()
if [[ -d /sys/class/bluetooth/hci0 ]]; then
  for package in bluez bluez-utils; do
    pacman -Q "$package" >/dev/null 2>&1 || missing_packages+=("$package")
  done
else
  record SKIP 'Bluetooth packages' 'no hci0 controller detected'
fi
if [[ ! -r /usr/lib/firmware/regulatory.db ]] && ! pacman -Q wireless-regdb >/dev/null 2>&1; then
  missing_packages+=(wireless-regdb)
fi
if ((${#missing_packages[@]})); then
  log "ACTION: install missing packages: ${missing_packages[*]}"
  if privileged pacman -S --needed --noconfirm "${missing_packages[@]}"; then
    for package in "${missing_packages[@]}"; do
      if pacman -Q "$package" >/dev/null 2>&1; then
        record PASS "Package $package" 'installed'
      else
        record FAIL "Package $package" 'not present in pacman local database after install'
      fi
    done
  else
    record FAIL 'Package installation' "failed: ${missing_packages[*]}"
  fi
else
  [[ -d /sys/class/bluetooth/hci0 ]] && record PASS 'Bluetooth packages' 'bluez and bluez-utils already installed'
fi

if [[ -r /usr/lib/firmware/regulatory.db ]]; then
  record PASS 'Wireless regulatory database' 'regulatory.db present and readable'
elif pacman -Q wireless-regdb >/dev/null 2>&1; then
  pacman -Qkk wireless-regdb >"$report_dir/wireless-regdb-integrity.txt" 2>&1 || true
  record WARN 'Wireless regulatory database' 'wireless-regdb installed but file absent; integrity report saved, no forced overwrite'
else
  record FAIL 'Wireless regulatory database' 'wireless-regdb package remains unavailable'
fi

# Enable Bluetooth only when both the controller and BlueZ package set exist.
if [[ -d /sys/class/bluetooth/hci0 ]] &&
   pacman -Q bluez >/dev/null 2>&1 && pacman -Q bluez-utils >/dev/null 2>&1; then
  if systemctl cat bluetooth.service >/dev/null 2>&1; then
    if systemctl is-active --quiet bluetooth.service; then
      record PASS 'Bluetooth service' 'already active'
    elif privileged systemctl enable --now bluetooth.service; then
      record PASS 'Bluetooth service' 'enabled and started'
    else
      record FAIL 'Bluetooth service' 'enable/start failed'
    fi
  else
    record FAIL 'Bluetooth service' 'unit unavailable after BlueZ installation'
  fi
else
  record SKIP 'Bluetooth service' 'controller or BlueZ package prerequisites unavailable'
fi

# PAM is security-critical: collect package integrity, never synthesize policy.
if [[ -r /etc/pam.d/other ]]; then
  record PASS 'PAM fallback policy' '/etc/pam.d/other readable'
elif pacman -Q pambase >/dev/null 2>&1; then
  pacman -Qkk pambase >"$report_dir/pambase-integrity.txt" 2>&1 || true
  record WARN 'PAM fallback policy' 'file missing/unreadable; pambase integrity saved; policy not rewritten'
else
  record FAIL 'PAM fallback policy' 'pambase or /etc/pam.d/other missing; automatic PAM changes prohibited'
fi

[[ -e $HOME/.face ]] &&
  record PASS 'Caelestia profile image' 'optional image exists' ||
  record SKIP 'Caelestia profile image' 'optional; no placeholder generated'
record WARN 'Bluetooth HCI negotiation' 'kernel HCI feature errors are not repaired by BlueZ; controller/driver firmware untouched'
record WARN 'CPU security mitigations' 'MDS/MMIO/VMSCAPE are CPU/kernel policy findings; no SMT or kernel parameters changed'
record SKIP 'Wi-Fi multicast RX warning' 'driver/kernel informational warning; Wi-Fi is connected, no network reset'
record SKIP 'Qt Wayland text-input warnings' 'no safe configuration change supported by this evidence'
record SKIP 'PipeWire libcamera plugin' 'optional camera integration; no package added'
record SKIP 'lsusb utility' 'diagnostic-only utility, not a desktop runtime dependency'

{
  printf 'Captured UTC: %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  printf '\nBlueZ packages:\n'; pacman -Q bluez bluez-utils 2>&1 || true
  printf '\nBluetooth service:\n'; systemctl show bluetooth.service -p LoadState -p ActiveState -p SubState -p UnitFileState 2>&1 || true
  printf '\nRegulatory database:\n'; stat /usr/lib/firmware/regulatory.db 2>&1 || true
  printf '\nCaelestia scheme:\n'; [[ -s $scheme_file ]] && stat "$scheme_file" || printf 'missing\n'
  printf '\nPAM fallback:\n'; stat /etc/pam.d/other 2>&1 || true
} >"$report_dir/post-repair-state.txt"
chmod 0600 "$report_dir"/*.txt

log ""
log "=== Post-repair validation ==="
if bash "$ROOT/scripts/k41-desktop-validation.sh" >"$report_dir/validation-output.log" 2>&1; then
  record PASS 'Desktop validation' 'validator returned exit 0'
else
  rc=$?
  record WARN 'Desktop validation' "validator returned exit $rc; inspect newest validation report"
fi

{
  printf '# K41 desktop repair summary\n\n'
  printf -- '- Captured UTC: %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Repository commit: %s\n' "$(git rev-parse HEAD 2>/dev/null || printf unknown)"
  printf -- '- Actions: %s PASS, %s WARN, %s FAIL, %s SKIP\n' "$pass_count" "$warn_count" "$fail_count" "$skip_count"
  printf '\nPAM policy, kernel parameters, CPU SMT policy, desktop configuration, optional profile imagery, and controller firmware were not rewritten. Package installation is limited to missing bluez, bluez-utils, and wireless-regdb. Review/redact reports before sharing.\n'
} >"$report_dir/summary.md"
chmod 0600 "$log_file" "$actions_file" "$report_dir/summary.md"
log "Repair complete: $report_dir"
(( fail_count == 0 ))
