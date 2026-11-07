# X280 live installation readiness report

- Result: **FAIL**
- Started (UTC): 2026-11-07T16:42:39Z
- Finished (UTC): 2026-11-07T16:42:59Z
- Repository: Lenovo-ThinkPad-X280-K41
- Branch: feat/x280-live-install-readiness-2026-11-07
- Commit: ae0575e41f3747b5555e5cd5226ee299b63eb4b9
- Working tree before report generation: modified before report generation
- Kernel: Linux 7.2.11-arch1-1
- Architecture: x86_64
- Checks passed: 7
- Checks failed: 1
- Process exit code: 1

## Check results

| Check | Result | Exit |
|---|---:|---:|
| Root privileges | **PASS** | 0 |
| Arch Linux live environment | **PASS** | 0 |
| UEFI boot mode | **PASS** | 0 |
| Git checkout and commit identity | **PASS** | 0 |
| Required command availability | **PASS** | 0 |
| Repository Bash syntax | **PASS** | 0 |
| Canonical automated test suite | **PASS** | 0 |
| X280 SSD identity and live topology (read-only) | **FAIL** | 1 |

## Evidence files

- `summary.md`: result, checkout identity, environment, and check table
- `diagnostics.log`: captured check output; detected disk serial values are redacted

## Interpretation and safety boundary

This report records checks for the commit and live environment above. A PASS means only that the listed read-only checks completed successfully. It does not prove a successful installation or first boot and does not authorize disk erasure. The destructive installer is separate and must not be run without reviewing the target identity, current backup, installation plan, and obtaining explicit operator authorization.

Review both files before committing. Do not add unrelated reports or secrets.
