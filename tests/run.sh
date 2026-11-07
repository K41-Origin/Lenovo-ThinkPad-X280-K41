#!/usr/bin/env bash
# Canonical test manifest. Every run preserves per-test logs and a summary report.
set -Eeuo pipefail
umask 077

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"

tests=(
  tests/test-common-preflight.sh
  tests/test-installer-entry.sh
  tests/test-inventory.sh
  tests/test-storage-discovery.sh
  tests/test-storage-plan.sh
  tests/test-storage-prerequisites.sh
  tests/test-storage-confirmation.sh
  tests/test-storage-execution-dry-run.sh
  tests/test-storage-execution-boundary.sh
  tests/test-storage-topology.sh
  tests/test-preflight-gate.sh
  tests/test-native-storage-handle.sh
)

timestamp="$(date -u +'%Y%m%dT%H%M%SZ')"
report_root="$ROOT/reports/test-runs"
mkdir -p -- "$report_root"
run_dir="$report_root/$timestamp"
suffix=0
while ! mkdir -- "$run_dir" 2>/dev/null; do
  suffix=$((suffix + 1))
  run_dir="$report_root/$timestamp-$suffix"
done
combined="$run_dir/combined.log"
summary="$run_dir/summary.md"
: > "$combined"
chmod 600 "$combined"

overall_rc=0
passed=0
failed=0
skipped=0

{
  printf '# Repository test run\n\n'
  printf -- '- Started (UTC): %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Repository: %s\n' "$ROOT"
  printf -- '- Branch: %s\n' "$(git branch --show-current 2>/dev/null || printf unknown)"
  printf -- '- Commit: %s\n' "$(git rev-parse HEAD 2>/dev/null || printf unknown)"
  printf -- '- Host: %s\n' "$(hostname 2>/dev/null || printf unknown)"
  printf -- '- Kernel: %s\n' "$(uname -sr 2>/dev/null || printf unknown)"
  printf '\n## Test results\n\n'
  printf '| Test | Result | Exit | Log |\n|---|---:|---:|---|\n'
} > "$summary"

printf 'Repository test run: %s\n' "$run_dir"

for dependency in bash jq python3 cc; do
  if ! command -v "$dependency" >/dev/null 2>&1; then
    printf 'FAIL: missing test dependency: %s\n' "$dependency" | tee -a "$combined"
    printf '| Dependency: %s | FAIL | 2 | combined.log |\n' "$dependency" >> "$summary"
    failed=$((failed + 1))
    overall_rc=2
  fi
done

for test in "${tests[@]}"; do
  if [[ ! -f "$test" ]]; then
    printf 'FAIL: required test is missing: %s\n' "$test" | tee -a "$combined"
    printf '| %s | FAIL | 1 | combined.log |\n' "$test" >> "$summary"
    failed=$((failed + 1))
    overall_rc=1
  fi
done

if (( overall_rc == 0 )); then
  for test in "${tests[@]}"; do
    test_log="$run_dir/${test##*/}.log"
    printf '\n== %s ==\n' "$test"
    if bash "$test" >"$test_log" 2>&1; then
      rc=0
      result=PASS
      passed=$((passed + 1))
    else
      rc=$?
      result=FAIL
      failed=$((failed + 1))
      overall_rc=1
    fi
    cat -- "$test_log" | tee -a "$combined"
    printf '%s: %s (exit %s) — %s\n' "$test" "$result" "$rc" "$test_log"
    printf '| %s | **%s** | %s | %s |\n' "$test" "$result" "$rc" "${test##*/}.log" >> "$summary"
  done
fi

{
  printf '\n## Summary\n\n'
  printf -- '- Passed test scripts: %s\n' "$passed"
  printf -- '- Failed checks: %s\n' "$failed"
  printf -- '- Skipped test scripts: %s\n' "$skipped"
  if (( overall_rc == 0 )); then
    printf -- '- Overall result: **PASS**\n'
  else
    printf -- '- Overall result: **FAIL**\n'
  fi
  printf -- '- Finished (UTC): %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  printf '\n## Evidence files\n\n'
  printf -- '- `summary.md`: per-test result and run metadata\n'
  printf -- '- `combined.log`: combined stdout/stderr from all test scripts\n'
  printf -- '- `<test-name>.log`: individual stdout/stderr for each test script\n'
  printf '\nReports are generated locally and are not committed automatically. Review them for environment-specific information before sharing. A passing fixture suite is not proof of a successful installation or safe disk erasure.\n'
} >> "$summary"

chmod 600 "$summary" "$combined" "$run_dir"/*.log 2>/dev/null || true
printf '\nSummary: %s\nCombined log: %s\n' "$summary" "$combined"
printf 'Test scripts passed: %s | failed: %s\n' "$passed" "$failed"
exit "$overall_rc"
