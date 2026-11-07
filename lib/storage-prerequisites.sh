#!/usr/bin/env bash
# Collect a live, read-only prerequisite snapshot for a bound storage plan.
# Source common.sh, preflight.sh, storage.sh, and storage-plan.sh first.

storage::prerequisite_fail() {
  printf 'storage: live prerequisite check failed at stage: %s\n' "$1" >&2
  return 1
}

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
  [[ \${_plan[status]-} == calculated && \${_plan[schema_version]-} == 1 ]] || { storage::prerequisite_fail plan_state; return 1; }
  [[ -z \${_prereq_out[evidence_id]-} ]] || return 2

  local -a required_tools=(lsblk jq swapon base64 readlink stat sha256sum date)
  preflight::check_commands "\${required_tools[@]}" || { storage::prerequisite_fail required_tools; return 1; }
  preflight::detect_boot_mode || { storage::prerequisite_fail uefi_mode; return 1; }

  local -A discovered=()
  storage::discover_candidates discovered || { storage::prerequisite_fail disk_discovery; return 1; }

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
    [[ \${discovered[$index.has_mounted_descendant]} == no ]] || { storage::prerequisite_fail target_has_mounted_descendant; return 1; }
    [[ \${discovered[$index.has_active_swap_descendant]} == no ]] || { storage::prerequisite_fail target_has_active_swap_descendant; return 1; }
    break
  done
  (( found == 1 )) || { storage::prerequisite_fail selected_disk_missing; return 1; }

  storage::validate_target "$target_name" || { storage::prerequisite_fail target_topology_validation; return 1; }

  [[ \${_target_out[major_minor]} == "\${_plan[target_major_minor]-}" ]] || { storage::prerequisite_fail target_major_minor_changed; return 1; }
  [[ \${_target_out[size_bytes]} == "\${_plan[target_size_bytes]-}" ]] || { storage::prerequisite_fail target_capacity_changed; return 1; }
  [[ \${_target_out[transport]} == "\${_plan[target_transport]-}" ]] || { storage::prerequisite_fail target_transport_changed; return 1; }
  [[ \${_target_out[removable]} == "\${_plan[target_removable]-}" ]] || { storage::prerequisite_fail target_removable_state_changed; return 1; }
  [[ \${_target_out[read_only]} == "\${_plan[target_read_only]-}" ]] || { storage::prerequisite_fail target_read_only_state_changed; return 1; }
  [[ \${_target_out[stable_id_kind]} == "\${_plan[target_stable_id_kind]-}" ]] || { storage::prerequisite_fail target_identity_kind_changed; return 1; }
  [[ \${_target_out[stable_id]} == "\${_plan[target_stable_id]-}" ]] || { storage::prerequisite_fail target_stable_identity_changed; return 1; }
  [[ \${_target_out[wwn]} == "\${_plan[target_wwn]-}" ]] || { storage::prerequisite_fail target_wwn_changed; return 1; }
  [[ \${_target_out[serial]} == "\${_plan[target_serial]-}" ]] || { storage::prerequisite_fail target_serial_changed; return 1; }

  local timestamp digest material
  timestamp=$(date -u +%Y-%m-%dT%H:%M:%S.%NZ) || { storage::prerequisite_fail evidence_timestamp; return 1; }
  local plan_fingerprint
  plan_fingerprint=$(storage::plan_digest "$plan_name") || { storage::prerequisite_fail plan_fingerprint; return 1; }
  material=$(printf '%s\n' "$timestamp" "$plan_fingerprint" "\${_plan[target_device_path]}" "\${_target_out[major_minor]}" "\${_target_out[stable_id_kind]}" "\${_target_out[stable_id]}" "\${_target_out[size_bytes]}") || { storage::prerequisite_fail evidence_material; return 1; }
  digest=$(printf '%s' "$material" | sha256sum) || { storage::prerequisite_fail evidence_digest; return 1; }
  digest=\${digest%% *}
  [[ $digest =~ ^[a-f0-9]{64}$ ]] || { storage::prerequisite_fail evidence_digest_format; return 1; }

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
  storage::plan_bind_prerequisites "$plan_name" "$prereq_name" || { storage::prerequisite_fail bind_evidence_to_plan; return 1; }
  storage::plan_validate "$plan_name" || { storage::prerequisite_fail validate_bound_plan; return 1; }
}
