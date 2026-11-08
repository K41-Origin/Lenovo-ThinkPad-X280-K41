#!/usr/bin/env bash
# Supplemental Arch ISO evidence collector; canonical readiness logic lives in
# scripts/k41-live-validation.sh. Detailed inventory and this repository-local
# report are retained for physical-hardware investigation.
set -Eeuo pipefail
umask 077

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
VALIDATOR="$ROOT/scripts/k41-live-validation.sh"

usage() {
  cat <<'USAGE'
Usage: bash scripts/x280-archiso-test.sh

Run from a checkout on the ThinkPad X280 booted into the official Arch ISO.
This supplemental collector records detailed block-device, mount, swap, DMI,
and kernel observations in a private repository report, then delegates all readiness,
DMI identity, dependency, test-suite, and SSD topology checks to
scripts/k41-live-validation.sh.

It does NOT partition, format, encrypt, mount, install packages, change
services/firmware, or write to the selected installation target. The report
is stored under reports/x280-archiso-test/<UTC timestamp>/ inside this checkout.
On the Arch ISO, the checkout must resolve to overlay or tmpfs; otherwise the
collector stops before writing.
USAGE
}

if [[ ${1-} == --help || ${1-} == -h ]]; then
  usage
  exit 0
fi
[[ $# -eq 0 ]] || {
  usage >&2
  exit 2
}

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

[[ -f "$VALIDATOR" ]] || fail "canonical validator not found: $VALIDATOR"
[[ -d /run/archiso ]] || fail 'Arch ISO runtime marker /run/archiso not found; boot the official Arch Linux ISO first'
[[ -r /sys/class/dmi/id/sys_vendor && -r /sys/class/dmi/id/product_name ]] ||
  fail 'DMI identity is unavailable for supplemental evidence'

for cmd in bash date lsblk findmnt swapon tee; do
  command -v "$cmd" >/dev/null 2>&1 || fail "missing required command: $cmd"
done

# Keep every diagnostic artifact inside this checkout. On an Arch ISO,
# refuse to write if the checkout is on a persistent filesystem.
report_fs="$(findmnt -T "$ROOT" -n -o FSTYPE 2>/dev/null)" ||
  fail 'cannot determine repository filesystem; refusing to write the report'
case "$report_fs" in
  overlay | tmpfs) ;;
  *)
    fail "repository checkout is on filesystem $report_fs; move it to the Arch ISO live filesystem first"
    ;;
esac

timestamp="$(date -u +'%Y%m%dT%H%M%SZ')"
report_root="$ROOT/reports/x280-archiso-test"
mkdir -p -- "$report_root"
report_dir="$report_root/$timestamp"
suffix=0
while ! mkdir -- "$report_dir" 2>/dev/null; do
  suffix=$((suffix + 1))
  report_dir="$report_root/$timestamp-$suffix"
done
report="$report_dir/x280-archiso-test.log"
: >"$report"
chmod 600 "$report"
exec > >(tee -a "$report") 2>&1

vendor="$(</sys/class/dmi/id/sys_vendor)"
product="$(</sys/class/dmi/id/product_name)"
product_version=''
if [[ -r /sys/class/dmi/id/product_version ]]; then
  product_version="$(</sys/class/dmi/id/product_version)"
fi

printf '%s\n' 'ThinkPad X280 — supplemental Arch ISO evidence'
printf 'Started (UTC): %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
printf 'Repository: %s\n' "$ROOT"
printf 'Vendor: %s\nProduct name: %s\nProduct version: %s\n' "$vendor" "$product" "$product_version"
printf 'Kernel: %s\n' "$(uname -srmo)"
if [[ -d /sys/firmware/efi ]]; then printf 'UEFI: yes\n'; else printf 'UEFI: no\n'; fi

printf '\n%s\n' '--- Detailed block-device inventory (read-only) ---'
lsblk --bytes --paths --output NAME,MAJ:MIN,TYPE,SIZE,MODEL,TRAN,WWN,SERIAL,RM,RO,FSTYPE,MOUNTPOINTS
printf '\n%s\n' '--- Mounts ---'
findmnt
printf '\n%s\n' '--- Active swap ---'
swapon --show

printf '\n%s\n' '--- Canonical K41 Live Validation ---'
if bash "$VALIDATOR" --readiness; then
  result=PASS
else
  rc=$?
  result=FAIL
  printf 'Canonical validator exit code: %s\n' "$rc"
  printf '\nResult: %s\n' "$result"
  printf 'Supplemental report (repository): %s\n' "$report"
  exit "$rc"
fi

printf '\nResult: %s\n' "$result"
printf 'Finished (UTC): %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
printf 'Supplemental report (repository): %s\n' "$report"
printf '%s\n' 'No disk-writing operation was requested or performed against the installation target.'
