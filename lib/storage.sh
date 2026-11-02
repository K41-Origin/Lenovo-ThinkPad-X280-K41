#!/usr/bin/env bash
# Read-only storage discovery and target validation.
# No partitioning, formatting, mounting, or privileged operations live here.

# shellcheck source=lib/storage-topology.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/storage-topology.sh"

storage::valid_assoc_name() {
  [[ $# -eq 1 && $1 =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || return 2
  local declaration
  declaration="$(declare -p "$1" 2>/dev/null)" || return 2
  [[ "$declaration" == 'declare -A '* ]]
}

# Output fields include active_swap_descendant. All candidate facts are
# collected from fresh lsblk/swapon snapshots; unknown safety facts fail closed.
storage::discover_candidates() {
  [[ $# -eq 1 ]] || return 2
  storage::valid_assoc_name "$1" || return 2
  local -n _out="$1"
  [[ ! -v _out[candidate_count] ]] || return 2
  command -v lsblk >/dev/null 2>&1 || return 1
  command -v jq >/dev/null 2>&1 || return 1
  command -v swapon >/dev/null 2>&1 || return 1
  command -v base64 >/dev/null 2>&1 || return 1
  command -v readlink >/dev/null 2>&1 || return 1

  local json swaps encoded index=0 object path major_minor type size model transport wwn serial removable readonly mounted active_swap
  json="$(lsblk --json --bytes --paths --output NAME,MAJ:MIN,TYPE,SIZE,MODEL,TRAN,WWN,SERIAL,RM,RO,MOUNTPOINTS)" || return 1
  jq -e '.blockdevices | type == "array"' >/dev/null 2>&1 <<<"$json" || return 1
  swaps="$(swapon --show --noheadings --raw --output NAME)" || return 1

  local rows
  rows="$(jq -er '
    def walk: ., (.children[]? | walk);
    .blockdevices[]
    | select(.type == "disk")
    | . as $disk
    | {
        name, "maj:min", type, size, model, tran, wwn, serial, rm, ro,
        mounted: ([$disk | walk | .mountpoints[]? | select(. != null and . != "")] | length > 0),
        descendants: ([$disk | walk | .name] | map(select(type == "string")))
      }
    | @base64
  ' <<<"$json")" || return 1

  while IFS= read -r encoded; do
    [[ -n "$encoded" ]] || continue
    object="$(printf '%s' "$encoded" | base64 --decode)" || return 1
    path="$(jq -er '.name | strings | select(length > 0)' <<<"$object")" || return 1
    major_minor="$(jq -er '.["maj:min"] | strings | select(test("^[0-9]+:[0-9]+$"))' <<<"$object")" || return 1
    type="$(jq -er '.type | strings | select(length > 0)' <<<"$object")" || return 1
    size="$(jq -er 'if (.size|type) == "number" and .size > 0 then (.size|tostring) else error("invalid size") end' <<<"$object")" || return 1
    model="$(jq -r '.model // "" | strings' <<<"$object")" || return 1
    transport="$(jq -r '.tran // "" | strings' <<<"$object")" || return 1
    wwn="$(jq -r '.wwn // "" | strings' <<<"$object")" || return 1
    serial="$(jq -r '.serial // "" | strings' <<<"$object")" || return 1
    removable="$(jq -er 'if .rm == true then "true" elif .rm == false then "false" else error("unknown removable state") end' <<<"$object")" || return 1
    readonly="$(jq -er 'if .ro == true then "true" elif .ro == false then "false" else error("unknown read-only state") end' <<<"$object")" || return 1
    mounted="$(jq -er 'if .mounted == true then "yes" elif .mounted == false then "no" else error("unknown mount state") end' <<<"$object")" || return 1
    [[ "$path" == /dev/* && "$type" == disk && "$size" =~ ^[0-9]+$ ]] || return 1

    active_swap=no
    local descendant swap_path resolved_descendant resolved_swap
    while IFS= read -r descendant; do
      [[ -n "$descendant" ]] || continue
      resolved_descendant="$(readlink -f -- "$descendant")" || return 1
      while IFS= read -r swap_path; do
        [[ -n "$swap_path" ]] || continue
        resolved_swap="$(readlink -f -- "$swap_path")" || continue
        if [[ "$resolved_descendant" == "$resolved_swap" ]]; then
          active_swap=yes
          break 2
        fi
      done <<<"$swaps"
    done < <(jq -r '.descendants[]' <<<"$object")

    local stable_kind=none stable_id=
    if [[ -n "$wwn" ]]; then
      stable_kind=wwn; stable_id="$wwn"
    elif [[ -n "$serial" ]]; then
      stable_kind=serial; stable_id="$serial"
    fi

    _out["$index.device_path"]="$path"
    _out["$index.major_minor"]="$major_minor"
    _out["$index.device_type"]="$type"
    _out["$index.size_bytes"]="$size"
    _out["$index.model"]="$model"
    _out["$index.transport"]="$transport"
    _out["$index.wwn"]="$wwn"
    _out["$index.serial"]="$serial"
    _out["$index.removable"]="$removable"
    _out["$index.read_only"]="$readonly"
    _out["$index.has_mounted_descendant"]="$mounted"
    _out["$index.has_active_swap_descendant"]="$active_swap"
    _out["$index.stable_id_kind"]="$stable_kind"
    _out["$index.stable_id"]="$stable_id"
    ((index += 1))
  done <<<"$rows"

  # Stable identifiers must be unique across discovered whole disks.
  local i j
  for ((i=0; i<index; i++)); do
    for ((j=i+1; j<index; j++)); do
      if [[ -n "${_out[$i.wwn]}" && "${_out[$i.wwn]}" == "${_out[$j.wwn]}" ]]; then
        return 1
      fi
      if [[ -n "${_out[$i.serial]}" && "${_out[$i.serial]}" == "${_out[$j.serial]}" ]]; then
        return 1
      fi
    done
  done
  _out[candidate_count]="$index"
}

# Revalidate a selected internal NVMe disk against a fresh read-only snapshot.
# Both supplied identity fields are compared when present.
storage::validate_target() {
  [[ $# -eq 1 ]] || return 2
  storage::valid_assoc_name "$1" || return 2
  local -n _target="$1"
  local required
  for required in device_path size_bytes; do
    [[ -n ${_target[$required]-} ]] || return 2
  done
  [[ -n ${_target[wwn]-} || -n ${_target[serial]-} ]] || return 1
  [[ ${_target[device_path]} == /dev/* && ${_target[size_bytes]} =~ ^[0-9]+$ ]] || return 2

  local -A current=()
  storage::discover_candidates current || return 1
  local i
  for ((i=0; i<current[candidate_count]; i++)); do
    [[ ${current[$i.device_path]} == "${_target[device_path]}" ]] || continue
    [[ ${current[$i.size_bytes]} == "${_target[size_bytes]}" ]] || return 1
    [[ ${current[$i.removable]} == false && ${current[$i.read_only]} == false ]] || return 1
    [[ ${current[$i.transport]} == nvme ]] || return 1
    [[ ${current[$i.major_minor]} =~ ^[0-9]+:[0-9]+$ ]] || return 1
    storage::topology_check_target "${current[$i.major_minor]}" /sys /proc/self/mountinfo /proc/swaps || return 1
    [[ ${current[$i.has_mounted_descendant]} == no ]] || return 1
    [[ ${current[$i.has_active_swap_descendant]} == no ]] || return 1
    if [[ -n ${_target[wwn]-} ]]; then
      [[ ${current[$i.wwn]} == "${_target[wwn]}" ]] || return 1
    fi
    if [[ -n ${_target[serial]-} ]]; then
      [[ ${current[$i.serial]} == "${_target[serial]}" ]] || return 1
    fi
    return 0
  done
  return 1
}
