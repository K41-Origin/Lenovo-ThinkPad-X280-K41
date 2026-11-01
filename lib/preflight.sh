#!/usr/bin/env bash
# Read-only diagnostics for the current live environment.
# Source lib/common.sh before calling these functions.
# No checks run automatically when this file is sourced.

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

preflight::detect_boot_mode() {
  if [[ -d /sys/firmware/efi ]]; then
    k41::log_info 'Boot mode: UEFI (firmware interface directory detected).'
    return 0
  fi

  if [[ -d /sys/firmware ]]; then
    k41::log_info 'Boot mode: legacy/BIOS candidate (UEFI interface directory not detected).'
    return 0
  fi

  k41::log_warn 'Boot mode: unknown (system firmware indicators unavailable).'
  return 2
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
