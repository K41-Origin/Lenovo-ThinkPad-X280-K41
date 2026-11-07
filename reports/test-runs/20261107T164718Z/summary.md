# Repository test run

- Started (UTC): 2026-11-07T16:47:18Z
- Repository: /tmp/Lenovo-ThinkPad-X280-K41
- Branch: feat/x280-live-install-readiness-2026-11-07
- Commit: 59efbf2db1856312c3b4be872b8a72f96c1677c5
- Host: unknown
- Kernel: Linux 7.2.11-arch1-1

## Test results

| Test | Result | Exit | Log |
|---|---:|---:|---|
| tests/test-common-preflight.sh | **PASS** | 0 | test-common-preflight.sh.log |
| tests/test-installer-entry.sh | **PASS** | 0 | test-installer-entry.sh.log |
| tests/test-arch-installer-script.sh | **PASS** | 0 | test-arch-installer-script.sh.log |
| tests/test-arch-config-script.sh | **PASS** | 0 | test-arch-config-script.sh.log |
| tests/test-x280-install-readiness.sh | **PASS** | 0 | test-x280-install-readiness.sh.log |
| tests/test-pinned-device-path.sh | **PASS** | 0 | test-pinned-device-path.sh.log |
| tests/test-inventory.sh | **PASS** | 0 | test-inventory.sh.log |
| tests/test-storage-discovery.sh | **PASS** | 0 | test-storage-discovery.sh.log |
| tests/test-storage-plan.sh | **PASS** | 0 | test-storage-plan.sh.log |
| tests/test-storage-prerequisites.sh | **PASS** | 0 | test-storage-prerequisites.sh.log |
| tests/test-storage-confirmation.sh | **PASS** | 0 | test-storage-confirmation.sh.log |
| tests/test-storage-execution-dry-run.sh | **PASS** | 0 | test-storage-execution-dry-run.sh.log |
| tests/test-storage-execution-boundary.sh | **PASS** | 0 | test-storage-execution-boundary.sh.log |
| tests/test-storage-topology.sh | **PASS** | 0 | test-storage-topology.sh.log |
| tests/test-preflight-gate.sh | **PASS** | 0 | test-preflight-gate.sh.log |
| tests/test-native-storage-handle.sh | **SKIP** | - | test-native-storage-handle.sh.log |

## Summary

- Passed test scripts: 15
- Failed checks: 0
- Skipped test scripts: 1
- Overall result: **PASS**
- Finished (UTC): 2026-11-07T16:47:36Z

## Evidence files

- `summary.md`: per-test result and run metadata
- `combined.log`: combined stdout/stderr from all executed tests and skip reasons
- `<test-name>.log`: individual stdout/stderr or explicit SKIP reason for every manifest entry

The native helper test is skipped only when `cc` is unavailable. Missing required suite dependencies or any failed test returns non-zero. Reports are generated locally and are not committed automatically. Review reports for environment-specific information before sharing. A passing fixture suite is not proof of a successful installation or safe disk erasure.
