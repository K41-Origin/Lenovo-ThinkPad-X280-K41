#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
source "$ROOT/lib/common.sh"
source "$ROOT/lib/preflight.sh"
source "$ROOT/lib/storage.sh"
source "$ROOT/lib/storage-plan.sh"
source "$ROOT/lib/storage-prerequisites.sh"

preflight::check_commands() {
  [[ ${K41_TEST_TOOLS_FAIL:-0} == 0 ]]
}
preflight::detect_boot_mode() {
  [[ ${K41_TEST_UEFI_FAIL:-0} == 0 ]]
}
storage::discover_candidates() {
  local -n out="$1"
  [[ ${K41_TEST_DISCOVERY_FAIL:-0} == 0 ]] || return 1
  out[candidate_count]=1
  out[0.device_path]=/dev/nvme0n1
  out[0.major_minor]=259:0
  out[0.size_bytes]=274877906944
  out[0.transport]=nvme
  out[0.removable]=false
  out[0.read_only]=false
  out[0.stable_id_kind]=wwn
  out[0.stable_id]=eui.0011223344556677
  out[0.wwn]=eui.0011223344556677
  out[0.serial]=SN-X280
  out[0.model]="WDC PC SN730"
  out[0.has_mounted_descendant]=no
  out[0.has_active_swap_descendant]=no
}
storage::validate_target() {
  local -n target="$1"
  [[ ${K41_TEST_TOPOLOGY_FAIL:-0} == 0 ]] || return 1
  [[ ${target[device_path]} == /dev/nvme0n1 ]]
  [[ ${target[major_minor]} == 259:0 ]]
  [[ ${target[stable_id]} == eui.0011223344556677 ]]
}

make_plan() {
  local -n plan="$1"
  local -A target=(
    [device_path]=/dev/nvme0n1 [major_minor]=259:0
    [size_bytes]=274877906944 [transport]=nvme
    [removable]=false [read_only]=false
    [stable_id_kind]=wwn [stable_id]=eui.0011223344556677
    [wwn]=eui.0011223344556677 [serial]=SN-X280 [model]="WDC PC SN730"
  )
  storage::plan_gpt_layout plan 274877906944 512 4096 8589934592 1073741824
  storage::plan_bind_target plan target
}

declare -A plan=() live_target=() prereq=()
make_plan plan
storage::plan_collect_live_prerequisites plan live_target prereq
storage::plan_validate plan
[[ ${prereq[boot_mode]} == uefi ]]
[[ ${prereq[required_tools]} == passed ]]
[[ ${prereq[topology]} == passed ]]
[[ ${prereq[target_unused]} == passed ]]
[[ ${prereq[target_identity]} == passed ]]
[[ ${prereq[evidence_id]} == live-* ]]
[[ ${plan[prereq_evidence_id]} == "${prereq[evidence_id]}" ]]
[[ ${live_target[major_minor]} == 259:0 ]]
echo 'PASS: live UEFI, tool, target identity, unused-state, and topology evidence is bound to the plan'

for failure in tools uefi discovery topology; do
  declare -A failed_plan=() failed_target=() failed_prereq=()
  make_plan failed_plan
  case $failure in
    tools) export K41_TEST_TOOLS_FAIL=1 ;;
    uefi) export K41_TEST_UEFI_FAIL=1 ;;
    discovery) export K41_TEST_DISCOVERY_FAIL=1 ;;
    topology) export K41_TEST_TOPOLOGY_FAIL=1 ;;
  esac
  if storage::plan_collect_live_prerequisites failed_plan failed_target failed_prereq; then
    echo "FAIL: $failure failure accepted" >&2; exit 1
  fi
  [[ ! -v failed_plan[prereq_evidence_id] ]]
  unset K41_TEST_TOOLS_FAIL K41_TEST_UEFI_FAIL K41_TEST_DISCOVERY_FAIL K41_TEST_TOPOLOGY_FAIL
done
echo 'PASS: failed live checks never produce a passed prerequisite snapshot'

declare -A changed_plan=() changed_target=() changed_prereq=()
make_plan changed_plan
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
  out[0.stable_id]=DIFFERENT-WWN
  out[0.wwn]=DIFFERENT-WWN
  out[0.serial]=SN-X280
  out[0.model]="WDC PC SN730"
  out[0.has_mounted_descendant]=no
  out[0.has_active_swap_descendant]=no
}
if storage::plan_collect_live_prerequisites changed_plan changed_target changed_prereq; then
  echo 'FAIL: changed stable identity accepted' >&2; exit 1
fi
echo 'PASS: changed stable identity cannot bind live prerequisites'
