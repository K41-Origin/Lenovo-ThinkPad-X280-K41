#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=lib/inventory.sh
source "$ROOT/lib/inventory.sh"
# shellcheck source=config/hardware/thinkpad-x280.conf
PROFILE="$ROOT/config/hardware/thinkpad-x280.conf"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/proc" "$tmp/sys/class/dmi/id"
cat > "$tmp/proc/cpuinfo" <<'EOF_CPU'
processor : 0
vendor_id : GenuineIntel
cpu family : 6
model : 142
model name : Intel(R) Core(TM) i5-8250U
processor : 1
model name : Intel(R) Core(TM) i5-8250U
EOF_CPU
cat > "$tmp/proc/meminfo" <<'EOF_MEM'
MemTotal:        8178892 kB
EOF_MEM
printf '%s\n' 'LENOVO' > "$tmp/sys/class/dmi/id/sys_vendor"
printf '%s\n' 'LENOVO 20KESC2Y00' > "$tmp/sys/class/dmi/id/product_name"
printf '%s\n' 'ThinkPad X280' > "$tmp/sys/class/dmi/id/product_version"
printf '%s\n' 'N20ET49W (1.34)' > "$tmp/sys/class/dmi/id/bios_version"
declare -A facts=()
inventory::collect_host facts "$tmp/proc" "$tmp/sys"
[[ "${facts[cpu.model]}" == 'Intel(R) Core(TM) i5-8250U' ]]
[[ "${facts[cpu.cores]}" == 2 ]]
[[ "${facts[memory.total_bytes]}" == 8375185408 ]]
[[ "${facts[dmi.product_name]}" == 'LENOVO 20KESC2Y00' ]]
inventory::compare_target_profile facts "$PROFILE" >/dev/null
# Missing optional fields remain absent; malformed memory is not guessed.
rm "$tmp/proc/meminfo"
printf '%s\n' 'MemTotal: invalid kB' > "$tmp/proc/meminfo"
declare -A partial=()
inventory::collect_host partial "$tmp/proc" "$tmp/sys"
[[ -z ${partial[memory.total_bytes]+x} ]]
# Invalid output variable schemas are rejected.
declare -a indexed=()
if inventory::collect_host indexed "$tmp/proc" "$tmp/sys"; then
  printf '%s\n' 'indexed output array unexpectedly accepted' >&2
  exit 1
else
  [[ $? -eq 2 ]]
fi
if inventory::collect_host missing "$tmp/proc" "$tmp/sys"; then
  printf '%s\n' 'undeclared output variable unexpectedly accepted' >&2
  exit 1
else
  [[ $? -eq 2 ]]
fi
printf '%s\n' 'inventory tests: PASS'
