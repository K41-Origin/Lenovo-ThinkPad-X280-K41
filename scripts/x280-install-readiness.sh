#!/usr/bin/env bash
# Consolidated, non-destructive X280 live-readiness check with shareable evidence.
# This script NEVER partitions, formats, opens LUKS, mounts, or installs Arch.
set -Eeuo pipefail
umask 077

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"

timestamp="$(date -u +'%Y%m%dT%H%M%SZ')"
report_root="$ROOT/reports/live-readiness"
mkdir -p -- "$report_root"
report_dir="$report_root/$timestamp"
suffix=0
while ! mkdir -- "$report_dir" 2>/dev/null; do
  suffix=$((suffix + 1))
  report_dir="$report_root/$timestamp-$suffix"
done
summary="$report_dir/summary.md"
diagnostics="$report_dir/diagnostics.log"
: >"$summary"
: >"$diagnostics"
chmod 600 "$summary" "$diagnostics"

started="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
branch="$(git branch --show-current 2>/dev/null || printf 'unknown')"
commit="$(git rev-parse HEAD 2>/dev/null || printf 'unknown')"
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  if [[ -z "$(git status --porcelain)" ]]; then
    working_tree="clean before report generation"
  else
    working_tree="modified before report generation"
  fi
else
  working_tree="not a Git checkout"
fi

checks_failed=0
checks_passed=0
finalized=0

record_check() {
  local name="$1" status="$2" rc="$3"
  printf '| %s | **%s** | %s |\n' "$name" "$status" "$rc" >>"$summary"
  if [[ "$status" == PASS ]]; then
    checks_passed=$((checks_passed + 1))
  else
    checks_failed=$((checks_failed + 1))
  fi
}

run_check() {
  local name="$1"
  shift
  local raw="$report_dir/.check-output"
  local rc=0
  printf '\n== %s ==\n' "$name"
  if "$@" >"$raw" 2>&1; then
    rc=0
    record_check "$name" PASS 0
    printf 'PASS: %s\n' "$name"
  else
    rc=$?
    record_check "$name" FAIL "$rc"
    printf 'FAIL: %s (exit %s)\n' "$name" "$rc"
  fi
  # Hardware serials are useful for local diagnosis but should not be published
  # in a report that the operator is expected to commit and push.
  sed -E 's/(serial=)[^[:space:]]+/\1[REDACTED]/g' "$raw" >>"$diagnostics"
  rm -f -- "$raw"
  return 0
}

finalize_report() {
  local rc="$1"
  (( finalized == 0 )) || return 0
  finalized=1
  local finished result
  finished="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  if (( rc == 0 && checks_failed == 0 )); then
    result="PASS"
  else
    result="FAIL"
  fi
  {
    printf '# X280 live installation readiness report\n\n'
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
    printf -- '- Process exit code: %s\n' "$rc"
    printf '\n## Check results\n\n'
    printf '| Check | Result | Exit |\n|---|---:|---:|\n'
  } >"$summary.tmp"
  # Check rows are accumulated separately so the report header stays first.
  if [[ -f "$report_dir/.check-rows" ]]; then
    cat "$report_dir/.check-rows" >>"$summary.tmp"
  fi
  {
    printf '\n## Evidence files\n\n'
    printf -- '- `summary.md`: result, checkout identity, environment, and check table\n'
    printf -- '- `diagnostics.log`: captured check output; detected disk serial values are redacted\n'
    printf '\n## Interpretation and safety boundary\n\n'
    printf 'This report records checks for the commit and live environment above. A PASS means only that the listed read-only checks completed successfully. It does not prove a successful installation or first boot and does not authorize disk erasure. The destructive installer is separate and must not be run without reviewing the target identity, current backup, installation plan, and obtaining explicit operator authorization.\n'
    printf '\nReview both files before committing. Do not add unrelated reports or secrets.\n'
  } >>"$summary.tmp"
  mv -- "$summary.tmp" "$summary"
  rm -f -- "$report_dir/.check-rows"
  chmod 600 "$summary" "$diagnostics"
  printf '\nReadiness report: %s\nDiagnostics: %s\nResult: %s\n' "$summary" "$diagnostics" "$result"
}

# Always leave a report, including when a check fails or the script is interrupted.
on_exit() {
  local rc=$?
  finalize_report "$rc"
}
trap on_exit EXIT

# Check rows are written to a temporary file and inserted into the report at exit.
: >"$report_dir/.check-rows"
record_check() {
  local name="$1" status="$2" rc="$3"
  printf '| %s | **%s** | %s |\n' "$name" "$status" "$rc" >>"$report_dir/.check-rows"
  if [[ "$status" == PASS ]]; then
    checks_passed=$((checks_passed + 1))
  else
    checks_failed=$((checks_failed + 1))
  fi
}

check_root() { (( EUID == 0 )) || { printf 'Run as root from the official Arch ISO.\n'; return 1; }; }
check_arch() { [[ -f /etc/arch-release ]] || { printf 'Not an Arch Linux environment.\n'; return 1; }; }
check_uefi() { [[ -d /sys/firmware/efi ]] || { printf 'Boot the Arch ISO in UEFI mode.\n'; return 1; }; }
check_git() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { printf 'Invalid Git checkout.\n'; return 1; }
  printf 'Branch: %s\nCommit: %s\nWorking tree: %s\n' "$branch" "$commit" "$working_tree"
}
check_commands() {
  local missing=() cmd
  for cmd in bash git find lsblk jq swapon base64 readlink stat python3; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
  done
  (("${#missing[@]}" == 0)) || { printf 'Missing required commands: %s\n' "${missing[*]}"; return 1; }
  printf 'All required commands are available.\n'
}
check_syntax() {
  local -a shell_files=()
  mapfile -d '' shell_files < <(find . -type f \( -name '*.sh' -o -name installer \) -not -path './.git/*' -print0)
  (("${#shell_files[@]}" > 0)) || { printf 'No shell scripts found.\n'; return 1; }
  local file
  for file in "${shell_files[@]}"; do bash -n "$file" || return 1; done
  printf 'PASS: %s shell files pass bash -n.\n' "${#shell_files[@]}"
}

run_check "Root privileges" check_root
run_check "Arch Linux live environment" check_arch
run_check "UEFI boot mode" check_uefi
run_check "Git checkout and commit identity" check_git
run_check "Required command availability" check_commands

if command -v find >/dev/null 2>&1 && command -v bash >/dev/null 2>&1; then
  run_check "Repository Bash syntax" check_syntax
else
  run_check "Repository Bash syntax" false
fi

if command -v bash >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1; then
  run_check "Canonical automated test suite" bash tests/run.sh
else
  run_check "Canonical automated test suite" false
fi

if command -v bash >/dev/null 2>&1 && command -v lsblk >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 && command -v swapon >/dev/null 2>&1; then
  run_check "X280 SSD identity and live topology (read-only)" bash scripts/validate-live-storage.sh
else
  run_check "X280 SSD identity and live topology (read-only)" false
fi

if (( checks_failed > 0 )); then
  exit 1
fi
exit 0
