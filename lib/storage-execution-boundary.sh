#!/usr/bin/env bash
# Stage 7: mock-only execution boundary.
# This module never opens block devices or invokes system/storage commands.
# Callback names are restricted to storage::mock_* functions for test isolation.

storage::plan_mock_execution_boundary() {
  [[ $# -eq 6 ]] || return 2
  local plan_name=$1 gate_name=$2 result_name=$3 probe_fn=$4 executor_fn=$5 fail_operation=$6

  local declaration
  declaration=$(declare -p "$result_name" 2>/dev/null) || return 2
  [[ $declaration == 'declare -A '* ]] || return 2
  [[ $probe_fn =~ ^storage::mock_[a-zA-Z0-9_]+$ ]] || return 2
  [[ $executor_fn =~ ^storage::mock_[a-zA-Z0-9_]+$ ]] || return 2
  declare -F "$probe_fn" >/dev/null || return 2
  declare -F "$executor_fn" >/dev/null || return 2

  local -n _gate="$gate_name" _result="$result_name"
  (( ${#_result[@]} == 0 )) || return 2
  [[ ${_gate[state]-} == ready ]] || return 1
  storage::plan_validate "$plan_name" || return 1

  local -n _plan_ref="$plan_name"
  [[ ${_gate[target_device_path]-} == "${_plan_ref[target_device_path]-}" &&
     ${_gate[target_major_minor]-} == "${_plan_ref[target_major_minor]-}" &&
     ${_gate[target_size_bytes]-} == "${_plan_ref[target_size_bytes]-}" &&
     ${_gate[target_transport]-} == "${_plan_ref[target_transport]-}" &&
     ${_gate[target_removable]-} == "${_plan_ref[target_removable]-}" &&
     ${_gate[target_read_only]-} == "${_plan_ref[target_read_only]-}" &&
     ${_gate[target_stable_id_kind]-} == "${_plan_ref[target_stable_id_kind]-}" &&
     ${_gate[target_stable_id]-} == "${_plan_ref[target_stable_id]-}" &&
     ${_gate[target_wwn]-} == "${_plan_ref[target_wwn]-}" &&
     ${_gate[target_serial]-} == "${_plan_ref[target_serial]-}" ]] || return 1

  local digest
  digest=$(storage::plan_review_digest "$plan_name") || return 1
  [[ $digest == "${_gate[review_digest]-}" ]] || return 1

  local -a manifest=()
  storage::plan_build_dry_run_manifest "$plan_name" "$gate_name" manifest || return 1
  if [[ -n $fail_operation ]]; then
    local found=0 entry
    for entry in "${manifest[@]}"; do
      [[ ${entry%%|*} == "$fail_operation" ]] && found=1
    done
    (( found == 1 )) || return 2
  fi

  # Consume the in-process gate before the first probe/callback.
  _gate[state]=consumed
  _result=()
  _result[mode]=mock-only
  _result[state]=running
  _result[target_device_path]=${_gate[target_device_path]}
  _result[target_major_minor]=${_gate[target_major_minor]}
  _result[target_stable_id_kind]=${_gate[target_stable_id_kind]}
  _result[target_stable_id]=${_gate[target_stable_id]}
  _result[target_transport]=${_gate[target_transport]}
  _result[target_removable]=${_gate[target_removable]}
  _result[target_read_only]=${_gate[target_read_only]}
  _result[review_digest]=$digest
  _result[attempted_count]=0
  _result[completed_count]=0
  _result[recovery_required]=no

  local index=0 operation operation_id
  local -A observed=()
  for operation in "${manifest[@]}"; do
    operation_id=${operation%%|*}
    observed=()
    "$probe_fn" "$plan_name" observed || {
      _result[state]=aborted
      _result[abort_reason]=identity_probe_failed
      _result[recovery_required]=$([[ ${_result[completed_count]} -gt 0 ]] && printf yes || printf no)
      return 1
    }

    # Compare the full target identity immediately before each mock operation.
    if [[ ${observed[device_path]-} != "${_gate[target_device_path]}" ||
          ${observed[major_minor]-} != "${_gate[target_major_minor]}" ||
          ${observed[size_bytes]-} != "${_gate[target_size_bytes]-}" ||
          ${observed[stable_id_kind]-} != "${_gate[target_stable_id_kind]}" ||
          ${observed[transport]-} != "${_gate[target_transport]}" ||
          ${observed[removable]-} != "${_gate[target_removable]}" ||
          ${observed[read_only]-} != "${_gate[target_read_only]}" ||
          ${observed[wwn]-} != "${_gate[target_wwn]}" ||
          ${observed[serial]-} != "${_gate[target_serial]}" ]]; then
      _result[state]=aborted
      _result[abort_reason]=target_identity_changed
      _result[recovery_required]=$([[ ${_result[completed_count]} -gt 0 ]] && printf yes || printf no)
      _result[changed_at_operation]=$operation_id
      return 1
    fi

    _result[attempted_count]=$(( _result[attempted_count] + 1 ))
    _result["attempted_$(( _result[attempted_count] ))"]=$operation
    if ! "$executor_fn" "$operation" "$index"; then
      _result[state]=failed
      _result[failed_operation]=$operation_id
      _result[recovery_required]=$([[ ${_result[completed_count]} -gt 0 ]] && printf yes || printf no)
      return 1
    fi
    _result[completed_count]=$(( _result[completed_count] + 1 ))
    _result["completed_$(( _result[completed_count] ))"]=$operation_id
    ((index += 1))
  done

  _result[state]=mock_completed
  _result[operation_count]=${#manifest[@]}
}
