#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
source "$ROOT/lib/common.sh"
source "$ROOT/lib/preflight.sh"
source "$ROOT/lib/storage.sh"
source "$ROOT/lib/storage-plan.sh"
source "$ROOT/lib/storage-prerequisites.sh"
source "$ROOT/lib/storage-confirmation.sh"
source "$ROOT/lib/storage-execution-dry-run.sh"

TEST_ID=eui.0011223344556677
preflight::check_commands() { [[ $# -gt 0 ]]; }
preflight::detect_boot_mode() { return 0; }
storage::discover_candidates() {
  local -n out="$1"
  out[candidate_count]=1
  out[0.device_path]=/dev/nvme0n1
  out[0.major_minor]=259:0
  out[0.size_bytes]=274877906944
  out[0.transport]=nvme
  out[0.removable]=false
  out[0.read_only]=false
  out[0.stable_id_kind]=wwn
  out[0.stable_id]=$TEST_ID
  out[0.wwn]=$TEST_ID
  out[0.serial]=SN-X280
  out[0.model]="WDC PC SN730"
  out[0.has_mounted_descendant]=no
  out[0.has_active_swap_descendant]=no
}
storage::validate_target() {
  local -n target="$1"
  [[ ${target[device_path]} == /dev/nvme0n1 &&
     ${target[major_minor]} == 259:0 &&
     ${target[stable_id]} == "$TEST_ID" ]]
}

prepare_gate() {
  local plan_name=$1 confirmation_name=$2 target_name=$3 prereq_name=$4 gate_name=$5
  local -n plan_ref="$plan_name"
  local -A initial_target=() initial_prereq=()
  storage::plan_gpt_layout "$plan_name" 274877906944 512 4096 8589934592 1073741824
  local -A target=(
    [device_path]=/dev/nvme0n1 [major_minor]=259:0
    [size_bytes]=274877906944 [transport]=nvme
    [removable]=false [read_only]=false
    [stable_id_kind]=wwn [stable_id]="$TEST_ID"
    [wwn]="$TEST_ID" [serial]=SN-X280 [model]="WDC PC SN730"
  )
  storage::plan_bind_target "$plan_name" target
  storage::plan_collect_live_prerequisites "$plan_name" initial_target initial_prereq
  local digest phrase
  digest=$(storage::plan_review_digest "$plan_name")
  phrase="ERASE /dev/nvme0n1 ${digest:0:12}"
  storage::plan_confirm_interactive "$plan_name" "$confirmation_name" <<<"$phrase" >/dev/null 2>&1
  storage::plan_final_revalidate "$plan_name" "$confirmation_name" "$target_name" "$prereq_name" "$gate_name"
}

declare -A plan=() confirmation=() target=() prereq=() gate=() result=()
prepare_gate plan confirmation target prereq gate
declare -a manifest=()
storage::plan_build_dry_run_manifest plan gate manifest
[[ ${#manifest[@]} == 7 ]]
[[ ${manifest[0]} == gpt_create\|* ]]
[[ ${manifest[1]} == esp_partition_create\|* ]]
[[ ${manifest[2]} == root_partition_create\|* ]]
[[ ${manifest[5]} == luks2_format\|* ]]
[[ ${manifest[6]} == ext4_format\|* ]]
echo 'PASS: manifest has deterministic GPT, partition, LUKS2, ext4 ordering'

# A stale/modified plan cannot pass the gate binding.
declare -A stale_plan=() stale_confirmation=() stale_target=() stale_prereq=() stale_gate=()
prepare_gate stale_plan stale_confirmation stale_target stale_prereq stale_gate
stale_plan[target_model]="changed after confirmation"
declare -a stale_manifest=()
if storage::plan_build_dry_run_manifest stale_plan stale_gate stale_manifest; then
  echo 'FAIL: stale plan was accepted' >&2; exit 1
fi
[[ ${#stale_manifest[@]} == 0 ]]
echo 'PASS: stale plan is rejected before manifest creation'

# A missing/not-ready gate must not produce an operation manifest.
declare -A no_gate=([state]=pending)
declare -a blocked_manifest=()
if storage::plan_build_dry_run_manifest plan no_gate blocked_manifest; then
  echo 'FAIL: non-ready gate was accepted' >&2; exit 1
fi
[[ ${#blocked_manifest[@]} == 0 ]]
echo 'PASS: execution planning is blocked without a ready gate'

# Simulated failure records the failed step and never advances to later steps.
declare -A fail_plan=() fail_confirmation=() fail_target=() fail_prereq=() fail_gate=() fail_result=()
prepare_gate fail_plan fail_confirmation fail_target fail_prereq fail_gate
if storage::plan_simulate_dry_run fail_plan fail_gate fail_result luks2_format; then
  echo 'FAIL: injected failure was not returned' >&2; exit 1
fi
[[ ${fail_result[state]} == failed ]]
[[ ${fail_result[failed_operation]} == luks2_format ]]
[[ ${fail_result[attempted_count]} == 6 ]]
[[ ${fail_result[completed_count]} == 5 ]]
[[ ${fail_gate[state]} == consumed ]]
echo 'PASS: simulated failure halts subsequent operations and consumes the gate'

if storage::plan_simulate_dry_run fail_plan fail_gate fail_result ''; then
  echo 'FAIL: consumed gate was reused' >&2; exit 1
fi
echo 'PASS: consumed gate cannot be reused'

# A complete dry-run records every operation without invoking disk utilities.
declare -A success_plan=() success_confirmation=() success_target=() success_prereq=() success_gate=() success_result=()
prepare_gate success_plan success_confirmation success_target success_prereq success_gate
storage::plan_simulate_dry_run success_plan success_gate success_result ''
[[ ${success_result[state]} == simulated ]]
[[ ${success_result[mode]} == dry-run ]]
[[ ${success_result[attempted_count]} == 7 && ${success_result[completed_count]} == 7 ]]
[[ ${success_gate[state]} == consumed ]]
echo 'PASS: complete dry-run simulation records all operations without system execution'
