#!/usr/bin/env bash
# Build and simulate a storage operation sequence. No system commands are run.
# Source storage-plan.sh and storage-confirmation.sh before this module.

# Produce a deterministic, descriptive operation manifest for review/testing.
# This function only writes strings into the caller's empty indexed array.
storage::plan_build_dry_run_manifest() {
  [[ $# -eq 3 ]] || return 2
  local plan_name=$1 gate_name=$2 manifest_name=$3 declaration
  declaration=$(declare -p "$plan_name" 2>/dev/null) || return 2
  [[ $declaration == 'declare -A '* ]] || return 2
  declaration=$(declare -p "$gate_name" 2>/dev/null) || return 2
  [[ $declaration == 'declare -A '* ]] || return 2
  declaration=$(declare -p "$manifest_name" 2>/dev/null) || return 2
  [[ $declaration == 'declare -a '* ]] || return 2

  local -n _plan="$plan_name" _gate="$gate_name" _manifest="$manifest_name"
  (( ${#_manifest[@]} == 0 )) || return 2
  [[ ${_gate[state]-} == ready ]] || return 1
  storage::plan_validate "$plan_name" || return 1

  local digest
  digest=$(storage::plan_review_digest "$plan_name") || return 1
  [[ $digest == "${_gate[review_digest]-}" ]] || return 1
  [[ ${_plan[target_device_path]} == "${_gate[target_device_path]-}" ]] || return 1
  [[ ${_plan[target_major_minor]} == "${_gate[target_major_minor]-}" ]] || return 1
  [[ ${_plan[target_stable_id]} == "${_gate[target_stable_id]-}" ]] || return 1
  [[ -n ${_gate[evidence_id]-} && -n ${_gate[validated_at]-} ]] || return 1

  # These are logical operation descriptors, not shell commands.
  _manifest=(
    "gpt_create|disk=${_plan[target_device_path]}|entries=${_plan[gpt_entry_count]}"
    "esp_partition_create|disk=${_plan[target_device_path]}|start=${_plan[esp_start_sector]}|end=${_plan[esp_end_sector]}"
    "root_partition_create|disk=${_plan[target_device_path]}|start=${_plan[root_start_sector]}|end=${_plan[root_end_sector]}"
    "esp_type_set|partition=1|type=${_plan[profile_esp_type_guid]}"
    "root_type_set|partition=2|type=${_plan[profile_root_type_guid]}"
    "luks2_format|partition=2|format=luks2"
    "ext4_format|mapper=cryptroot|format=ext4"
  )
}

# Deterministic failure-injection simulator for tests and architecture review.
# It never invokes a callback, shell command, block-device API, or privileged tool.
# The gate is consumed before simulation; a second attempt requires a new gate.
storage::plan_simulate_dry_run() {
  [[ $# -eq 4 ]] || return 2
  local plan_name=$1 gate_name=$2 result_name=$3 fail_operation=$4 declaration
  declaration=$(declare -p "$result_name" 2>/dev/null) || return 2
  [[ $declaration == 'declare -A '* ]] || return 2
  local -n _gate="$gate_name" _result="$result_name"
  (( ${#_result[@]} == 0 )) || return 2

  local -a manifest=()
  storage::plan_build_dry_run_manifest "$plan_name" "$gate_name" manifest || return 1
  [[ -z $fail_operation ]] || {
    local found=0 entry
    for entry in "${manifest[@]}"; do
      [[ ${entry%%|*} == "$fail_operation" ]] && found=1
    done
    (( found == 1 )) || return 2
  }

  _gate[state]=consumed
  _result[mode]=dry-run
  _result[target_device_path]=${_gate[target_device_path]}
  _result[review_digest]=${_gate[review_digest]}
  _result[attempted_count]=0
  _result[completed_count]=0

  local operation
  for operation in "${manifest[@]}"; do
    local operation_id=${operation%%|*}
    _result["attempted_$(( _result[attempted_count] + 1 ))"]=$operation
    _result[attempted_count]=$(( _result[attempted_count] + 1 ))
    if [[ -n $fail_operation && $operation_id == "$fail_operation" ]]; then
      _result[state]=failed
      _result[failed_operation]=$operation_id
      return 1
    fi
    _result[completed_count]=$(( _result[completed_count] + 1 ))
  done
  _result[state]=simulated
  _result[operation_count]=${#manifest[@]}
}
