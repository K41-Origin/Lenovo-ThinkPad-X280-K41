#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
source "$ROOT/tests/helpers/storage-fixtures.sh"
source "$ROOT/lib/common.sh"
source "$ROOT/lib/preflight.sh"
source "$ROOT/lib/storage.sh"
source "$ROOT/lib/storage-plan.sh"
source "$ROOT/lib/storage-prerequisites.sh"
source "$ROOT/lib/storage-confirmation.sh"
source "$ROOT/lib/storage-execution-dry-run.sh"
source "$ROOT/lib/storage-execution-boundary.sh"

TEST_ID=eui.0011223344556677
MOCK_PROBE_COUNT=0
MOCK_EXEC_COUNT=0
MOCK_CHANGE_AT=0
MOCK_READ_ONLY_CHANGE_AT=0
MOCK_FAIL_AT=-1
MOCK_PROBE_FAIL=0
MOCK_CURRENT_ID=$TEST_ID
MOCK_LOG=()

preflight::check_commands() { [[ $# -gt 0 ]]; }
preflight::detect_boot_mode() { return 0; }
storage::discover_candidates() {
  local -n out="$1"
  out[candidate_count]=1
  out["0.device_path"]=/dev/nvme0n1
  out["0.major_minor"]=259:0
  out["0.size_bytes"]=274877906944
  out["0.transport"]=nvme
  out["0.removable"]=false
  out["0.read_only"]=false
  out["0.stable_id_kind"]=wwn
  out["0.stable_id"]=$TEST_ID
  out["0.wwn"]=$TEST_ID
  out["0.serial"]=SN-X280
  out["0.model"]="WDC PC SN730"
  out["0.has_mounted_descendant"]=no
  out["0.has_active_swap_descendant"]=no
}
storage::validate_target() {
  local -n selected_ref="$1"
  [[ ${selected_ref[device_path]} == /dev/nvme0n1 &&
     ${selected_ref[major_minor]} == 259:0 &&
     ${selected_ref[stable_id]} == "$TEST_ID" ]]
}

prepare_gate() {
  local plan_name=$1 confirmation_name=$2 target_name=$3 prereq_name=$4 gate_name=$5
  local -A initial_target=() initial_prereq=()
  storage::plan_gpt_layout "$plan_name" 274877906944 512 4096 8589934592 1073741824
  local -A bound_target=()
  storage_test::make_x280_target bound_target "${TEST_ID:-eui.0011223344556677}" "SN-X280"
  storage::plan_bind_target "$plan_name" bound_target
  storage::plan_collect_live_prerequisites "$plan_name" initial_target initial_prereq
  local digest phrase
  digest=$(storage::plan_review_digest "$plan_name")
  phrase="ERASE /dev/nvme0n1 ${digest:0:12}"
  storage::plan_confirm_interactive "$plan_name" "$confirmation_name" <<<"$phrase" >/dev/null 2>&1
  storage::plan_final_revalidate "$plan_name" "$confirmation_name" "$target_name" "$prereq_name" "$gate_name"
}

storage::mock_probe_target() {
  [[ $# -eq 2 ]] || return 2
  local plan_name=$1 output_name=$2
  local -n output="$output_name"
  ((MOCK_PROBE_COUNT += 1))
  if (( MOCK_PROBE_FAIL )); then return 1; fi
  if (( MOCK_CHANGE_AT > 0 && MOCK_PROBE_COUNT >= MOCK_CHANGE_AT )); then
    MOCK_CURRENT_ID=changed-device-id
  fi
  output[device_path]=/dev/nvme0n1
  output[major_minor]=259:0
  output[size_bytes]=274877906944
  output[stable_id_kind]=wwn
  output[stable_id]=$MOCK_CURRENT_ID
  output[wwn]=$MOCK_CURRENT_ID
  output[serial]=SN-X280
  output[transport]=nvme
  output[removable]=false
  output[read_only]=false
  if (( MOCK_READ_ONLY_CHANGE_AT > 0 && MOCK_PROBE_COUNT >= MOCK_READ_ONLY_CHANGE_AT )); then output[read_only]=true; fi
}
storage::mock_record_operation() {
  [[ $# -eq 2 ]] || return 2
  local operation=$1 index=$2
  MOCK_LOG+=("$operation")
  ((MOCK_EXEC_COUNT += 1))
  (( index == MOCK_FAIL_AT )) && return 1
  return 0
}
reset_mock() {
  MOCK_PROBE_COUNT=0 MOCK_EXEC_COUNT=0 MOCK_CHANGE_AT=0 MOCK_READ_ONLY_CHANGE_AT=0 MOCK_FAIL_AT=-1 MOCK_PROBE_FAIL=0
  MOCK_CURRENT_ID=$TEST_ID
  MOCK_LOG=()
}

declare -A plan=() confirmation=() target=() prereq=() gate=() result=()
prepare_gate plan confirmation target prereq gate
reset_mock
storage::plan_mock_execution_boundary plan gate result storage::mock_probe_target storage::mock_record_operation ''
[[ ${result[state]} == mock_completed ]]
[[ ${result[completed_count]} == 8 && $MOCK_EXEC_COUNT == 8 ]]
[[ $MOCK_PROBE_COUNT == 8 && ${gate[state]} == consumed ]]
echo 'PASS: mock boundary re-probes full target identity immediately before all eight operations'

# A target identity change on probe four must block operation four.
declare -A changed_plan=() changed_confirmation=() changed_target=() changed_prereq=() changed_gate=() changed_result=()
prepare_gate changed_plan changed_confirmation changed_target changed_prereq changed_gate
reset_mock
MOCK_CHANGE_AT=4
if storage::plan_mock_execution_boundary changed_plan changed_gate changed_result storage::mock_probe_target storage::mock_record_operation ''; then
  echo 'FAIL: changed target identity was accepted' >&2; exit 1
fi
[[ ${changed_result[state]} == aborted ]]
[[ ${changed_result[abort_reason]} == target_identity_changed ]]
[[ ${changed_result[completed_count]} == 3 && $MOCK_EXEC_COUNT == 3 ]]
[[ ${changed_result[recovery_required]} == yes ]]
[[ ${changed_gate[state]} == consumed ]]
echo 'PASS: changed identity blocks the next mock operation and records partial-state recovery'

# A safety-attribute change is treated as a target mismatch as well.
declare -A readonly_plan=() readonly_confirmation=() readonly_target=() readonly_prereq=() readonly_gate=() readonly_result=()
prepare_gate readonly_plan readonly_confirmation readonly_target readonly_prereq readonly_gate
reset_mock
MOCK_READ_ONLY_CHANGE_AT=2
if storage::plan_mock_execution_boundary readonly_plan readonly_gate readonly_result storage::mock_probe_target storage::mock_record_operation ''; then
  echo 'FAIL: newly read-only target was accepted' >&2; exit 1
fi
[[ ${readonly_result[state]} == aborted ]]
[[ ${readonly_result[abort_reason]} == target_identity_changed ]]
[[ ${readonly_result[completed_count]} == 1 && $MOCK_EXEC_COUNT == 1 ]]
[[ ${readonly_result[recovery_required]} == yes ]]
echo 'PASS: changed read-only safety attribute blocks the next operation'

# A failed initial identity probe must result in zero executor calls.
declare -A probe_plan=() probe_confirmation=() probe_target=() probe_prereq=() probe_gate=() probe_result=()
prepare_gate probe_plan probe_confirmation probe_target probe_prereq probe_gate
reset_mock
MOCK_PROBE_FAIL=1
if storage::plan_mock_execution_boundary probe_plan probe_gate probe_result storage::mock_probe_target storage::mock_record_operation ''; then
  echo 'FAIL: failed identity probe was accepted' >&2; exit 1
fi
[[ ${probe_result[state]} == aborted && ${probe_result[abort_reason]} == identity_probe_failed ]]
[[ $MOCK_EXEC_COUNT == 0 && ${probe_result[recovery_required]} == no ]]
echo 'PASS: failed initial identity probe produces zero mock executor calls'

# Failure after several operations marks partial state; no automatic rollback is claimed.
declare -A failed_plan=() failed_confirmation=() failed_target=() failed_prereq=() failed_gate=() failed_result=()
prepare_gate failed_plan failed_confirmation failed_target failed_prereq failed_gate
reset_mock
MOCK_FAIL_AT=5
if storage::plan_mock_execution_boundary failed_plan failed_gate failed_result storage::mock_probe_target storage::mock_record_operation ''; then
  echo 'FAIL: injected executor failure was not returned' >&2; exit 1
fi
[[ ${failed_result[state]} == failed && ${failed_result[failed_operation]} == luks2_format ]]
[[ ${failed_result[completed_count]} == 5 && $MOCK_EXEC_COUNT == 6 ]]
[[ ${failed_result[recovery_required]} == yes ]]
echo 'PASS: partial executor failure is recorded and recovery is required without automatic rollback'

# Callback allowlist and missing gate reject before any operation.
declare -A invalid_plan=() invalid_confirmation=() invalid_target=() invalid_prereq=() invalid_gate=() invalid_result=()
prepare_gate invalid_plan invalid_confirmation invalid_target invalid_prereq invalid_gate
reset_mock
if storage::plan_mock_execution_boundary invalid_plan invalid_gate invalid_result storage::mock_probe_target printf ''; then
  echo 'FAIL: non-mock callback was accepted' >&2; exit 1
fi
[[ $MOCK_EXEC_COUNT == 0 && ${#invalid_result[@]} == 0 ]]
echo 'PASS: non-mock executor callback is rejected before execution'

# Gate metadata must agree with the immutable plan before any mock call.
declare -A tampered_plan=() tampered_confirmation=() tampered_target=() tampered_prereq=() tampered_gate=() tampered_result=()
prepare_gate tampered_plan tampered_confirmation tampered_target tampered_prereq tampered_gate
tampered_gate[target_read_only]=true
reset_mock
if storage::plan_mock_execution_boundary tampered_plan tampered_gate tampered_result storage::mock_probe_target storage::mock_record_operation ''; then
  echo 'FAIL: gate/plan target-attribute mismatch was accepted' >&2; exit 1
fi
[[ $MOCK_EXEC_COUNT == 0 && ${#tampered_result[@]} == 0 ]]
[[ ${tampered_gate[state]} == ready ]]
echo 'PASS: gate/plan target-attribute mismatch blocks before gate consumption and mock execution'

