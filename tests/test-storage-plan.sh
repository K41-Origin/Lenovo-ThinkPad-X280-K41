#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
source "$ROOT/tests/helpers/storage-fixtures.sh"
source "$ROOT/lib/storage-plan.sh"

declare -A plan=()
storage::plan_gpt_layout plan 274877906944 512 4096 8589934592 1073741824
[[ ${plan[status]} == calculated ]]
[[ ${plan[esp_size_bytes]} == 1073741824 ]]
[[ $((plan[esp_start_sector] % 2048)) == 0 ]]
[[ $((plan[root_start_sector] % 2048)) == 0 ]]
[[ ${plan[swapfile_target_bytes]} == 9663676416 ]]
(( plan[root_end_sector] < plan[total_sectors] - 33 ))
echo 'PASS: calculates aligned GPT layout and RAM-plus-margin swap proposal'

declare -A plan_4k=()
storage::plan_gpt_layout plan_4k 274877906944 4096 4096 8589934592 1073741824
[[ ${plan_4k[esp_size_bytes]} == 1073741824 ]]
[[ $((plan_4k[esp_start_sector] % 256)) == 0 ]]
[[ $((plan_4k[root_start_sector] % 256)) == 0 ]]
echo 'PASS: supports 4Kn logical sectors with 1 MiB alignment'

declare -A too_small=()
if storage::plan_gpt_layout too_small 34359738368 512 4096 8589934592 1073741824; then
  echo 'FAIL: insufficient root/headroom accepted' >&2; exit 1
fi
echo 'PASS: rejects insufficient capacity'

declare -A invalid=()
if storage::plan_gpt_layout invalid 274877906944 1000 4096 8589934592 1073741824; then
  echo 'FAIL: invalid logical sector size accepted' >&2; exit 1
fi
echo 'PASS: rejects unsupported logical sector geometry'

declare -A misaligned=()
if storage::plan_gpt_layout misaligned 274877906943 512 4096 8589934592 1073741824; then
  echo 'FAIL: non-sector-aligned disk capacity accepted' >&2; exit 1
fi
echo 'PASS: rejects capacity not divisible by logical sector size'

declare -A overflow=()
if storage::plan_gpt_layout overflow 9223372036854775808 512 4096 8589934592 1073741824; then
  echo 'FAIL: out-of-range disk size accepted' >&2; exit 1
fi
echo 'PASS: rejects arithmetic input outside signed 64-bit range'

# Public planner output validation must fail cleanly before nameref creation.
if storage::plan_gpt_layout 'bad-name' 274877906944 512 4096 8589934592 1073741824; then
  echo 'FAIL: malformed output variable name accepted' >&2; exit 1
fi
if storage::plan_gpt_layout missing_plan 274877906944 512 4096 8589934592 1073741824; then
  echo 'FAIL: missing output variable accepted' >&2; exit 1
fi
declare -a indexed_plan=()
if storage::plan_gpt_layout indexed_plan 274877906944 512 4096 8589934592 1073741824; then
  echo 'FAIL: indexed output array accepted' >&2; exit 1
fi
declare -Ar readonly_plan=()
if storage::plan_gpt_layout readonly_plan 274877906944 512 4096 8589934592 1073741824; then
  echo 'FAIL: readonly associative output accepted' >&2; exit 1
fi
echo 'PASS: rejects malformed, missing, indexed, and readonly output variables before nameref creation'

declare -A swap_overflow=()
if storage::plan_gpt_layout swap_overflow 274877906944 512 4096 9223372036854775807 1; then
  echo 'FAIL: swap-size addition overflow accepted' >&2; exit 1
fi
echo 'PASS: rejects swap-size arithmetic overflow'

declare -A leading_zero=()
storage::plan_gpt_layout leading_zero 0274877906944 0512 04096 08589934592 01073741824
[[ ${leading_zero[disk_bytes]} == 274877906944 ]]
[[ ${leading_zero[logical_sector_bytes]} == 512 ]]
echo 'PASS: normalizes decimal inputs with leading zeros without octal interpretation'

# Bind the calculated geometry to a stable target and approved profile.
declare -A target=()
storage_test::make_x280_target target eui.0011223344556677 SERIAL-X280
declare -A bound=()
storage::plan_gpt_layout bound 274877906944 512 4096 8589934592 1073741824
storage::plan_bind_target bound target
[[ ${bound[schema_version]} == 1 ]]
[[ ${bound[target_stable_id]} == eui.0011223344556677 ]]
[[ ${bound[target_removable]} == false && ${bound[target_read_only]} == false ]]
[[ ${bound[profile_root_encryption]} == luks2 ]]
[[ ${bound[profile_root_type_guid]} == ca7d7ccb-63ed-4c53-861c-1742536059cc ]]
[[ ${bound[profile_root_filesystem]} == ext4 ]]
[[ ${bound[profile_esp_mountpoint]} == /efi ]]
[[ ${bound[profile_uki_path]} == /efi/EFI/Linux/arch-linux.efi ]]
serialized_a=$(storage::plan_serialize bound)
serialized_b=$(storage::plan_serialize bound)
[[ $serialized_a == "$serialized_b" ]]
[[ $serialized_a == "$(printf '%s' "$serialized_a" | LC_ALL=C sort)" ]]
digest_a=$(storage::plan_digest bound)
digest_b=$(storage::plan_digest bound)
[[ $digest_a == "$digest_b" && $digest_a =~ ^[a-f0-9]{64}$ ]]
echo 'PASS: binds target/profile and produces deterministic serialization and digest'

declare -A changed=()
for key in "${!bound[@]}"; do changed["$key"]=${bound[$key]}; done
changed[target_stable_id]=different-disk
[[ $(storage::plan_digest changed) != "$digest_a" ]]
changed[target_stable_id]=${bound[target_stable_id]}
changed[profile_resume_policy]=different-policy
[[ $(storage::plan_digest changed) != "$digest_a" ]]
echo 'PASS: target identity and profile changes alter the plan digest'

declare -A invalid_target=()
for key in "${!target[@]}"; do invalid_target["$key"]=${target[$key]}; done
invalid_target[stable_id]=
declare -A rejected=()
storage::plan_gpt_layout rejected 274877906944 512 4096 8589934592 1073741824
if storage::plan_bind_target rejected invalid_target; then
  echo 'FAIL: target without stable identity accepted' >&2; exit 1
fi
echo 'PASS: refuses target without stable identity'

declare -A malformed=([safe]=value [unsafe]=$'line1\nline2')
if storage::plan_serialize malformed >/dev/null; then
  echo 'FAIL: multiline plan value accepted' >&2; exit 1
fi
echo 'PASS: rejects ambiguous multiline serialization values'

# A plan is incomplete until the caller binds a successful prerequisite snapshot.
declare -A prerequisites=(
  [boot_mode]=uefi [required_tools]=passed [topology]=passed
  [target_unused]=passed [target_identity]=passed [evidence_id]=fixture-snapshot-001
)
storage::plan_bind_prerequisites bound prerequisites
storage::plan_validate bound
echo 'PASS: accepts complete geometry, target, profile, and prerequisite state'

declare -A changed_prereq=()
for key in "${!bound[@]}"; do changed_prereq["$key"]=${bound[$key]}; done
changed_prereq[prereq_topology]=failed
if storage::plan_validate changed_prereq; then
  echo 'FAIL: failed topology prerequisite accepted' >&2; exit 1
fi
changed_prereq[prereq_topology]=passed
changed_prereq[profile_root_filesystem]=btrfs
if storage::plan_validate changed_prereq; then
  echo 'FAIL: unsupported root filesystem profile accepted' >&2; exit 1
fi
changed_prereq[profile_root_filesystem]=ext4
changed_prereq[esp_end_sector]=$((changed_prereq[esp_end_sector] - 1))
if storage::plan_validate changed_prereq; then
  echo 'FAIL: inconsistent ESP geometry accepted' >&2; exit 1
fi
echo 'PASS: rejects failed prerequisites and inconsistent profile/partition geometry'

declare -A missing_prerequisite=([boot_mode]=uefi [required_tools]=passed [topology]=passed [target_unused]=passed [target_identity]=passed)
declare -A no_prereq_plan=()
storage::plan_gpt_layout no_prereq_plan 274877906944 512 4096 8589934592 1073741824
storage::plan_bind_target no_prereq_plan target
if storage::plan_bind_prerequisites no_prereq_plan missing_prerequisite; then
  echo 'FAIL: prerequisite snapshot without evidence ID accepted' >&2; exit 1
fi
if storage::plan_validate no_prereq_plan; then
  echo 'FAIL: plan without prerequisite state accepted' >&2; exit 1
fi
echo 'PASS: refuses missing prerequisite evidence and incomplete plans'

declare -A invalid_prerequisite=(
  [boot_mode]=legacy [required_tools]=passed [topology]=passed
  [target_unused]=passed [target_identity]=passed [evidence_id]=fixture-snapshot-002
)
if storage::plan_bind_prerequisites no_prereq_plan invalid_prerequisite; then
  echo 'FAIL: non-UEFI prerequisite state accepted' >&2; exit 1
fi
echo 'PASS: refuses non-UEFI prerequisite state'

digest_with_prerequisites=$(storage::plan_digest bound)
declare -A prereq_digest_variant=()
for key in "${!bound[@]}"; do prereq_digest_variant["$key"]=${bound[$key]}; done
prereq_digest_variant[prereq_evidence_id]=different-snapshot
[[ $(storage::plan_digest prereq_digest_variant) != "$digest_with_prerequisites" ]]
echo 'PASS: prerequisite evidence changes alter the canonical plan digest'

declare -A noncanonical_numeric=()
for key in "${!bound[@]}"; do noncanonical_numeric["$key"]=${bound[$key]}; done
noncanonical_numeric[esp_start_sector]=0${noncanonical_numeric[esp_start_sector]}
if storage::plan_validate noncanonical_numeric; then
  echo 'FAIL: non-canonical decimal geometry accepted' >&2; exit 1
fi
echo 'PASS: rejects non-canonical numeric fields before arithmetic evaluation'
declare -A wrong_esp_profile=()
for key in "${!bound[@]}"; do wrong_esp_profile["$key"]=${bound[$key]}; done
wrong_esp_profile[profile_esp_size_bytes]=536870912
if storage::plan_validate wrong_esp_profile; then
  echo 'FAIL: ESP profile size inconsistent with partition geometry accepted' >&2; exit 1
fi
echo 'PASS: rejects ESP profile size inconsistent with planned partition geometry'
