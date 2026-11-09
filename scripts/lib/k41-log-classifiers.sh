#!/usr/bin/env bash
# Conservative Caelestia log classifier. Prints one finding per line.
# Arguments: LOG_FILE SCHEME_FILE
k41_classify_caelestia_log() {
  local log_file=$1 scheme_file=$2 bluetooth_active=${3:-0} rtkit_installed=${4:-0}
  local scheme_warning="Read of $scheme_file failed: File does not exist"
  local filtered
  filtered="$(mktemp)" || return 2

  # Classify the scheme condition separately so a resolved startup warning
  # cannot be re-detected by the generic QML failure matcher.
  grep -Fiv -- "$scheme_warning" "$log_file" >"$filtered" || :
  # A missing .face is an optional avatar resource, not a shell failure.
  sed -E '/Source file does not exist.*\.face([[:space:]]|$)/Id' "$filtered" >"$filtered.tmp"
  mv -- "$filtered.tmp" "$filtered"

  if [[ ! -s $scheme_file ]] &&
     grep -Fqi -- "$scheme_warning" "$log_file"; then
    printf '%s\n' 'scheme-missing'
  fi
  if grep -Eiq '(^|[[:space:]])(fatal|critical):|QML.*(Error|failed)|failed to load.*(QML|plugin|module)|TypeError:|ReferenceError:' "$filtered"; then
    printf '%s\n' 'runtime-error'
  fi
  if grep -Eiq 'Source file does not exist' "$filtered"; then
    printf '%s\n' 'missing-resource'
  fi
  if [[ $bluetooth_active != 1 ]] && grep -Eiq 'org\.bluez' "$filtered"; then
    printf '%s\n' 'bluez-service-inactive'
  fi
  if [[ $rtkit_installed != 1 ]] && grep -Eiq 'RTKit' "$filtered"; then
    printf '%s\n' 'rtkit-package-missing'
  fi
  rm -f -- "$filtered"
}

# Classify journal query results without treating an empty error-priority
# query as a fault. Arguments: FILE QUERY_EXIT_CODE REGULATORY_DB_PRESENT [CPU_VULNERABILITY_DIR]
k41_classify_journal() {
  local journal_file=$1 query_rc=$2 regulatory_db_present=$3 cpu_vulnerability_dir=${4:-/sys/devices/system/cpu/vulnerabilities} filtered cpu_attention=0
  if (( query_rc != 0 )); then
    printf '%s\n' 'query-failed'
    return 0
  fi
  if [[ ! -s $journal_file ]] || grep -Eiq '^[[:space:]]*-- No entries --[[:space:]]*  if grep -Eiq 'not seeing messages|permission denied|failed to open.*journal|No journal files were found' "$journal_file"; then
    printf '%s\n' 'access-limited'
    return 0
  fi
  if grep -Eiq 'kernel BUG|Oops:|Kernel panic|general protection fault|Out of memory|oom-kill' "$journal_file"; then
    printf '%s\n' 'critical'
    return 0
  fi

  filtered="$(mktemp)" || {
    printf '%s\n' 'classifier-failed'
    return 0
  }
  cp -- "$journal_file" "$filtered"
  if [[ $regulatory_db_present == 1 ]]; then
    grep -Eiv 'Direct firmware load for regulatory\.db failed' "$filtered" >"$filtered.tmp" || :
    mv -- "$filtered.tmp" "$filtered"
  fi

  # CPU boot notices describe detected hardware, not necessarily an
  # unmitigated vulnerability. Correlate each with its live sysfs state.
  # Missing/unknown state remains actionable (fail conservative).
  local cpu_patterns=('MDS CPU bug present' 'MMIO Stale Data CPU bug present' 'VMSCAPE:')
  local cpu_files=(mds mmio_stale_data vmscape)
  local index cpu_state_file
  for index in "${!cpu_patterns[@]}"; do
    if grep -Fqi -- "${cpu_patterns[$index]}" "$filtered"; then
      cpu_state_file="$cpu_vulnerability_dir/${cpu_files[$index]}"
      if [[ ! -r $cpu_state_file ]] ||
         grep -Eiq 'Vulnerable|SMT vulnerable' "$cpu_state_file" ||
         ! grep -Eiq 'Mitigation:|Not affected' "$cpu_state_file"; then
        cpu_attention=1
      fi
    fi
  done

  if grep -Eiq 'segfault|coredump|Out of memory|oom-kill|PAM _pam_init_handlers: no default config other|Bluetooth: hci[0-9]+: Reading supported features failed|Direct firmware load for regulatory\.db failed' "$filtered" ||
     (( cpu_attention == 1 )); then
    printf '%s\n' 'actionable'
  elif grep -Eiq 'Failed|failed|failure|QML.*Error|error:' "$filtered"; then
    printf '%s\n' 'unclassified-error'
  elif grep -Eiq 'nl80211: kernel reports: multicast RX registrations are not supported|virt/tdx: TDX not supported|hpet_acpi_probe: no address or irqs in _CRS|ENERGY_PERF_BIAS:' "$filtered"; then
    printf '%s\n' 'informational-only'
  else
    printf '%s\n' 'no-configured-signature'
  fi
  rm -f -- "$filtered" "$filtered.tmp"
}
 "$journal_file"; then
    printf '%s\n' 'no-error-entries'
    return 0
  fi
  if grep -Eiq 'not seeing messages|permission denied|failed to open.*journal|No journal files were found' "$journal_file"; then
    printf '%s\n' 'access-limited'
    return 0
  fi
  if grep -Eiq 'kernel BUG|Oops:|Kernel panic|general protection fault|Out of memory|oom-kill' "$journal_file"; then
    printf '%s\n' 'critical'
    return 0
  fi

  filtered="$(mktemp)" || {
    printf '%s\n' 'classifier-failed'
    return 0
  }
  cp -- "$journal_file" "$filtered"
  if [[ $regulatory_db_present == 1 ]]; then
    grep -Eiv 'Direct firmware load for regulatory\.db failed' "$filtered" >"$filtered.tmp" || :
    mv -- "$filtered.tmp" "$filtered"
  fi

  # CPU boot notices describe detected hardware, not necessarily an
  # unmitigated vulnerability. Correlate each with its live sysfs state.
  # Missing/unknown state remains actionable (fail conservative).
  local cpu_patterns=('MDS CPU bug present' 'MMIO Stale Data CPU bug present' 'VMSCAPE:')
  local cpu_files=(mds mmio_stale_data vmscape)
  local index cpu_state_file
  for index in "${!cpu_patterns[@]}"; do
    if grep -Fqi -- "${cpu_patterns[$index]}" "$filtered"; then
      cpu_state_file="$cpu_vulnerability_dir/${cpu_files[$index]}"
      if [[ ! -r $cpu_state_file ]] ||
         grep -Eiq 'Vulnerable|SMT vulnerable' "$cpu_state_file" ||
         ! grep -Eiq 'Mitigation:|Not affected' "$cpu_state_file"; then
        cpu_attention=1
      fi
    fi
  done

  if grep -Eiq 'segfault|coredump|Out of memory|oom-kill|PAM _pam_init_handlers: no default config other|Bluetooth: hci[0-9]+: Reading supported features failed|Direct firmware load for regulatory\.db failed' "$filtered" ||
     (( cpu_attention == 1 )); then
    printf '%s\n' 'actionable'
  elif grep -Eiq 'Failed|failed|failure|QML.*Error|error:' "$filtered"; then
    printf '%s\n' 'unclassified-error'
  elif grep -Eiq 'nl80211: kernel reports: multicast RX registrations are not supported|virt/tdx: TDX not supported|hpet_acpi_probe: no address or irqs in _CRS|ENERGY_PERF_BIAS:' "$filtered"; then
    printf '%s\n' 'informational-only'
  else
    printf '%s\n' 'no-configured-signature'
  fi
  rm -f -- "$filtered" "$filtered.tmp"
}
