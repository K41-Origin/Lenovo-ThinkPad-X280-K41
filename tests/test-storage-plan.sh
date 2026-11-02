#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
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
