#!/usr/bin/env bash
# Read-only live validation for an Arch ISO / installed host.
# Saves immutable timestamped evidence plus a convenience latest.md report.
set -Eeuo pipefail
umask 077

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  printf 'ERROR: repository checkout not found: %s\n' "$ROOT" >&2
  exit 2
fi

timestamp="$(date -u +'%Y%m%dT%H%M%SZ')"
report_dir="$ROOT/reports/live-validation"
mkdir -p -- "$report_dir"
report="$report_dir/$timestamp.md"
latest="$report_dir/latest.md"

if [[ -e "$report" ]]; then
  printf 'ERROR: refusing to overwrite existing evidence: %s\n' "$report" >&2
  exit 2
fi

failures=0
checks=0
skips=0

{
  printf '# Live validation report\n\n'
  printf -- '- Generated (UTC): %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Repository: %s\n' "$ROOT"
  printf -- '- Host: %s\n' "$(hostname 2>/dev/null || printf unknown)"
  printf -- '- Kernel: %s\n' "$(uname -srmo 2>/dev/null || printf unknown)"
  printf '\n> Read-only diagnostics and repository tests only. This script does not partition, format, mount, install packages, change services, or modify firmware. Review the report before sharing; hardware and network metadata may be environment-specific.\n'
} > "$report"

section() {
  printf '\n## %s\n\n' "$1" >> "$report"
}

capture() {
  local label=$1
  shift
  checks=$((checks + 1))
  printf -- '- **%s** — ' "$label" >> "$report"
  if "$@" >> "$report" 2>&1; then
    printf 'PASS\n' >> "$report"
  else
    local rc=$?
    failures=$((failures + 1))
    printf 'FAIL (exit %s)\n' "$rc" >> "$report"
  fi
}

capture_optional() {
  local label=$1 binary=$2
  shift 2
  if command -v "$binary" >/dev/null 2>&1; then
    capture "$label" "$@"
  else
    skips=$((skips + 1))
    printf -- '- **%s** — SKIPPED (missing command: %s)\n' "$label" "$binary" >> "$report"
  fi
}

section "Repository identity"
capture "Git repository status" git status --short --branch
capture "Current commit" git rev-parse HEAD
capture "Current branch" git branch --show-current
capture "Tracked file inventory" git ls-files
capture "Working-tree diff summary" git diff --stat
capture "Untracked file inventory" git ls-files --others --exclude-standard

section "Host and boot environment"
capture "Kernel" uname -a
capture_optional "CPU inventory" lscpu lscpu
capture_optional "Memory inventory" free free -h
capture_optional "UEFI firmware indicator" test -d /sys/firmware/efi
capture_optional "DMI vendor" cat cat /sys/class/dmi/id/sys_vendor
capture_optional "DMI product" cat cat /sys/class/dmi/id/product_name
capture_optional "DMI product version" cat cat /sys/class/dmi/id/product_version
capture_optional "BIOS version" cat cat /sys/class/dmi/id/bios_version
capture_optional "PCI inventory" lspci lspci -nn
capture_optional "USB inventory" lsusb lsusb

section "Storage and mount topology (read-only)"
capture_optional "Block-device inventory" lsblk lsblk -e7 -o NAME,PATH,TYPE,SIZE,MODEL,TRAN,RM,RO,FSTYPE,MOUNTPOINTS
capture_optional "Filesystem mounts" findmnt findmnt
capture_optional "Active swap" swapon swapon --show
capture_optional "Kernel block-device inventory" find find /sys/block -maxdepth 1 -mindepth 1 -printf '%f\n'

section "Network diagnostics (no connectivity test)"
capture_optional "Network link state" ip ip -brief link
capture_optional "IP addresses" ip ip -brief address

section "Shell syntax validation"
mapfile -d '' shell_files < <(
  find . -type f \( -name '*.sh' -o -name installer \) -not -path './.git/*' -print0
)
if (( ${#shell_files[@]} == 0 )); then
  failures=$((failures + 1))
  checks=$((checks + 1))
  printf -- '- **Bash syntax** — FAIL (no shell files found)\n' >> "$report"
else
  for file in "${shell_files[@]}"; do
    checks=$((checks + 1))
    if bash -n "$file" >> "$report" 2>&1; then
      printf -- '- **bash -n %s** — PASS\n' "$file" >> "$report"
    else
      rc=$?
      failures=$((failures + 1))
      printf -- '- **bash -n %s** — FAIL (exit %s)\n' "$file" "$rc" >> "$report"
    fi
  done
fi

section "Static analysis"
capture_optional "ShellCheck (severity error)" shellcheck shellcheck --severity=error "${shell_files[@]}"
capture_optional "shfmt formatting check (runner and shared fixture helper)" shfmt shfmt -d -i 2 tests/run.sh tests/helpers/storage-fixtures.sh

section "Canonical repository test suite"
capture "bash tests/run.sh" bash tests/run.sh

section "Installer diagnostics"
# --help should succeed. --preflight is intentionally non-zero while installation
# is disabled; record its actual status without treating the documented gate as a test failure.
capture "installer --help" ./installer --help
{
  printf '\n### installer --preflight (informational)\n\n'
  printf 'Expected project behavior: non-zero while installation is disabled. Actual output and exit code follow.\n\n'
  if ./installer --preflight >> "$report" 2>&1; then
    preflight_rc=0
  else
    preflight_rc=$?
  fi
  printf '\nPreflight exit code: %s\n' "$preflight_rc"
} >> "$report"

section "Result summary"
{
  printf -- '- Checks counted: %s\n' "$checks"
  printf -- '- Failures: %s\n' "$failures"
  printf -- '- Optional checks skipped: %s\n' "$skips"
  if (( failures == 0 )); then
    printf -- '- Overall repository validation: PASS (within checks available on this host)\n'
  else
    printf -- '- Overall repository validation: FAIL\n'
  fi
  printf '\nThis report is evidence for this exact checkout and host at the recorded time. It is not proof of successful installation, safe disk erasure, hardware compatibility beyond observed inventory, or correctness of untested behavior.\n'
} >> "$report"

# Keep timestamped reports immutable; latest.md is a convenience pointer-copy.
cp -- "$report" "$latest"
chmod 600 "$report" "$latest"

printf 'Report: %s\n' "$report"
printf 'Latest: %s\n' "$latest"
printf 'Checks: %s | Failures: %s | Optional skips: %s\n' "$checks" "$failures" "$skips"

(( failures == 0 ))
