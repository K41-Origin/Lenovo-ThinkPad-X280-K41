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
if pacman -Q pipewire >/dev/null 2>&1 && ! pacman -Q rtkit >/dev/null 2>&1; then
  missing_packages+=(rtkit)
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
elif [[ -d /sys/class/bluetooth/hci0 ]]; then
  record PASS 'Bluetooth packages' 'bluez and bluez-utils already installed'
fi

if pacman -Q rtkit >/dev/null 2>&1; then
  record PASS 'RealtimeKit' 'rtkit package installed; D-Bus activation remains on demand'
else
  record WARN 'RealtimeKit' 'rtkit unavailable; PipeWire may use its lower-priority fallback'
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

# PAM is security-critical: always capture package integrity and ownership; never rewrite policy.
pam_integrity="$report_dir/pambase-integrity.txt"
pam_owner="$report_dir/pam-other-owner.txt"
if pacman -Q pambase >"$report_dir/pambase-version.txt" 2>&1; then
  if pacman -Qkk pambase >"$pam_integrity" 2>&1; then
    integrity_ok=1
  else
    integrity_ok=0
  fi
  pacman -Qo /etc/pam.d/other >"$pam_owner" 2>&1 || true
  if [[ -r /etc/pam.d/other ]]; then
    if (( integrity_ok == 1 )) && grep -Fq 'pambase' "$pam_owner"; then
      record PASS 'PAM fallback policy' 'file readable, owned by pambase, and package integrity check passed'
    else
      record WARN 'PAM fallback policy' 'file readable but package ownership/integrity needs review; evidence saved; policy not rewritten'
    fi
  else
    record WARN 'PAM fallback policy' 'fallback file missing/unreadable; package integrity and ownership evidence saved; policy not rewritten'
  fi
else
  printf 'pambase package is not installed\n' >"$pam_integrity"
  record FAIL 'PAM fallback policy' 'pambase package missing; automatic PAM changes prohibited'
fi

if [[ -e $HOME/.face ]]; then
  record PASS 'Caelestia profile image' 'optional image exists'
else
  record SKIP 'Caelestia profile image' 'optional; no placeholder generated'
fi

{
  printf 'Captured UTC: %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  printf '\nBlueZ packages:\n'; pacman -Q bluez bluez-utils 2>&1 || true
  printf '\nRealtimeKit package:\n'; pacman -Q rtkit 2>&1 || true
  printf '\nBluetooth service:\n'; systemctl show bluetooth.service -p LoadState -p ActiveState -p SubState -p UnitFileState 2>&1 || true
  printf '\nRegulatory database:\n'; stat /usr/lib/firmware/regulatory.db 2>&1 || true
  printf '\nCaelestia scheme:\n'; [[ -s $scheme_file ]] && stat "$scheme_file" || printf 'missing\n'
  printf '\nPAM fallback:\n'; stat /etc/pam.d/other 2>&1 || true
} >"$report_dir/post-repair-state.txt"
chmod 0600 "$report_dir"/*.txt

log ""
log "=== Post-repair validation ==="
validation_rc=0
if bash "$ROOT/scripts/k41-desktop-validation.sh" >"$report_dir/validation-output.log" 2>&1; then
  validation_rc=0
else
  validation_rc=$?
fi

# Grade the actual post-repair report, not only the exit code: WARN is a
# successful execution but is not a clean PASS.
validation_reports=("$ROOT"/reports/desktop-validation/*/summary.md)
latest_validation_summary=''
latest_validation_dir=''
if (("${#validation_reports[@]}" > 0)) && [[ -f ${validation_reports[-1]} ]]; then
  latest_validation_summary=${validation_reports[-1]}
  latest_validation_dir=${latest_validation_summary%/summary.md}
  validation_result="$(sed -n 's/^- Result: \*\*\(.*\)\*\*$/\1/p' "$latest_validation_summary" | head -n 1)"
  validation_counts="$(sed -n 's/^- Checks: //p' "$latest_validation_summary" | head -n 1)"
  printf 'Report: %s\nExit code: %s\nResult: %s\nChecks: %s\n' \
    "$latest_validation_dir" "$validation_rc" "${validation_result:-unknown}" "${validation_counts:-unknown}" \
    >"$report_dir/validation-result.txt"
  case "$validation_result:$validation_rc" in
    PASS:0)
      record PASS 'Desktop validation' "clean PASS; $validation_counts"
      ;;
    PASS_WITH_WARNINGS:0)
      record WARN 'Desktop validation' "validator completed with review findings; $validation_counts"
      ;;
    *)
      record FAIL 'Desktop validation' "validator failed or report result is invalid (exit $validation_rc, result ${validation_result:-missing})"
      ;;
  esac
else
  printf 'No complete post-repair validation summary found. Exit code: %s\n' "$validation_rc" \
    >"$report_dir/validation-result.txt"
  record FAIL 'Desktop validation' 'validator produced no complete summary report'
fi

# Classify diagnostics from this exact post-repair snapshot. Missing evidence
# is SKIP, never silently interpreted as a clean PASS.
if [[ -n $latest_validation_dir && -r $latest_validation_dir/kernel-journal-warnings.txt ]]; then
  latest_kernel_report="$latest_validation_dir/kernel-journal-warnings.txt"
  if grep -Eiq 'Bluetooth: hci[0-9]+: Reading supported features failed|HCI LE Coded PHY feature bit is set' "$latest_kernel_report"; then
    record WARN 'Bluetooth HCI negotiation' 'post-repair kernel snapshot contains controller feature errors; firmware/driver investigation required'
  else
    record PASS 'Bluetooth HCI negotiation' 'no configured HCI feature-negotiation signature in post-repair kernel snapshot'
  fi
  if grep -Eiq 'MDS CPU bug present|MMIO Stale Data CPU bug present|VMSCAPE:' "$latest_kernel_report"; then
    record WARN 'CPU security mitigations' 'post-repair kernel snapshot contains mitigation findings; no SMT or kernel parameters changed'
  else
    record PASS 'CPU security mitigations' 'no configured CPU mitigation signature in post-repair kernel snapshot'
  fi
else
  record SKIP 'Kernel warning classification' 'post-repair kernel journal snapshot unavailable'
fi

if [[ -n $latest_validation_dir && -r $latest_validation_dir/system-journal-errors.txt ]]; then
  latest_system_report="$latest_validation_dir/system-journal-errors.txt"
  if grep -Eiq 'nl80211: kernel reports: multicast RX registrations are not supported' "$latest_system_report"; then
    record SKIP 'Wi-Fi multicast RX warning' 'recognized driver/kernel informational message; no network reset performed'
  else
    record PASS 'Wi-Fi multicast RX warning' 'no matching informational warning in post-repair system snapshot'
  fi
else
  record SKIP 'Wi-Fi multicast RX warning' 'post-repair system journal snapshot unavailable'
fi

if [[ -n $latest_validation_dir && -r $latest_validation_dir/user-journal-errors.txt ]]; then
  latest_user_report="$latest_validation_dir/user-journal-errors.txt"
  if grep -Fq 'PAM _pam_init_handlers: no default config other' "$latest_user_report"; then
    pam_warning_count="$(grep -Fc 'PAM _pam_init_handlers: no default config other' "$latest_user_report")"
    record WARN 'PAM runtime warning' "$pam_warning_count matching entry/entries in post-repair user journal; compare pambase-integrity.txt and pam-other-owner.txt; policy unchanged"
  else
    record PASS 'PAM runtime warning' 'no matching PAM fallback warning in post-repair user journal snapshot'
  fi
else
  record SKIP 'PAM runtime warning' 'post-repair user journal snapshot unavailable; runtime behavior not assessed'
fi

record SKIP 'Qt Wayland text-input warnings' 'no safe configuration change supported by current evidence'
record SKIP 'PipeWire libcamera plugin' 'optional camera integration; no package added'
record SKIP 'lsusb utility' 'diagnostic-only utility, not a desktop runtime dependency'

{
  printf '# K41 desktop repair summary\n\n'
  printf -- '- Captured UTC: %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Repository commit: %s\n' "$(git rev-parse HEAD 2>/dev/null || printf unknown)"
  printf -- '- Actions: %s PASS, %s WARN, %s FAIL, %s SKIP\n' "$pass_count" "$warn_count" "$fail_count" "$skip_count"
  printf '\nPAM policy, kernel parameters, CPU SMT policy, desktop configuration, optional profile imagery, and controller firmware were not rewritten. Package installation is limited to missing bluez, bluez-utils, wireless-regdb, and rtkit. Review/redact reports before sharing.\n'
} >"$report_dir/summary.md"
chmod 0600 "$log_file" "$actions_file" "$report_dir/summary.md" "$report_dir/validation-result.txt"
log "Repair complete: $report_dir"
(( fail_count == 0 ))
