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
  local output_declaration
  output_declaration="$(declare -p "$output_name" 2>/dev/null)" || return 2
  [[ "$output_declaration" != "declare -Ar "* ]] || return 2
  [[ -d "$proc_root" && -d "$sys_root" ]] || return 1

  local -n output_ref="$output_name"
  output_ref=()

  local key value line core_count=0 cpu_model_seen=''
  local cpuinfo="$proc_root/cpuinfo"
  if [[ -r "$cpuinfo" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      case "$line" in
        'vendor_id'*) value=${line#*:}; value=${value# }; [[ -n "$value" ]] && output_ref[cpu.vendor]=$value ;;
        'model name'*) value=${line#*:}; value=${value# }; if [[ -n "$value" ]]; then if [[ -z "$cpu_model_seen" ]]; then cpu_model_seen=$value; output_ref[cpu.model]=$value; elif [[ "$cpu_model_seen" != "$value" ]]; then output_ref[cpu.model_conflict]=1; fi; fi ;;
        'cpu family'*) value=${line#*:}; value=${value//[[:space:]]/}; [[ "$value" =~ ^[0-9]+$ ]] && output_ref[cpu.family]=$value ;;
        'model'*) value=${line#*:}; value=${value//[[:space:]]/}; [[ "$value" =~ ^[0-9]+$ ]] && output_ref[cpu.model_id]=$value ;;
        'processor'*) value=${line#*:}; value=${value//[[:space:]]/}; [[ "$value" =~ ^[0-9]+$ ]] && (( core_count += 1 )) ;;

      esac
    done < "$cpuinfo"
    (( core_count > 0 )) && output_ref[cpu.threads]=$core_count
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

inventory::validate_required_facts() {
  [[ $# -eq 1 ]] || return 2
  local input_name=$1
  inventory::valid_assoc_name "$input_name" || return 2
  local -n facts_ref="$input_name"
  local failed=0 key value
  for key in cpu.model memory.total_bytes dmi.sys_vendor dmi.product_name; do
    value=${facts_ref[$key]-}
    if [[ -z "$value" ]]; then printf 'UNKNOWN: required inventory fact unavailable: %s\n' "$key" >&2; failed=1; fi
  done
  if [[ -n ${facts_ref[cpu.model_conflict]+x} ]]; then printf '%s\n' 'ERROR: conflicting CPU model names in /proc/cpuinfo.' >&2; failed=1; fi
  value=${facts_ref[memory.total_bytes]-}
  if [[ -n "$value" && ! "$value" =~ ^[0-9]+$ ]]; then printf '%s\n' 'ERROR: memory.total_bytes is not an unsigned decimal integer.' >&2; failed=1; fi
  if [[ -n "$value" && "$value" =~ ^[0-9]+$ ]]; then
    local max_int=9223372036854775807
    if ((${#value} > 19)) || { ((${#value} == 19)) && [[ "$value" > "$max_int" ]]; }; then printf '%s\n' 'ERROR: memory.total_bytes exceeds supported integer range.' >&2; failed=1; fi
  fi
  return "$failed"
}
inventory::render_host_summary() {
  [[ $# -eq 1 ]] || return 2
  local input_name=$1
  inventory::valid_assoc_name "$input_name" || return 2
  local -n input_ref="$input_name"
  local key
  for key in cpu.vendor cpu.model cpu.family cpu.model_id cpu.threads cpu.model_conflict memory.total_bytes dmi.sys_vendor dmi.product_name dmi.product_version dmi.bios_version dmi.bios_date; do
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
  inventory::validate_required_facts "$inventory_name" || return 1

  # Parse only whitelisted single-quoted scalar assignments; never source/evaluate.
  local line value expected_vendor='' expected_product='' expected_cpu='' memory_min='' memory_max=''
  local seen_vendor=0
  local seen_product=0 seen_cpu=0 seen_min=0 seen_max=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    case "$line" in
      K41_TARGET_VENDOR=*)
        (( seen_vendor == 0 )) || return 1
        value=${line#*=}; [[ $value =~ ^\'[^']*'\'$ ]] || return 1
        expected_vendor=${value:1:${#value}-2}; seen_vendor=1 ;;
      K41_TARGET_PRODUCT_NAME=*)
        (( seen_product == 0 )) || return 1
        value=${line#*=}; [[ $value =~ ^\'[^\']*\'$ ]] || return 1
        expected_product=${value:1:${#value}-2}; seen_product=1 ;;
      K41_TARGET_CPU_MODEL_LINUX=*)
        (( seen_cpu == 0 )) || return 1
        value=${line#*=}; [[ $value =~ ^\'[^\']*\'$ ]] || return 1
        expected_cpu=${value:1:${#value}-2}; seen_cpu=1 ;;
      K41_TARGET_MEMORY_MIN_BYTES=*)
        (( seen_min == 0 )) || return 1
        value=${line#*=}; [[ $value =~ ^\'[0-9]+\'$ ]] || return 1
        memory_min=${value:1:${#value}-2}; seen_min=1 ;;
      K41_TARGET_MEMORY_MAX_BYTES=*)
        (( seen_max == 0 )) || return 1
        value=${line#*=}; [[ $value =~ ^\'[0-9]+\'$ ]] || return 1
        memory_max=${value:1:${#value}-2}; seen_max=1 ;;
    esac
  done < "$profile_file"
  (( seen_vendor && seen_product && seen_cpu && seen_min && seen_max )) || return 1
  [[ -n "$expected_vendor" && -n "$expected_product" && -n "$expected_cpu" ]] || return 1
  # Reject values outside Bash signed 64-bit arithmetic range.
  local max_int=9223372036854775807
  ((${#memory_min} < 19)) || { ((${#memory_min} == 19)) && [[ "$memory_min" < "$max_int" ]]; } || return 1
  ((${#memory_max} < 19)) || { ((${#memory_max} == 19)) && [[ "$memory_max" < "$max_int" || "$memory_max" == "$max_int" ]]; } || return 1
  local min_num=$((10#$memory_min)) max_num=$((10#$memory_max))
  (( min_num > 0 && max_num >= min_num )) || return 1

  local mismatch=0
  if [[ "${facts_ref[dmi.sys_vendor]}" != "$expected_vendor" ]]; then
    printf "WARN: system vendor mismatch (expected %s; detected %s).\\n" "$expected_vendor" "${facts_ref[dmi.sys_vendor]}" >&2
    mismatch=1
  else
    printf "OK: system vendor matches %s.\\n" "$expected_vendor"
  fi
  if [[ -n ${facts_ref[dmi.product_name]+x} ]]; then
    if [[ "${facts_ref[dmi.product_name]}" != "$expected_product" ]]; then
      printf 'WARN: target product mismatch (expected %s; detected %s).\n' "$expected_product" "${facts_ref[dmi.product_name]}" >&2
      mismatch=1
    else
      printf 'OK: target product matches %s.\n' "$expected_product"
    fi
  else
    printf 'UNKNOWN: DMI product name unavailable; target identity not verified.\n' >&2
    mismatch=1
  fi

  if [[ -n ${facts_ref[cpu.model]+x} ]]; then
    if [[ "${facts_ref[cpu.model]}" != *"$expected_cpu"* ]]; then
      printf 'WARN: CPU mismatch (expected %s; detected %s).\n' "$expected_cpu" "${facts_ref[cpu.model]}" >&2
      mismatch=1
    else
      printf 'OK: CPU matches %s.\n' "$expected_cpu"
    fi
  else
    printf 'UNKNOWN: CPU model unavailable; CPU compatibility not verified.\n' >&2
    mismatch=1
  fi

  if [[ -n ${facts_ref[memory.total_bytes]+x} ]]; then
    local detected_memory=$((10#${facts_ref[memory.total_bytes]}))
    if (( detected_memory < min_num || detected_memory > max_num )); then
      printf 'WARN: memory outside target range (%s bytes detected).\n' "${facts_ref[memory.total_bytes]}" >&2
      mismatch=1
    else
      printf 'OK: memory is within the configured target range.\n'
    fi
  else
    printf 'UNKNOWN: memory total unavailable; memory-dependent planning must use another verified source.\n' >&2
    mismatch=1
  fi
  return "$mismatch"
}
