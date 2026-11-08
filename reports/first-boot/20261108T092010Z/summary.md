# ThinkPad X280 first-boot report

- Result: **PASS**
- Started (UTC): 2026-11-08T09:20:10Z
- Finished (UTC): 2026-11-08T09:20:12Z
- Repository: Lenovo-ThinkPad-X280-K41
- Branch: main
- Commit: d640464b73ca185e0b7edf7a940f2de008069861
- Kernel: Linux 7.2.14-arch1-1
- Architecture: x86_64
- Checks: 14 PASS, 0 FAIL, 0 SKIP
- Script exit code: 0

## Acceptance checks

| Check | Result | Exit | Detail |
|---|---:|---:|---|
| Installed Arch Linux | **PASS** | 0 | Check completed. |
| UEFI boot | **PASS** | 0 | Check completed. |
| Encrypted root mount (ext4 on cryptroot) | **PASS** | 0 | Check completed. |
| Active LUKS cryptroot mapping | **PASS** | 0 | Check completed. |
| EFI system partition mount | **PASS** | 0 | Check completed. |
| EFI random-seed permission security | **PASS** | 0 | Check completed. |
| systemd-boot status | **PASS** | 0 | Check completed. |
| Unified Kernel Image present | **PASS** | 0 | Check completed. |
| systemd reached running state | **PASS** | 0 | Check completed. |
| No failed systemd units | **PASS** | 0 | Check completed. |
| Default systemd target active | **PASS** | 0 | Check completed. |
| NetworkManager active | **PASS** | 0 | Check completed. |
| Network connected | **PASS** | 0 | Check completed. |
| Regular user session context | **PASS** | 0 | Check completed. |

## Evidence files

- `boot-status.txt`: bootloader, UKI, and kernel command-line evidence
- `system-status.txt`: systemd, mounts, network, and encryption state
- `hardware.txt`: hardware inventory without disk serials or filesystem UUIDs
- `diagnostics.log`: captured check output and errors

## Interpretation and safety

This is a read-only snapshot of the running installed system. PASS applies only to the listed check and this boot. SKIP means evidence could not be collected; it is not a pass. A report containing FAIL must be reviewed before any repair. The collector does not change boot configuration, services, networking, encryption, partitions, or files outside its report directory. Review every report file before committing; automated redaction is best-effort and is not a substitute for human review.

Run from the repository root with `sudo bash scripts/x280-first-boot-check.sh` to use the current repository version. Reports are local and are never committed or pushed automatically.
