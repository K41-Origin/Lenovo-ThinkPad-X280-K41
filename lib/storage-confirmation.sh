#!/usr/bin/env bash
# Human-readable storage-plan review and one-shot confirmation gate.
# Source storage-plan.sh and storage-prerequisites.sh before this module.
# This module never performs disk mutations.

storage::plan_review_digest() {
  [[ $# -eq 1 ]] || return 2
  local declaration
  declaration=$(declare -p "$1" 2>/dev/null) || return 2
  [[ $declaration == 'declare -A '* ]] || return 2
  local -n _review_source="$1"
  local -A stable_plan=()
  local key
  for key in "${!_review_source[@]}"; do
    [[ $key == prereq_* ]] && continue
    stable_plan[$key]=${_review_source[$key]}
  done
  storage::plan_digest stable_plan
}

storage::plan_render_review() {
  [[ $# -eq 1 ]] || return 2
  storage::plan_validate "$1" || return 1
  local -n _review_plan="$1"
  local digest
  digest=$(storage::plan_review_digest "$1") || return 1

  printf '%s\n' '========== STORAGE PLAN REVIEW =========='
  printf 'Review digest:       %s\n' "$digest"
  printf 'Target device:       %s\n' "${_review_plan[target_device_path]}"
  printf 'Target model:        %s\n' "${_review_plan[target_model]:-unknown}"
  printf 'Target capacity:     %s bytes\n' "${_review_plan[target_size_bytes]}"
  printf 'Kernel identity:     %s (%s)\n' "${_review_plan[target_stable_id_kind]}" "${_review_plan[target_stable_id]}"
  printf 'Kernel device ID:    %s\n' "${_review_plan[target_major_minor]}"
  printf 'Partition table:     GPT\n'
  printf 'Alignment:           %s bytes\n' "${_review_plan[profile_partition_alignment_bytes]}"
  printf 'ESP:                 %s bytes, FAT32, type %s, mount %s\n' \
    "${_review_plan[esp_size_bytes]}" "${_review_plan[profile_esp_type_guid]}" "${_review_plan[profile_esp_mountpoint]}"
  printf 'Root partition:      sectors %s-%s (%s bytes)\n' \
    "${_review_plan[root_start_sector]}" "${_review_plan[root_end_sector]}" "${_review_plan[root_size_bytes]}"
  printf 'Root storage:        %s + %s, mount %s\n' \
    "${_review_plan[profile_root_encryption]}" "${_review_plan[profile_root_filesystem]}" "${_review_plan[profile_root_mountpoint]}"
  printf 'Swapfile target:     %s bytes\n' "${_review_plan[swapfile_target_bytes]}"
  printf 'Swap policy:         %s\n' "${_review_plan[profile_swap_policy]}"
  printf 'Resume policy:       %s\n' "${_review_plan[profile_resume_policy]}"
  printf 'Boot:                %s, %s, %s, kernel %s\n' \
    "${_review_plan[profile_bootloader]}" "${_review_plan[profile_boot_artifact]}" \
    "${_review_plan[profile_uki_path]}" "${_review_plan[profile_kernel_package]}"
  printf 'Secure Boot:         %s\n' "${_review_plan[profile_secure_boot]}"
  printf 'Prerequisites:       UEFI=%s tools=%s topology=%s unused=%s identity=%s\n' \
    "${_review_plan[prereq_boot_mode]}" "${_review_plan[prereq_required_tools]}" \
    "${_review_plan[prereq_topology]}" "${_review_plan[prereq_target_unused]}" \
    "${_review_plan[prereq_target_identity]}"
  printf '%s\n' '========================================='
}

# Confirmation phrase: ERASE <device-path> <first-12-digest-characters>.
storage::plan_confirm_interactive() {
  [[ $# -eq 2 ]] || return 2
  local plan_name=$1 confirmation_name=$2 declaration
  declaration=$(declare -p "$confirmation_name" 2>/dev/null) || return 2
  [[ $declaration == 'declare -A '* ]] || return 2
  local -n _confirmation_out="$confirmation_name"
  (( ${#_confirmation_out[@]} == 0 )) || return 2

  storage::plan_render_review "$plan_name" || return 1
  local -n _confirm_plan="$plan_name"
  local digest expected answer confirmed_at
  digest=$(storage::plan_review_digest "$plan_name") || return 1
  expected="ERASE ${_confirm_plan[target_device_path]} ${digest:0:12}"
  printf '\nThis action is intended to replace the selected disk and erase its contents.\n' >&2
  printf 'To confirm this exact target and plan, type: %s\n> ' "$expected" >&2
  IFS= read -r answer || return 1
  [[ $answer == "$expected" ]] || {
    printf 'storage: confirmation did not match; cancelled.\n' >&2
    return 1
  }
  confirmed_at=$(date -u +%Y-%m-%dT%H:%M:%SZ) || return 1

  _confirmation_out=()
  _confirmation_out[state]=confirmed
  _confirmation_out[review_digest]=$digest
  _confirmation_out[target_device_path]=${_confirm_plan[target_device_path]}
  _confirmation_out[target_major_minor]=${_confirm_plan[target_major_minor]}
  _confirmation_out[target_size_bytes]=${_confirm_plan[target_size_bytes]}
  _confirmation_out[target_stable_id_kind]=${_confirm_plan[target_stable_id_kind]}
  _confirmation_out[target_stable_id]=${_confirm_plan[target_stable_id]}
  _confirmation_out[phrase]=$expected
  _confirmation_out[confirmed_at]=$confirmed_at
}

# A successful return means only that confirmation and fresh read-only
# prerequisites match. This function does not execute any disk operation.
storage::plan_final_revalidate() {
  [[ $# -eq 5 ]] || return 2
  local plan_name=$1 confirmation_name=$2 target_name=$3 prereq_name=$4 gate_name=$5
  local declaration value
  for declaration in "$confirmation_name" "$target_name" "$prereq_name" "$gate_name"; do
    value=$(declare -p "$declaration" 2>/dev/null) || return 2
    [[ $value == 'declare -A '* ]] || return 2
  done

  local -n _confirmation="$confirmation_name" _target_out="$target_name"
  local -n _prereq_out="$prereq_name" _gate_out="$gate_name"
  (( ${#_target_out[@]} == 0 && ${#_prereq_out[@]} == 0 && ${#_gate_out[@]} == 0 )) || return 2
  [[ ${_confirmation[state]-} == confirmed ]] || return 1

  # Consume before checks: failures require a new review and confirmation.
  _confirmation[state]=consumed
  storage::plan_validate "$plan_name" || return 1

  local -n _final_plan="$plan_name"
  local digest
  digest=$(storage::plan_review_digest "$plan_name") || return 1
  [[ $digest == "${_confirmation[review_digest]-}" ]] || return 1
  [[ ${_final_plan[target_device_path]} == "${_confirmation[target_device_path]-}" ]] || return 1
  [[ ${_final_plan[target_major_minor]} == "${_confirmation[target_major_minor]-}" ]] || return 1
  [[ ${_final_plan[target_size_bytes]} == "${_confirmation[target_size_bytes]-}" ]] || return 1
  [[ ${_final_plan[target_stable_id_kind]} == "${_confirmation[target_stable_id_kind]-}" ]] || return 1
  [[ ${_final_plan[target_stable_id]} == "${_confirmation[target_stable_id]-}" ]] || return 1

  storage::plan_collect_live_prerequisites "$plan_name" "$target_name" "$prereq_name" || return 1
  storage::plan_validate "$plan_name" || return 1
  local fresh_digest
  fresh_digest=$(storage::plan_review_digest "$plan_name") || return 1
  [[ $fresh_digest == "${_confirmation[review_digest]}" ]] || return 1
  [[ ${_target_out[device_path]-} == "${_confirmation[target_device_path]}" ]] || return 1
  [[ ${_target_out[major_minor]-} == "${_confirmation[target_major_minor]}" ]] || return 1
  [[ ${_target_out[size_bytes]-} == "${_confirmation[target_size_bytes]}" ]] || return 1
  [[ ${_target_out[stable_id_kind]-} == "${_confirmation[target_stable_id_kind]}" ]] || return 1
  [[ ${_target_out[stable_id]-} == "${_confirmation[target_stable_id]}" ]] || return 1
  [[ -n ${_prereq_out[evidence_id]-} ]] || return 1

  _gate_out=()
  _gate_out[state]=ready
  _gate_out[review_digest]=$fresh_digest
  _gate_out[evidence_id]=${_prereq_out[evidence_id]}
  _gate_out[target_device_path]=${_target_out[device_path]}
  _gate_out[target_major_minor]=${_target_out[major_minor]}
  _gate_out[target_stable_id]=${_target_out[stable_id]}
  _gate_out[validated_at]=${_prereq_out[observed_at]}
  _confirmation[state]=validated
}
