#!/usr/bin/env bash
# Read-only diagnostics for the current live environment.
# Source lib/common.sh before calling these functions.
# No checks run automatically when this file is sourced.
# shellcheck source=inventory.sh
_PREFLIGHT_MODULE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "$_PREFLIGHT_MODULE_DIR/inventory.sh"
unset _PREFLIGHT_MODULE_DIR

preflight::check_root() {
  local uid
  if ! uid="$(id -u 2>/dev/null)"; then
    k41::log_warn 'Unable to determine effective user ID; root status is unknown.'
    return 2
  fi

  if [[ "$uid" == 0 ]]; then
    k41::log_info 'Running with effective UID 0 (root).'
  else
    k41::log_warn "Running with effective UID $uid; the live installation workflow normally requires root."
  fi
}

preflight::detect_boot_mode_at() {
  local firmware_root
  if [[ $# -ne 1 || -z "$1" ]]; then
    k41::log_error 'preflight::detect_boot_mode_at requires a firmware-root path.'
    return 2
  fi
  firmware_root=$1

  if [[ -d "$firmware_root/efi" ]]; then
    k41::log_info 'Boot mode: UEFI (firmware interface directory detected).'
    return 0
  fi

  if [[ -d "$firmware_root" ]]; then
    k41::log_warn 'Boot mode: legacy/BIOS candidate only; absence of the UEFI directory is not conclusive.'
    return 2
  fi

  k41::log_warn 'Boot mode: unknown (system firmware indicators unavailable).'
  return 2
}

preflight::detect_boot_mode() {
  preflight::detect_boot_mode_at /sys/firmware
}

preflight::check_commands() {
  local name missing=0
  if [[ $# -eq 0 ]]; then
    k41::log_error 'preflight::check_commands requires at least one command name.'
    return 2
  fi

  for name in "$@"; do
    if [[ ! "$name" =~ ^[a-zA-Z0-9._+-]+$ ]]; then
      k41::log_error "Invalid command name in required-command check: $name"
      return 2
    fi
    if ! command -v -- "$name" >/dev/null 2>&1; then
      k41::log_error "Required command is unavailable: $name"
      missing=1
    fi
  done

  if (( missing != 0 )); then
    return 1
  fi
  k41::log_info 'All requested commands are available.'
}


# Collect and validate the live host against the project target profile.
# Optional arguments are procfs root, sysfs root, and profile path (test seam).
preflight::check_target_inventory() {
  [[ $# -le 3 ]] || {
    k41::log_error 'preflight::check_target_inventory accepts at most three paths.'
    return 2
  }
  local proc_root=${1:-/proc} sys_root=${2:-/sys}
  local module_dir profile_file
  module_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)" || return 1
  profile_file=${3:-"$module_dir/../config/hardware/thinkpad-x280.conf"}
  [[ -r "$profile_file" ]] || {
    k41::log_error "Target hardware profile is unavailable: $profile_file"
    return 1
  }

  local -A host_facts=()
  if ! inventory::collect_host host_facts "$proc_root" "$sys_root"; then
    k41::log_error 'Unable to collect host inventory from procfs/sysfs.'
    return 1
  fi

  k41::log_info 'Detected host inventory (read-only):'
  inventory::render_host_summary host_facts >&2

  if ! inventory::validate_required_facts host_facts; then
    k41::log_error 'Host inventory is incomplete or inconsistent; target compatibility is unresolved.'
    return 1
  fi

  if ! inventory::compare_target_profile host_facts "$profile_file"; then
    k41::log_error 'Detected hardware does not match the configured ThinkPad X280 target profile.'
    return 1
  fi

  k41::log_info 'Target hardware profile matches the detected host.'
}

preflight::report_network_links() {
  if ! command -v ip >/dev/null 2>&1; then
    k41::log_warn 'Network link state unknown: the ip command is unavailable.'
    return 2
  fi

  local output
  if ! output="$(ip -brief link show 2>/dev/null)"; then
    k41::log_warn 'Network link state unknown: ip could not read link information.'
    return 2
  fi

  if [[ -n "$output" ]]; then
    k41::log_info 'Observed network link state (not proof of internet connectivity):'
    printf '%s\n' "$output" >&2
  else
    k41::log_warn 'No network interfaces were reported.'
    return 2
  fi
}
