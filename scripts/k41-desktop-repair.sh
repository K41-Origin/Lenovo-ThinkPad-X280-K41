#!/usr/bin/env bash
# Conservative remediation for findings from k41-desktop-validation.sh.
# Audits automatically; only starts/enables an already-installed BlueZ service
# after explicit approval. It never installs packages or edits PAM/desktop files.
set -Eeuo pipefail
umask 077

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"

usage() {
  cat <<'USAGE'
Usage: bash scripts/k41-desktop-repair.sh [--apply] [--no-validate]

Default mode performs an automated audit and prints proposed actions only.
--apply          Permit the one supported repair (enable/start an installed
                 bluetooth.service) after an interactive confirmation.
--no-validate    Do not run k41-desktop-validation.sh after the audit/repair.
Run as the regular desktop user inside the active Hyprland session. Never sudo
the script itself. Package installation and PAM/desktop configuration edits
are deliberately not automated.
USAGE
}
apply=0
run_validation=1
while (($#)); do
  case "$1" in
    --apply) apply=1 ;;
    --no-validate) run_validation=0 ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'ERROR: unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

(( EUID != 0 )) || { printf 'ERROR: run as regular user, never sudo.\n' >&2; exit 2; }
[[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} && -n ${WAYLAND_DISPLAY:-} ]] ||
  { printf 'ERROR: run inside active Hyprland session.\n' >&2; exit 2; }
for cmd in date mkdir chmod pacman systemctl journalctl grep awk tee; do
  command -v "$cmd" >/dev/null 2>&1 || { printf 'ERROR: missing command: %s\n' "$cmd" >&2; exit 2; }
done
[[ -x "$ROOT/scripts/k41-desktop-validation.sh" || -f "$ROOT/scripts/k41-desktop-validation.sh" ]] ||
  { printf 'ERROR: desktop validator missing.\n' >&2; exit 2; }

stamp="$(date -u +'%Y%m%dT%H%M%SZ')"
report_root="$ROOT/reports/desktop-repair"
mkdir -p -- "$report_root"
report_dir="$report_root/$stamp"
n=0
while ! mkdir -- "$report_dir" 2>/dev/null; do
  n=$((n + 1)); report_dir="$report_root/$stamp-$n"
done
chmod 0700 "$report_dir"
report="$report_dir/repair.log"
: >"$report"
chmod 0600 "$report"

log() { printf '%s\n' "$*" | tee -a "$report"; }
log "K41 desktop remediation audit"
log "UTC: $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
log "Mode: $([[ $apply == 1 ]] && printf apply || printf audit-only)"
log "Report: $report_dir"
log ""
log "=== Caelestia optional resources ==="
if [[ -e ${HOME}/.face ]]; then
  log "PASS: profile image exists."
else
  log "INFO: ~/.face is absent. This is an optional profile image; no placeholder will be created."
fi
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/caelestia"
if [[ -d $state_dir ]]; then
  log "PASS: Caelestia state directory exists: $state_dir"
else
  log "INFO: Caelestia state directory is absent. No theme state file will be fabricated."
fi

log ""
log "=== BlueZ / Bluetooth ==="
bluez_installed=0
if pacman -Q bluez >/dev/null 2>&1 && pacman -Q bluez-utils >/dev/null 2>&1; then
  bluez_installed=1
  log "PASS: bluez and bluez-utils are installed."
else
  log "WARN: bluez and/or bluez-utils are not installed. Automatic package installation is intentionally disabled."
fi
unit_available=0
if systemctl cat bluetooth.service >/dev/null 2>&1; then
  unit_available=1
  log "PASS: bluetooth.service unit is available."
else
  log "WARN: bluetooth.service unit is unavailable."
fi
if (( bluez_installed == 1 && unit_available == 1 )); then
  if systemctl is-active --quiet bluetooth.service; then
    log "PASS: bluetooth.service is active; no action required."
  elif (( apply == 1 )); then
    log "PROPOSED: enable and start bluetooth.service."
    if [[ -t 0 ]] && read -r -p "Apply this service change now? [y/N] " answer &&
       [[ $answer == [yY] || $answer == [yY][eE][sS] ]]; then
      if command -v sudo >/dev/null 2>&1 && sudo -v &&
         sudo systemctl enable --now bluetooth.service; then
        log "PASS: bluetooth.service enabled and started."
      else
        log "FAIL: could not enable/start bluetooth.service."
      fi
    else
      log "SKIP: operator declined or no interactive terminal was available."
    fi
  else
    log "PROPOSED: bluetooth.service is installed but inactive; rerun with --apply to approve enable/start."
  fi
else
  log "SKIP: BlueZ service remediation is not applicable until both packages and unit are present."
fi

log ""
log "=== Regulatory database / firmware ==="
if [[ -r /usr/lib/firmware/regulatory.db ]]; then
  log "PASS: regulatory.db is present and readable."
else
  log "WARN: regulatory.db is missing or unreadable. Package ownership and repair are left to package-integrity validation; no package will be reinstalled blindly."
  if pacman -Qo /usr/lib/firmware/regulatory.db >/dev/null 2>&1; then
    log "INFO: pacman reports an owning package; inspect its integrity with pacman -Qkk <package>."
  else
    log "INFO: pacman reports no installed package owning this path."
  fi
fi

log ""
log "=== PAM configuration ==="
if [[ -r /etc/pam.d/other ]]; then
  log "PASS: /etc/pam.d/other exists and is readable."
else
  log "WARN: /etc/pam.d/other is missing or unreadable. PAM policy is security-sensitive; this script will not generate or replace it."
fi
log ""
log "=== Repair boundaries ==="
log "INFO: scheme.json and ~/.face are not fabricated; these may be optional Caelestia resources."
log "INFO: HCI feature errors are kernel/adapter-level evidence and cannot be safely fixed by restarting BlueZ alone."
log "INFO: PAM files, firmware packages, kernel parameters, and desktop configuration are never modified by this script."
log "INFO: No package installation, package upgrade, reboot, or destructive operation is performed."

if (( run_validation == 1 )); then
  log ""
  log "=== Post-repair automated validation ==="
  if bash "$ROOT/scripts/k41-desktop-validation.sh" >>"$report" 2>&1; then
    log "PASS: desktop validator completed with exit 0."
  else
    rc=$?
    log "WARN: desktop validator returned exit $rc; inspect its newest reports/desktop-validation directory."
  fi
fi

chmod 0600 "$report"
log "Repair audit complete. Report: $report_dir"
