#!/usr/bin/env bash
# Canonical K41 live validation. Read-only; no disk, service, package, or firmware changes.
set -Eeuo pipefail
umask 077

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
cd "$ROOT"

usage() {
  cat <<'USAGE'
Usage: bash stages/stage-1-live-readiness/scripts/k41-live-validation.sh [--readiness|--diagnostics-only]

  --readiness        Strict Arch ISO / ThinkPad X280 readiness gate (default).
  --diagnostics-only Broad read-only diagnostics for any checked-out host.

Both modes run repository syntax checks, available static analysis, and the
canonical test suite. Readiness mode additionally checks root, Arch ISO,
UEFI, X280 DMI identity, required tools, and target SSD identity/topology.
No mode partitions, formats, opens LUKS, mounts, installs packages, or writes
to the selected installation target. Reports are written under the repository checkout.
USAGE
}

mode=readiness
case "${1-}" in
"") ;;
--readiness) mode=readiness ;;
--diagnostics-only) mode=diagnostics ;;
-h | --help)
  usage
  exit 0
  ;;
*)
  usage >&2
  exit 2
  ;;
esac
[[ $# -le 1 ]] || {
  usage >&2
  exit 2
}

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  printf 'ERROR: repository checkout not found: %s\n' "$ROOT" >&2
  exit 2
fi

# On a real Arch ISO, keep report writes on the live overlay/RAM filesystem.
# Refuse to create reports if the checkout resolves to a persistent filesystem.
if [[ "$mode" == readiness && -d /run/archiso ]]; then
  if ! command -v findmnt >/dev/null 2>&1; then
    printf 'ERROR: findmnt is required to verify that repository reports stay off persistent disks.\n' >&2
    exit 2
  fi
  report_fs="$(findmnt -T "$ROOT" -n -o FSTYPE 2>/dev/null)" || {
    printf 'ERROR: cannot determine the repository filesystem; refusing to write reports.\n' >&2
    exit 2
  }
  case "$report_fs" in
  overlay | tmpfs) ;;
  *)
    printf 'ERROR: repository checkout is on filesystem %s; move it to the Arch ISO live filesystem before running readiness.\n' "$report_fs" >&2
    exit 2
    ;;
  esac
fi

timestamp="$(date -u +'%Y%m%dT%H%M%SZ')"
started="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
branch="$(git branch --show-current 2>/dev/null || printf unknown)"
commit="$(git rev-parse HEAD 2>/dev/null || printf unknown)"
if [[ -z "$(git status --porcelain)" ]]; then
  working_tree='clean before report generation'
else
  working_tree='modified before report generation'
fi

make_report_dir() {
  local root="$1"
  local candidate="$root/$timestamp" suffix=0
  mkdir -p -- "$root"
  while ! mkdir -- "$candidate" 2>/dev/null; do
    suffix=$((suffix + 1))
    candidate="$root/$timestamp-$suffix"
  done
  printf '%s\n' "$candidate"
}

readiness_dir="$(make_report_dir "$ROOT/reports/live-readiness")"
live_root="$ROOT/reports/live-validation"
mkdir -p -- "$live_root"
live_stamp="$timestamp"
live_report="$live_root/$live_stamp.md"
suffix=0
while [[ -e "$live_report" ]]; do
  suffix=$((suffix + 1))
  live_stamp="$timestamp-$suffix"
  live_report="$live_root/$live_stamp.md"
done
summary="$readiness_dir/summary.md"
diagnostics="$readiness_dir/diagnostics.log"
latest="$live_root/latest.md"
rows="$readiness_dir/.check-rows"
: >"$summary"
: >"$diagnostics"
: >"$live_report"
: >"$rows"
chmod 600 "$summary" "$diagnostics" "$live_report"

checks=0
checks_passed=0
checks_failed=0
skips=0
finalized=0
declare -a shell_files=()

record_check() {
  local name="$1" status="$2" rc="$3"
  printf '| %s | **%s** | %s |\n' "$name" "$status" "$rc" >>"$rows"
  checks=$((checks + 1))
  if [[ "$status" == PASS ]]; then
    checks_passed=$((checks_passed + 1))
  else
    checks_failed=$((checks_failed + 1))
  fi
}

run_check() {
  local name="$1"
  shift
  local raw="$readiness_dir/.check-output" rc=0
  printf '\n== %s ==\n' "$name" >>"$live_report"
  if "$@" >"$raw" 2>&1; then
    record_check "$name" PASS 0
    printf 'PASS: %s\n' "$name"
    printf 'PASS\n' >>"$live_report"
  else
    rc=$?
    record_check "$name" FAIL "$rc"
    printf 'FAIL: %s (exit %s)\n' "$name" "$rc"
    printf 'FAIL (exit %s)\n' "$rc" >>"$live_report"
  fi
  # Keep the shareable readiness diagnostics private and redact disk serials.
  sed -E 's/(serial[[:space:]]*=?[[:space:]]*)[^[:space:]]+/\1[REDACTED]/Ig' "$raw" >>"$diagnostics"
  # Preserve the original broad diagnostic detail in the local live report.
  cat -- "$raw" >>"$live_report"
  rm -f -- "$raw"
  return 0
}

capture_optional() {
  local label="$1" binary="$2"
  shift 2
  if command -v "$binary" >/dev/null 2>&1; then
    run_check "$label" "$@"
  else
    skips=$((skips + 1))
    printf -- '- **%s** — SKIPPED (missing command: %s)\n' "$label" "$binary" >>"$live_report"
    printf 'SKIPPED: %s (missing %s)\n' "$label" "$binary"
  fi
}

check_root() {
  ((EUID == 0)) || {
    printf 'Run as root from the official Arch ISO.\n'
    return 1
  }
  printf 'Effective UID: %s\n' "$EUID"
}
check_arch() {
  [[ -f /etc/arch-release ]] || {
    printf 'Not an Arch Linux environment.\n'
    return 1
  }
  [[ -d /run/archiso ]] || {
    printf 'Arch ISO runtime marker /run/archiso not found. Boot the official Arch Linux ISO.\n'
    return 1
  }
  printf 'Arch Linux release and live ISO runtime markers found.\n'
}
check_uefi() {
  [[ -d /sys/firmware/efi ]] || {
    printf 'Boot the Arch ISO in UEFI mode.\n'
    return 1
  }
  printf 'UEFI runtime detected.\n'
}
check_x280_dmi() {
  local vendor product version=''
  [[ -r /sys/class/dmi/id/sys_vendor && -r /sys/class/dmi/id/product_name ]] || {
    printf 'DMI vendor/product identity is unavailable.\n'
    return 1
  }
  vendor="$(</sys/class/dmi/id/sys_vendor)"
  product="$(</sys/class/dmi/id/product_name)"
  [[ ! -r /sys/class/dmi/id/product_version ]] || version="$(</sys/class/dmi/id/product_version)"
  [[ "${vendor,,}" == *lenovo* ]] || {
    printf 'Unexpected system vendor: %s\n' "$vendor"
    return 1
  }
  [[ "$product $version" == *'ThinkPad X280'* ]] || {
    printf "Expected ThinkPad X280; detected product_name='%s', product_version='%s'.\n" "$product" "$version"
    return 1
  }
  printf 'Vendor: %s\nProduct: %s\nProduct version: %s\n' "$vendor" "$product" "$version"
}
check_commands() {
  local missing=() cmd
  for cmd in bash git find lsblk jq swapon base64 readlink stat python3; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
  done
  (("${#missing[@]}" == 0)) || {
    printf 'Missing required commands: %s\n' "${missing[*]}"
    return 1
  }
  printf 'All readiness dependencies are available.\n'
}
check_syntax() {
  mapfile -d '' shell_files < <(find . -type f \( -name '*.sh' -o -name installer \) -not -path './.git/*' -print0)
  (("${#shell_files[@]}" > 0)) || {
    printf 'No shell scripts found.\n'
    return 1
  }
  local file
  for file in "${shell_files[@]}"; do
    bash -n "$file" || return 1
  done
  printf '%s shell files passed bash -n.\n' "${#shell_files[@]}"
}
check_shfmt() {
  shfmt -d -i 2 stages/stage-1-live-readiness/scripts/k41-live-validation.sh stages/stage-1-live-readiness/scripts/live-validation.sh \
    stages/stage-1-live-readiness/scripts/x280-install-readiness.sh stages/stage-1-live-readiness/scripts/x280-archiso-test.sh tests/run.sh tests/helpers/storage-fixtures.sh
}
finalize_report() {
  local rc="$1" result finished
  ((finalized == 0)) || return 0
  finalized=1
  finished="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  if ((rc == 0 && checks_failed == 0)); then result=PASS; else result=FAIL; fi

  {
    printf '# K41 live validation readiness report\n\n'
    printf -- '- Mode: %s\n' "$mode"
    printf -- '- Result: **%s**\n' "$result"
    printf -- '- Started (UTC): %s\n' "$started"
    printf -- '- Finished (UTC): %s\n' "$finished"
    printf -- '- Repository: Lenovo-ThinkPad-X280-K41\n'
    printf -- '- Branch: %s\n' "$branch"
    printf -- '- Commit: %s\n' "$commit"
    printf -- '- Working tree before report generation: %s\n' "$working_tree"
    printf -- '- Kernel: %s\n' "$(uname -sr 2>/dev/null || printf unknown)"
    printf -- '- Architecture: %s\n' "$(uname -m 2>/dev/null || printf unknown)"
    printf -- '- Checks passed: %s\n' "$checks_passed"
    printf -- '- Checks failed: %s\n' "$checks_failed"
    printf -- '- Optional diagnostics skipped: %s\n' "$skips"
    printf -- '- Process exit code: %s\n' "$rc"
    printf '\n## Check results\n\n'
    printf '| Check | Result | Exit |\n|---|---:|---:|\n'
    cat -- "$rows"
    printf '\n## Evidence files\n\n'
    printf -- '- `summary.md`: result, checkout identity, environment, and check table\n'
    printf -- '- `diagnostics.log`: captured command output with serial values redacted\n'
    printf -- '- `../../live-validation/%s.md`: broad host, storage, network, and repository diagnostics\n' "$live_stamp"
    printf '\n## Safety boundary\n\n'
    printf 'This is read-only validation. PASS applies only to the recorded checkout and host snapshot. It does not prove a successful installation or authorize disk erasure. No partitioning, formatting, LUKS opening, mounting, package installation, service changes, firmware changes, or writes to the selected installation target are performed. Reports are written under the repository checkout. Review reports before sharing.\n'
  } >"$summary"
  {
    printf '\n## Result summary\n\n'
    printf -- '- Checks counted: %s\n' "$checks"
    printf -- '- Failures: %s\n' "$checks_failed"
    printf -- '- Optional diagnostics skipped: %s\n' "$skips"
    if ((checks_failed == 0 && rc == 0)); then
      printf -- '- Overall repository validation: PASS (within checks available on this host)\n'
    else
      printf -- '- Overall repository validation: FAIL\n'
    fi
    printf '\nThis report is evidence for this exact checkout and host at the recorded time. It is not proof of successful installation, safe disk erasure, or untested hardware behavior. Review hardware and network metadata before sharing.\n'
  } >>"$live_report"
  cp -- "$live_report" "$latest"
  rm -f -- "$rows" "$readiness_dir/.check-output"
  chmod 600 "$summary" "$diagnostics" "$live_report" "$latest"
  printf '\nReadiness summary: %s\nRedacted diagnostics: %s\nLive report: %s\nLatest report: %s\nResult: %s\n' \
    "$summary" "$diagnostics" "$live_report" "$latest" "$result"
}

on_exit() {
  local rc=$?
  finalize_report "$rc"
}
trap on_exit EXIT

{
  printf '# K41 live validation diagnostics\n\n'
  printf -- '- Generated (UTC): %s\n' "$started"
  printf -- '- Repository: %s\n' "$ROOT"
  printf -- '- Host: %s\n' "$(hostname 2>/dev/null || printf unknown)"
  printf -- '- Kernel: %s\n' "$(uname -srmo 2>/dev/null || printf unknown)"
  printf -- '- Branch: %s\n' "$branch"
  printf -- '- Commit: %s\n' "$commit"
  printf '\n> Read-only diagnostics and repository tests. This report may contain hardware identifiers and network metadata; review before sharing.\n'
} >>"$live_report"

printf 'K41 live validation mode: %s\n' "$mode"
run_check "Git repository status" git status --short --branch
run_check "Current commit" git rev-parse HEAD
run_check "Current branch" git branch --show-current
run_check "Tracked file inventory" git ls-files
run_check "Working-tree diff summary" git diff --stat
run_check "Untracked file inventory" git ls-files --others --exclude-standard

if [[ "$mode" == readiness ]]; then
  run_check "Root privileges" check_root
  run_check "Arch Linux live environment" check_arch
  run_check "UEFI boot mode" check_uefi
  run_check "ThinkPad X280 DMI identity" check_x280_dmi
  run_check "Required command availability" check_commands
fi

run_check "Kernel" uname -a
capture_optional "CPU inventory" lscpu lscpu
capture_optional "Memory inventory" free free -h
capture_optional "UEFI firmware indicator" test test -d /sys/firmware/efi
capture_optional "DMI vendor" cat cat /sys/class/dmi/id/sys_vendor
capture_optional "DMI product" cat cat /sys/class/dmi/id/product_name
capture_optional "DMI product version" cat cat /sys/class/dmi/id/product_version
capture_optional "BIOS version" cat cat /sys/class/dmi/id/bios_version
capture_optional "PCI inventory" lspci lspci -nn
capture_optional "USB inventory" lsusb lsusb
capture_optional "Block-device inventory" lsblk lsblk -e7 -o NAME,PATH,TYPE,SIZE,MODEL,TRAN,RM,RO,FSTYPE,MOUNTPOINTS
capture_optional "Filesystem mounts" findmnt findmnt
capture_optional "Active swap" swapon swapon --show
capture_optional "Kernel block-device inventory" find find /sys/block -maxdepth 1 -mindepth 1 -printf '%f\n'
capture_optional "Network link state" ip ip -brief link
capture_optional "IP addresses" ip ip -brief address

run_check "Repository Bash syntax" check_syntax
if command -v shellcheck >/dev/null 2>&1; then
  run_check "ShellCheck (severity error)" shellcheck --severity=error "${shell_files[@]}"
else
  skips=$((skips + 1))
  printf -- '- **ShellCheck (severity error)** — SKIPPED (missing command: shellcheck)\n' >>"$live_report"
fi
if command -v shfmt >/dev/null 2>&1; then
  run_check "shfmt formatting check" check_shfmt
else
  skips=$((skips + 1))
  printf -- '- **shfmt formatting check** — SKIPPED (missing command: shfmt)\n' >>"$live_report"
fi
run_check "Canonical repository test suite" bash tests/run.sh

if [[ "$mode" == readiness ]]; then
  run_check "X280 SSD identity and live topology (read-only)" bash stages/stage-1-live-readiness/scripts/validate-live-storage.sh
fi

run_check "installer --help" ./installer --help
# This legacy preflight is informational: its documented non-zero result while
# installation is disabled must not fail the overall validation.
{
  printf '\n## Installer diagnostics\n\n### installer --preflight (informational)\n\n' >>"$live_report"
  printf 'Expected project behavior: non-zero while installation is disabled. Actual output and exit code follow.\n\n'
  if ./installer --preflight >>"$live_report" 2>&1; then preflight_rc=0; else preflight_rc=$?; fi
  printf '\nPreflight exit code: %s\n' "$preflight_rc" >>"$live_report"
}

if ((checks_failed > 0)); then exit 1; fi
exit 0
