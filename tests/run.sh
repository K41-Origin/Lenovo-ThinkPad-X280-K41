#!/usr/bin/env bash
# Canonical test manifest. Every run preserves per-test logs and a summary report.
set -Eeuo pipefail
umask 077

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"

tests=(
  stages/stage-2-basic-arch-install/tests/test-x280-first-boot-check.sh
  stages/stage-3-desktop-install/tests/test-desktop-setup.sh
  stages/stage-5-desktop-customization/tests/test-autologin-desktop.sh
  stages/stage-5-desktop-customization/tests/test-desktop-startup-audit.sh
  stages/stage-5-desktop-customization/tests/test-lockscreen-startup-helper.sh
  stages/stage-5-desktop-customization/tests/test-boot-experience.sh
  stages/stage-5-desktop-customization/tests/test-boot-audit-collector.sh
  stages/stage-5-desktop-customization/tests/test-plymouth-k41-theme.sh
  stages/stage-5-desktop-customization/tests/test-plymouth-only-boot.sh
  stages/stage-5-desktop-customization/tests/test-lockscreen-design.sh
  stages/stage-5-desktop-customization/tests/test-lockscreen-visual-module.sh
  stages/stage-5-desktop-customization/tests/test-lockscreen-visual-deploy.sh
  stages/stage-5-desktop-customization/tests/test-boot-visual-diagnostics.sh
  stages/stage-4-desktop-validation/tests/test-desktop-validation.sh
  stages/stage-4-desktop-validation/tests/test-desktop-repair.sh
  stages/stage-6-hardware-optimization/tests/test-hardware-audit.sh
  stages/stage-5-desktop-customization/tests/test-guest-storage-audit.sh
  stages/stage-5-desktop-customization/tests/test-caelestia-dashboard-cleanup.sh
  stages/stage-5-desktop-customization/tests/test-caelestia-module-repair.sh
  stages/stage-6-hardware-optimization/tests/test-power-management-audit.sh
  stages/stage-6-hardware-optimization/tests/test-power-profile-selector.sh
  tests/test-bootstrap-archiso.sh
  tests/test-common-preflight.sh
  stages/stage-2-basic-arch-install/tests/test-installer-entry.sh
  stages/stage-2-basic-arch-install/tests/test-arch-installer-script.sh
  stages/stage-2-basic-arch-install/tests/test-arch-config-script.sh
  stages/stage-1-live-readiness/tests/test-x280-install-readiness.sh
  tests/test-pinned-device-path.sh
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
  stages/stage-2-basic-arch-install/tests/test-base-system-fstab.sh
  stages/stage-2-basic-arch-install/tests/test-resume-arch-installer.sh
)

timestamp="$(date -u +'%Y%m%dT%H%M%SZ')"
report_root="$ROOT/reports/shared/test-runs"
mkdir -p -- "$report_root"
run_dir="$report_root/$timestamp"
suffix=0
while ! mkdir -- "$run_dir" 2>/dev/null; do
  suffix=$((suffix + 1))
  run_dir="$report_root/$timestamp-$suffix"
done
combined="$run_dir/combined.log"
summary="$run_dir/summary.md"
: >"$combined"
: >"$summary"
chmod 600 "$combined" "$summary"

overall_rc=0
passed=0
failed=0
skipped=0
required_missing=()

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
} >>"$summary"

printf 'Repository test run: %s\n' "$run_dir"

# Only tools needed by the shell/fixture suite are global requirements.
# The C compiler is optional and gates only the native helper test.
for dependency in bash jq python3; do
  if ! command -v "$dependency" >/dev/null 2>&1; then
    required_missing+=("$dependency")
    printf 'FAIL: missing required test dependency: %s\n' "$dependency" | tee -a "$combined"
  fi
done

for test in "${tests[@]}"; do
  test_log="$run_dir/${test##*/}.log"
  if [[ ! -f "$test" ]]; then
    printf 'FAIL: required test is missing: %s\n' "$test" | tee -a "$combined"
    printf 'FAIL: missing test script: %s\n' "$test" >"$test_log"
    printf '| %s | **FAIL** | 1 | %s |\n' "$test" "${test##*/}.log" >>"$summary"
    failed=$((failed + 1))
    overall_rc=1
  elif ((${#required_missing[@]} > 0)); then
    printf 'SKIP: required suite dependency is missing; see combined.log\n' >"$test_log"
    printf '| %s | **SKIP** | - | %s |\n' "$test" "${test##*/}.log" >>"$summary"
    skipped=$((skipped + 1))
  elif [[ $test == tests/test-native-storage-handle.sh ]] && ! command -v cc >/dev/null 2>&1; then
    printf 'SKIP: optional compiler cc is unavailable; install base-devel or a C compiler to run this native-helper test.\n' >"$test_log"
    cat "$test_log" | tee -a "$combined"
    printf '| %s | **SKIP** | - | %s |\n' "$test" "${test##*/}.log" >>"$summary"
    skipped=$((skipped + 1))
  else
    printf '\n== %s ==\n' "$test" | tee -a "$combined"
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
    printf '| %s | **%s** | %s | %s |\n' "$test" "$result" "$rc" "${test##*/}.log" >>"$summary"
  fi
done

if ((${#required_missing[@]} > 0)); then
  overall_rc=2
fi

{
  printf '\n## Summary\n\n'
  printf -- '- Passed test scripts: %s\n' "$passed"
  printf -- '- Failed checks: %s\n' "$failed"
  printf -- '- Skipped test scripts: %s\n' "$skipped"
  if ((overall_rc == 0)); then
    printf -- '- Overall result: **PASS**\n'
  else
    printf -- '- Overall result: **FAIL**\n'
  fi
  printf -- '- Finished (UTC): %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  printf '\n## Evidence files\n\n'
  printf -- '- `summary.md`: per-test result and run metadata\n'
  printf -- '- `combined.log`: combined stdout/stderr from all executed tests and skip reasons\n'
  printf -- '- `<test-name>.log`: individual stdout/stderr or explicit SKIP reason for every manifest entry\n'
  printf '\nThe native helper test is skipped only when `cc` is unavailable. Missing required suite dependencies or any failed test returns non-zero. Reports are generated locally and are not committed automatically. Review reports for environment-specific information before sharing. A passing fixture suite is not proof of a successful installation or safe disk erasure.\n'
} >>"$summary"

chmod 600 "$summary" "$combined" "$run_dir"/*.log
printf '\nSummary: %s\nCombined log: %s\n' "$summary" "$combined"
printf 'Test scripts: %s passed | %s failed | %s skipped\n' "$passed" "$failed" "$skipped"
exit "$overall_rc"
