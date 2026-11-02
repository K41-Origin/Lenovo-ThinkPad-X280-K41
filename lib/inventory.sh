#!/usr/bin/env bash
# Read-only host inventory and target-profile comparison.
# Safe to source: function definitions only; no commands or filesystem access.

inventory::valid_assoc_name() {
  [[ $# -eq 1 && "$1" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || return 1
  local declaration
  declaration="$(declare -p "$1" 2>/dev/null)" || return 1
  [[ "$declaration" == "declare -A "* || "$declaration" == "declare -Ar "* ]]
}

inventory::read_first_line() {
  local file=$1 value
  [[ -r "$file" ]] || return 1
  IFS= read -r value < "$file" || [[ -n "$value" ]] || return 1
  [[ -n "$value" ]] || return 1
  printf '%s' "$value"
}

inventory::collect_host() {
  [[ $# -ge 1 && $# -le 3 ]] || return 2
  local output_name=$1 proc_root=${2:-/proc} sys_root=${3:-/sys}
  inventory::valid_assoc_name "$output_name" || return 2
  [[ -d "$proc_root" && -d "$sys_root" ]] || return 1

  local -n output_ref="$output_name"
  output_ref=()

  local key value line core_count=0
  local cpuinfo="$proc_root/cpuinfo"
  if [[ -r "$cpuinfo" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      case "$line" in
        'vendor_id'*) value=${line#*:}; value=${value# }; [[ -n "$value" ]] && output_ref[cpu.vendor]=$value ;;
        'model name'*) value=${line#*:}; value=${value# }; [[ -n "$value" && -z ${output_ref[cpu.model]+x} ]] && output_ref[cpu.model]=$value ;;
        'cpu family'*) value=${line#*:}; value=${value//[[:space:]]/}; [[ "$value" =~ ^[0-9]+$ ]] && output_ref[cpu.family]=$value ;;
        'model'*) value=${line#*:}; value=${value//[[:space:]]/}; [[ "$value" =~ ^[0-9]+$ ]] && output_ref[cpu.model_id]=$value ;;
        'processor'*) value=${line#*:}; value=${value//[[:space:]]/}; [[ "$value" =~ ^[0-9]+$ ]] && (( core_count += 1 )) ;;

      esac
    done < "$cpuinfo"
    (( core_count > 0 )) && output_ref[cpu.cores]=$core_count
  fi

  local meminfo="$proc_root/meminfo"
  if [[ -r "$meminfo" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      if [[ "$line" =~ ^MemTotal:[[:space:]]+([0-9]+)[[:space:]]+kB$ ]]; then
        output_ref[memory.total_bytes]=$(( BASH_REMATCH[1] * 1024 ))
        break
      fi
    done < "$meminfo"
  fi

  for key in sys_vendor product_name product_version bios_version bios_date; do
    value=$(inventory::read_first_line "$sys_root/class/dmi/id/$key") || continue
    case "$key" in
      sys_vendor) output_ref[dmi.sys_vendor]=$value ;;
      product_name) output_ref[dmi.product_name]=$value ;;
      product_version) output_ref[dmi.product_version]=$value ;;
      bios_version) output_ref[dmi.bios_version]=$value ;;
      bios_date) output_ref[dmi.bios_date]=$value ;;
    esac
  done
  return 0
}

inventory::render_host_summary() {
  [[ $# -eq 1 ]] || return 2
  local input_name=$1
  inventory::valid_assoc_name "$input_name" || return 2
  local -n input_ref="$input_name"
  local key
  for key in cpu.vendor cpu.model cpu.family cpu.model_id cpu.cores memory.total_bytes dmi.sys_vendor dmi.product_name dmi.product_version dmi.bios_version dmi.bios_date; do
    if [[ -n ${input_ref[$key]+x} && -n ${input_ref[$key]} ]]; then
      printf '%-24s %s\n' "$key" "${input_ref[$key]}"
    else
      printf '%-24s %s\n' "$key" 'unknown/unavailable'
    fi
  done
}

inventory::compare_target_profile() {
  [[ $# -eq 2 ]] || return 2
  local inventory_name=$1 profile_file=$2
  inventory::valid_assoc_name "$inventory_name" || return 2
  [[ -r "$profile_file" ]] || return 1
  local -n facts_ref="$inventory_name"

  # shellcheck source=/dev/null
  source "$profile_file" || return 1
  local mismatch=0
  if [[ -n ${facts_ref[dmi.product_name]+x} ]]; then
    if [[ "${facts_ref[dmi.product_name]}" != "$K41_TARGET_PRODUCT_NAME" ]]; then
      printf 'WARN: target product mismatch (expected %s; detected %s).\n' "$K41_TARGET_PRODUCT_NAME" "${facts_ref[dmi.product_name]}" >&2
      mismatch=1
    else
      printf 'OK: target product matches %s.\n' "$K41_TARGET_PRODUCT_NAME"
    fi
  else
    printf 'UNKNOWN: DMI product name unavailable; target identity not verified.\n' >&2
    mismatch=1
  fi

  if [[ -n ${facts_ref[cpu.model]+x} ]]; then
    if [[ "${facts_ref[cpu.model]}" != *"$K41_TARGET_CPU_MODEL_LINUX"* ]]; then
      printf 'WARN: CPU mismatch (expected %s; detected %s).\n' "$K41_TARGET_CPU_MODEL_LINUX" "${facts_ref[cpu.model]}" >&2
      mismatch=1
    else
      printf 'OK: CPU matches %s.\n' "$K41_TARGET_CPU_MODEL_LINUX"
    fi
  else
    printf 'UNKNOWN: CPU model unavailable; CPU compatibility not verified.\n' >&2
    mismatch=1
  fi

  if [[ -n ${facts_ref[memory.total_bytes]+x} ]]; then
    if (( facts_ref[memory.total_bytes] < K41_TARGET_MEMORY_MIN_BYTES || facts_ref[memory.total_bytes] > K41_TARGET_MEMORY_MAX_BYTES )); then
      printf 'WARN: memory outside target range (%s bytes detected).\n' "${facts_ref[memory.total_bytes]}" >&2
      mismatch=1
    else
      printf 'OK: memory is within the configured 8 GiB target range.\n'
    fi
  else
    printf 'UNKNOWN: memory total unavailable; memory-dependent planning must use another verified source.\n' >&2
    mismatch=1
  fi
  return "$mismatch"
}
