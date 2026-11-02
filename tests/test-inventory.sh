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
printf '%s\n' '20KESC2Y00' > "$tmp/sys/class/dmi/id/product_name"
printf '%s\n' 'ThinkPad X280' > "$tmp/sys/class/dmi/id/product_version"
printf '%s\n' 'N20ET49W (1.34)' > "$tmp/sys/class/dmi/id/bios_version"
declare -A facts=()
inventory::collect_host facts "$tmp/proc" "$tmp/sys"
[[ "${facts[cpu.model]}" == 'Intel(R) Core(TM) i5-8250U' ]]
[[ "${facts[cpu.threads]}" == 2 ]]
[[ "${facts[memory.total_bytes]}" == 8375185408 ]]
[[ "${facts[dmi.product_name]}" == '20KESC2Y00' ]]
inventory::validate_required_facts facts
inventory::compare_target_profile facts "$PROFILE" >/dev/null
# Mismatched target identity and missing required facts fail closed.
declare -A wrong_device=([dmi.sys_vendor]='LENOVO' [dmi.product_name]='20KESC2Y10' [cpu.model]='Intel(R) Core(TM) i5-8250U' [memory.total_bytes]=8375185408)
if inventory::compare_target_profile wrong_device "$PROFILE" >/dev/null 2>&1; then exit 1; fi
declare -A missing_facts=([dmi.product_name]='20KESC2Y00')
if inventory::compare_target_profile missing_facts "$PROFILE" >/dev/null 2>&1; then exit 1; fi
declare -A wrong_vendor=([dmi.sys_vendor]='DELL' [dmi.product_name]='20KESC2Y00' [cpu.model]='Intel(R) Core(TM) i5-8250U' [memory.total_bytes]=8375185408)
if inventory::compare_target_profile wrong_vendor "$PROFILE" >/dev/null 2>&1; then exit 1; fi
declare -A incomplete=([cpu.model]='Intel(R) Core(TM) i5-8250U' [memory.total_bytes]=8375185408 [dmi.product_name]='20KESC2Y00')
if inventory::validate_required_facts incomplete >/dev/null 2>&1; then exit 1; fi
declare -A bad_memory=([cpu.model]='Intel(R) Core(TM) i5-8250U' [memory.total_bytes]='8GiB' [dmi.sys_vendor]='LENOVO' [dmi.product_name]='20KESC2Y00')
if inventory::validate_required_facts bad_memory >/dev/null 2>&1; then exit 1; fi
printf '%s\n' 'processor : 0' 'model name : CPU A' 'processor : 1' 'model name : CPU B' > "$tmp/proc/cpuinfo"
declare -A cpu_conflict=()
inventory::collect_host cpu_conflict "$tmp/proc" "$tmp/sys"
[[ -n ${cpu_conflict[cpu.model_conflict]+x} ]]
if inventory::validate_required_facts cpu_conflict >/dev/null 2>&1; then exit 1; fi

# Malformed profile content is rejected without executing shell syntax.
cat > "$tmp/malicious.conf" <<EOF_BAD
K41_TARGET_VENDOR='LENOVO'
K41_TARGET_PRODUCT_NAME=\$(touch "$tmp/should-not-exist")
K41_TARGET_CPU_MODEL_LINUX='Intel(R) Core(TM) i5-8250U'
K41_TARGET_MEMORY_MIN_BYTES='7516192768'
K41_TARGET_MEMORY_MAX_BYTES='9663676416'
EOF_BAD
if inventory::compare_target_profile facts "$tmp/malicious.conf" >/dev/null 2>&1; then exit 1; fi
[[ ! -e "$tmp/should-not-exist" ]]
cp "$PROFILE" "$tmp/duplicate.conf"
printf "%s\n" "K41_TARGET_PRODUCT_NAME='20KESC2Y00'" >> "$tmp/duplicate.conf"
if inventory::compare_target_profile facts "$tmp/duplicate.conf" >/dev/null 2>&1; then exit 1; fi
declare -Ar readonly_facts=([dmi.product_name]='20KESC2Y00')
if inventory::collect_host readonly_facts "$tmp/proc" "$tmp/sys"; then exit 1; else [[ $? -eq 2 ]]; fi
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
