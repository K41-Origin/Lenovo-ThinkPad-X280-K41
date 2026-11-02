#!/usr/bin/env bash
# Read-only storage discovery and target validation.
# No partitioning, formatting, mounting, or privileged operations live here.

storage::valid_assoc_name() {
  [[ $# -eq 1 && $1 =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || return 2
  local declaration
  declaration="$(declare -p "$1" 2>/dev/null)" || return 2
  [[ "$declaration" == 'declare -A '* || "$declaration" == 'declare -Ar '* ]]
}

# Populate a caller-declared associative array:
#   candidate_count
#   <index>.device_path, .device_type, .size_bytes, .model, .transport,
#   .wwn, .serial, .removable, .read_only, .has_mounted_descendant,
#   .stable_id_kind, .stable_id
#
# Requires lsblk with JSON output and jq. Uses only read-only queries.
storage::discover_candidates() {
  [[ $# -eq 1 ]] || return 2
  storage::valid_assoc_name "$1" || return 2
  local -n _out="$1"
  [[ ! -v _out[candidate_count] ]] || return 2
  command -v lsblk >/dev/null 2>&1 || return 1
  command -v jq >/dev/null 2>&1 || return 1

  local json
  json="$(lsblk --json --bytes --paths --output NAME,TYPE,SIZE,MODEL,TRAN,WWN,SERIAL,RM,RO,MOUNTPOINTS)" || return 1
  jq -e '.blockdevices | type == "array"' >/dev/null 2>&1 <<<"$json" || return 1

  local encoded index=0 object path type size model transport wwn serial removable readonly mounted stable_kind stable_id
  while IFS= read -r encoded; do
    [[ -n "$encoded" ]] || continue
    object="$(printf '%s' "$encoded" | base64 --decode)" || return 1
    path="$(jq -r '.name // ""' <<<"$object")" || return 1
    type="$(jq -r '.type // ""' <<<"$object")" || return 1
    size="$(jq -r 'if .size == null then "" else (.size|tostring) end' <<<"$object")" || return 1
    model="$(jq -r '.model // ""' <<<"$object")" || return 1
    transport="$(jq -r '.tran // ""' <<<"$object")" || return 1
    wwn="$(jq -r '.wwn // ""' <<<"$object")" || return 1
    serial="$(jq -r '.serial // ""' <<<"$object")" || return 1
    removable="$(jq -r 'if .rm == null then "" else (.rm|tostring) end' <<<"$object")" || return 1
    readonly="$(jq -r 'if .ro == null then "" else (.ro|tostring) end' <<<"$object")" || return 1
    mounted="$(jq -r 'if .mounted then "yes" else "no" end' <<<"$object")" || return 1

    [[ "$path" == /dev/* && "$type" == disk && "$size" =~ ^[0-9]+$ ]] || return 1
    [[ "$removable" == true || "$removable" == false ]] || return 1
    [[ "$readonly" == true || "$readonly" == false ]] || return 1
    if [[ -n "$wwn" ]]; then
      stable_kind=wwn; stable_id="$wwn"
    elif [[ -n "$serial" ]]; then
      stable_kind=serial; stable_id="$serial"
    else
      stable_kind=none; stable_id=
    fi

    _out["$index.device_path"]="$path"
    _out["$index.device_type"]="$type"
    _out["$index.size_bytes"]="$size"
    _out["$index.model"]="$model"
    _out["$index.transport"]="$transport"
    _out["$index.wwn"]="$wwn"
    _out["$index.serial"]="$serial"
    _out["$index.removable"]="$removable"
    _out["$index.read_only"]="$readonly"
    _out["$index.has_mounted_descendant"]="$mounted"
    _out["$index.stable_id_kind"]="$stable_kind"
    _out["$index.stable_id"]="$stable_id"
    ((index += 1))
  done < <(
    jq -r '
      def walk: ., (.children[]? | walk);
      .blockdevices[]
      | select(.type == "disk")
      | . as $disk
      | {
          name, type, size, model, tran, wwn, serial, rm, ro,
          mounted: ([$disk | walk | .mountpoints[]? | select(. != null and . != "")] | length > 0)
        }
      | @base64
    ' <<<"$json"
  ) || return 1

  _out[candidate_count]="$index"
}

# Validate a selected candidate against a fresh read-only discovery.
# Target array must contain device_path, size_bytes, and at least one stable
# identifier (wwn or serial). Refuses removable, read-only, mounted, or changed
# targets. This is a safety gate, not proof that a disk is safe to erase.
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
  local i found=0
  for ((i=0; i<current[candidate_count]; i++)); do
    [[ ${current[$i.device_path]} == "${_target[device_path]}" ]] || continue
    found=1
    [[ ${current[$i.size_bytes]} == "${_target[size_bytes]}" ]] || return 1
    [[ ${current[$i.removable]} == false ]] || return 1
    [[ ${current[$i.read_only]} == false ]] || return 1
    [[ ${current[$i.has_mounted_descendant]} == no ]] || return 1
    if [[ -n ${_target[wwn]-} ]]; then
      [[ ${current[$i.wwn]} == "${_target[wwn]}" ]] || return 1
    else
      [[ ${current[$i.serial]} == "${_target[serial]}" ]] || return 1
    fi
    return 0
  done
  (( found == 1 )) || return 1
}
