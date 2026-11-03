#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
source "$ROOT/lib/common.sh"
source "$ROOT/lib/preflight.sh"
source "$ROOT/lib/storage.sh"
source "$ROOT/lib/storage-plan.sh"
source "$ROOT/lib/storage-prerequisites.sh"
source "$ROOT/lib/storage-confirmation.sh"

K41_TEST_IDENTITY=eui.0011223344556677
K41_TEST_TOPOLOGY_FAIL=0

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
  out[0.stable_id]=$K41_TEST_IDENTITY
  out[0.wwn]=$K41_TEST_IDENTITY
  out[0.serial]=SN-X280
  out[0.model]="WDC PC SN730"
  out[0.has_mounted_descendant]=no
  out[0.has_active_swap_descendant]=no
}

storage::validate_target() {
  local -n target="$1"
  [[ $K41_TEST_TOPOLOGY_FAIL == 0 ]] || return 1
  [[ ${target[device_path]} == /dev/nvme0n1 ]]
  [[ ${target[major_minor]} == 259:0 ]]
  [[ ${target[stable_id]} == "$K41_TEST_IDENTITY" ]]
}

make_plan() {
  local -A target=(
    [device_path]=/dev/nvme0n1 [major_minor]=259:0
    [size_bytes]=274877906944 [transport]=nvme
    [removable]=false [read_only]=false
    [stable_id_kind]=wwn [stable_id]=eui.0011223344556677
    [wwn]=eui.0011223344556677 [serial]=SN-X280 [model]="WDC PC SN730"
  )
  storage::plan_gpt_layout "$1" 274877906944 512 4096 8589934592 1073741824
  storage::plan_bind_target "$1" target
  local -A initial_target=() initial_prereq=()
  storage::plan_collect_live_prerequisites "$1" initial_target initial_prereq
}

declare -A plan=() confirmation=() target_out=() prereq_out=() gate=()
make_plan plan
review_digest=$(storage::plan_review_digest plan)
expected="ERASE /dev/nvme0n1 ${review_digest:0:12}"
if storage::plan_confirm_interactive plan confirmation <<<"NO" >/dev/null 2>&1; then
  echo 'FAIL: incorrect confirmation phrase was accepted' >&2; exit 1
fi
[[ ${#confirmation[@]} == 0 ]]
echo 'PASS: cancellation and incorrect confirmation are rejected'

storage::plan_confirm_interactive plan confirmation <<<"$expected" >/dev/null 2>&1
[[ ${confirmation[state]} == confirmed ]]
[[ ${confirmation[review_digest]} == "$review_digest" ]]
echo 'PASS: explicit confirmation is bound to the exact plan digest and target'

storage::plan_final_revalidate plan confirmation target_out prereq_out gate
[[ ${confirmation[state]} == validated ]]
[[ ${gate[state]} == ready ]]
[[ ${gate[review_digest]} == "$review_digest" ]]
[[ ${gate[target_stable_id]} == eui.0011223344556677 ]]
[[ -n ${gate[evidence_id]} ]]
[[ ${prereq_out[evidence_id]} == "${gate[evidence_id]}" ]]
echo 'PASS: final live revalidation creates a one-shot ready gate'

if storage::plan_final_revalidate plan confirmation target_out prereq_out gate; then
  echo 'FAIL: confirmation/gate was reusable' >&2; exit 1
fi
echo 'PASS: confirmation cannot be reused'

declare -A changed_plan=() changed_confirmation=() changed_target=() changed_prereq=() changed_gate=()
make_plan changed_plan
digest=$(storage::plan_review_digest changed_plan)
phrase="ERASE /dev/nvme0n1 ${digest:0:12}"
storage::plan_confirm_interactive changed_plan changed_confirmation <<<"$phrase" >/dev/null 2>&1
changed_plan[target_model]="Different disk"
if storage::plan_final_revalidate changed_plan changed_confirmation changed_target changed_prereq changed_gate; then
  echo 'FAIL: modified plan retained confirmation' >&2; exit 1
fi
[[ ${changed_confirmation[state]} == consumed ]]
[[ ${#changed_gate[@]} == 0 ]]
echo 'PASS: modified plan invalidates confirmation and fails closed'

declare -A identity_plan=() identity_confirmation=() identity_target=() identity_prereq=() identity_gate=()
K41_TEST_IDENTITY=eui.0011223344556677
make_plan identity_plan
digest=$(storage::plan_review_digest identity_plan)
phrase="ERASE /dev/nvme0n1 ${digest:0:12}"
storage::plan_confirm_interactive identity_plan identity_confirmation <<<"$phrase" >/dev/null 2>&1
K41_TEST_IDENTITY=DIFFERENT-WWN
if storage::plan_final_revalidate identity_plan identity_confirmation identity_target identity_prereq identity_gate; then
  echo 'FAIL: changed target identity passed final gate' >&2; exit 1
fi
[[ ${#identity_gate[@]} == 0 ]]
echo 'PASS: changed target identity fails final revalidation'

declare -A topology_plan=() topology_confirmation=() topology_target=() topology_prereq=() topology_gate=()
K41_TEST_IDENTITY=eui.0011223344556677
make_plan topology_plan
digest=$(storage::plan_review_digest topology_plan)
phrase="ERASE /dev/nvme0n1 ${digest:0:12}"
storage::plan_confirm_interactive topology_plan topology_confirmation <<<"$phrase" >/dev/null 2>&1
K41_TEST_TOPOLOGY_FAIL=1
if storage::plan_final_revalidate topology_plan topology_confirmation topology_target topology_prereq topology_gate; then
  echo 'FAIL: topology failure passed final gate' >&2; exit 1
fi
[[ ${#topology_gate[@]} == 0 ]]
echo 'PASS: topology failure leaves the final gate closed'
