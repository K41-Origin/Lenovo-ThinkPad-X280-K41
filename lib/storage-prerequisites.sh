#!/usr/bin/env bash
# Collect a live, read-only prerequisite snapshot for a bound storage plan.
# Source common.sh, preflight.sh, storage.sh, and storage-plan.sh first.

storage::plan_collect_live_prerequisites() {
  [[ $# -eq 3 ]] || return 2
  local plan_name=$1 target_name=$2 prereq_name=$3
  local declaration
  declaration=$(declare -p "$plan_name" 2>/dev/null) || return 2
  [[ $declaration == 'declare -A '* ]] || return 2
  declaration=$(declare -p "$target_name" 2>/dev/null) || return 2
  [[ $declaration == 'declare -A '* ]] || return 2
  declaration=$(declare -p "$prereq_name" 2>/dev/null) || return 2
  [[ $declaration == 'declare -A '* ]] || return 2

  local -n _plan="$plan_name" _target_out="$target_name" _prereq_out="$prereq_name"
  [[ \${_plan[status]-} == calculated && \${_plan[schema_version]-} == 1 ]] || return 1
  [[ -z \${_prereq_out[evidence_id]-} ]] || return 2

  local -a required_tools=(lsblk jq swapon base64 readlink stat sha256sum date)
  preflight::check_commands "\${required_tools[@]}" || return 1
  preflight::detect_boot_mode || return 1

  local -A discovered=()
  storage::discover_candidates discovered || return 1

  local index found=0
  for ((index=0; index<discovered[candidate_count]; index++)); do
    [[ \${discovered[$index.device_path]} == "\${_plan[target_device_path]-}" ]] || continue
    found=1
    _target_out=()
    _target_out[device_path]=\${discovered[$index.device_path]}
    _target_out[major_minor]=\${discovered[$index.major_minor]}
    _target_out[size_bytes]=\${discovered[$index.size_bytes]}
    _target_out[transport]=\${discovered[$index.transport]}
    _target_out[removable]=\${discovered[$index.removable]}
    _target_out[read_only]=\${discovered[$index.read_only]}
    _target_out[stable_id_kind]=\${discovered[$index.stable_id_kind]}
    _target_out[stable_id]=\${discovered[$index.stable_id]}
    _target_out[wwn]=\${discovered[$index.wwn]}
    _target_out[serial]=\${discovered[$index.serial]}
    _target_out[model]=\${discovered[$index.model]}
    [[ \${discovered[$index.has_mounted_descendant]} == no ]] || return 1
    [[ \${discovered[$index.has_active_swap_descendant]} == no ]] || return 1
    break
  done
  (( found == 1 )) || return 1

  # Re-discover and compare the selected disk against a fresh topology snapshot.
  storage::validate_target "$target_name" || return 1

  [[ \${_target_out[major_minor]} == "\${_plan[target_major_minor]-}" ]] || return 1
  [[ \${_target_out[size_bytes]} == "\${_plan[target_size_bytes]-}" ]] || return 1
  [[ \${_target_out[transport]} == "\${_plan[target_transport]-}" ]] || return 1
  [[ \${_target_out[removable]} == "\${_plan[target_removable]-}" ]] || return 1
  [[ \${_target_out[read_only]} == "\${_plan[target_read_only]-}" ]] || return 1
  [[ \${_target_out[stable_id_kind]} == "\${_plan[target_stable_id_kind]-}" ]] || return 1
  [[ \${_target_out[stable_id]} == "\${_plan[target_stable_id]-}" ]] || return 1
  [[ \${_target_out[wwn]} == "\${_plan[target_wwn]-}" ]] || return 1
  [[ \${_target_out[serial]} == "\${_plan[target_serial]-}" ]] || return 1

  local timestamp digest material
  timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ) || return 1
  material=$(printf '%s\n' "$timestamp" "\${_plan[target_device_path]}" "\${_target_out[major_minor]}" "\${_target_out[stable_id_kind]}" "\${_target_out[stable_id]}" "\${_target_out[size_bytes]}") || return 1
  digest=$(printf '%s' "$material" | sha256sum) || return 1
  digest=\${digest%% *}
  [[ $digest =~ ^[a-f0-9]{64}$ ]] || return 1

  _prereq_out=()
  _prereq_out[boot_mode]=uefi
  _prereq_out[required_tools]=passed
  _prereq_out[topology]=passed
  _prereq_out[target_unused]=passed
  _prereq_out[target_identity]=passed
  _prereq_out[evidence_id]="live-$timestamp-$digest"
  _prereq_out[observed_at]=$timestamp
  _prereq_out[target_device_path]=\${_target_out[device_path]}
  _prereq_out[target_major_minor]=\${_target_out[major_minor]}
  _prereq_out[target_stable_id]=\${_target_out[stable_id]}
  _prereq_out[target_size_bytes]=\${_target_out[size_bytes]}
}
