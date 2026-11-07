#!/usr/bin/env bash
# Run the project's read-only X280 storage validation from an Arch ISO.
# Persistent disks are never used for logs; the report is stored under /run (RAM).
set -Eeuo pipefail
umask 077

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
VALIDATOR="$ROOT/scripts/validate-live-storage.sh"

usage() {
  cat <<'USAGE'
Usage: bash scripts/x280-archiso-test.sh

Run from a checkout of Lenovo-ThinkPad-X280-K41 on the ThinkPad X280
booted into the Arch Linux installation ISO in UEFI mode.

This test:
  - records basic host, firmware, block-device, mount, and swap observations;
  - runs scripts/validate-live-storage.sh against the expected X280 NVMe;
  - stores a private report in /run (the live ISO RAM filesystem).

It does NOT partition, format, encrypt, mount, install packages, change
services/firmware, or write to any block device. Do not interpret PASS as
authorization or readiness to erase/install to the SSD.
USAGE
}

if [[ ${1-} == --help || ${1-} == -h ]]; then
  usage
  exit 0
fi
[[ $# -eq 0 ]] || { usage >&2; exit 2; }

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

[[ -f "$VALIDATOR" ]] || fail "validator not found: $VALIDATOR"
[[ -d /run/archiso ]] || fail 'Arch ISO runtime marker /run/archiso not found; boot the official Arch Linux ISO first'
[[ -d /sys/firmware/efi ]] || fail 'UEFI boot required; reboot the ISO in UEFI mode'
[[ -r /sys/class/dmi/id/sys_vendor && -r /sys/class/dmi/id/product_name ]] ||
  fail 'DMI product identity is unavailable'

vendor="$(< /sys/class/dmi/id/sys_vendor)"
product="$(< /sys/class/dmi/id/product_name)"
product_version=''
if [[ -r /sys/class/dmi/id/product_version ]]; then
  product_version="$(< /sys/class/dmi/id/product_version)"
fi
[[ "$vendor" == *Lenovo* ]] || fail "unexpected system vendor: $vendor"
# Lenovo firmware may expose the MTM (for example, 20KESC2Y00) as
# product_name and the marketing model as product_version.
[[ "$product $product_version" == *"ThinkPad X280"* ]] ||
  fail "expected ThinkPad X280 DMI identity; detected product_name='$product', product_version='$product_version'"

for cmd in bash date lsblk findmnt swapon; do
  command -v "$cmd" >/dev/null 2>&1 || fail "missing required command: $cmd"
done

# The underlying project validator additionally requires jq, base64, readlink,
# and stat. Fail before producing a partial test report if any are unavailable.
for cmd in jq base64 readlink stat; do
  command -v "$cmd" >/dev/null 2>&1 || fail "missing required command: $cmd (no packages will be installed automatically)"
done

timestamp="$(date -u +'%Y%m%dT%H%M%SZ')"
report="/run/x280-archiso-storage-test-$timestamp.log"
[[ ! -e "$report" ]] || fail "report already exists: $report"
: > "$report"
chmod 600 "$report"

exec > >(tee -a "$report") 2>&1

printf '%s\n' 'ThinkPad X280 — Arch ISO read-only storage test'
printf 'Started (UTC): %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
printf 'Repository: %s\n' "$ROOT"
printf 'Vendor: %s\nProduct name: %s\nProduct version: %s\n' "$vendor" "$product" "$product_version"
printf 'Kernel: %s\n' "$(uname -srmo)"
printf 'UEFI: yes\n'
printf '\n%s\n' '--- Block devices (read-only inventory) ---'
lsblk --bytes --paths --output NAME,MAJ:MIN,TYPE,SIZE,MODEL,TRAN,WWN,SERIAL,RM,RO,FSTYPE,MOUNTPOINTS
printf '\n%s\n' '--- Mounts ---'
findmnt
printf '\n%s\n' '--- Active swap ---'
swapon --show

printf '\n%s\n' '--- Project live storage validator ---'
if bash "$VALIDATOR"; then
  result=PASS
else
  rc=$?
  result=FAIL
  printf 'Validator exit code: %s\n' "$rc"
  printf '\nResult: %s\n' "$result"
  printf 'Report (RAM only): %s\n' "$report"
  exit "$rc"
fi

printf '\nResult: %s\n' "$result"
printf 'Finished (UTC): %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
printf 'Report (RAM only): %s\n' "$report"
printf '%s\n' 'No disk-writing operation was requested or performed by this test script.'
