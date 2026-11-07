#!/usr/bin/env bash
# Read-only live validation for the known ThinkPad X280 internal NVMe SSD.
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"

EXPECTED_MODEL='WDC PC SN730'
EXPECTED_SERIAL='193839803177'

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

for cmd in bash lsblk jq swapon base64 readlink stat; do
  command -v "$cmd" >/dev/null 2>&1 || fail "missing required command: $cmd"
done

[[ -d /sys/firmware/efi ]] || fail 'system is not booted in UEFI mode'

# shellcheck source=../lib/storage.sh
source "$ROOT/lib/storage.sh"

declare -A disks=()
storage::discover_candidates disks || fail 'storage discovery failed'

printf 'Discovered whole disks: %s\n' "${disks[candidate_count]}"
matches=0
selected=-1

for ((i=0; i<disks[candidate_count]; i++)); do
  printf '\n[%s] %s | %s | %s bytes | %s | serial=%s | removable=%s | read-only=%s | mounted=%s | swap=%s\n' \
    "$i" "${disks[$i.device_path]}" "${disks[$i.model]}" \
    "${disks[$i.size_bytes]}" "${disks[$i.transport]}" \
    "${disks[$i.serial]}" "${disks[$i.removable]}" \
    "${disks[$i.read_only]}" "${disks[$i.has_mounted_descendant]}" \
    "${disks[$i.has_active_swap_descendant]}"
  if [[ "${disks[$i.model]}" == *"$EXPECTED_MODEL"* && \
        "${disks[$i.serial]}" == "$EXPECTED_SERIAL" ]]; then
    ((matches += 1))
    selected=$i
  fi
done

(( matches == 1 )) || fail "expected exactly one $EXPECTED_MODEL SSD with serial $EXPECTED_SERIAL; found $matches"

declare -A target=(
  [device_path]="${disks[$selected.device_path]}"
  [size_bytes]="${disks[$selected.size_bytes]}"
  [major_minor]="${disks[$selected.major_minor]}"
  [serial]="${disks[$selected.serial]}"
)

printf '\nValidating expected internal SSD: %s\n' "${target[device_path]}"
storage::validate_target target || fail 'target identity or live topology validation failed'

printf '\nPASS: expected SSD identity and read-only topology checks passed.\n'
printf 'No partitioning, formatting, encryption, mounting, or disk writes were performed.\n'
