# Test Guide

## Canonical command and manifest

Run from the repository root:

```bash
bash tests/run.sh
```

The test list is defined only in `tests/run.sh` (20 scripts at this revision). Do not maintain a second editable manifest in documentation. The runner requires `bash`, `jq`, and `python3`. The native C helper compile/CLI test is skipped only when `cc` is unavailable; all other missing dependencies, missing scripts, or test failures make the run exit non-zero.

## What the suite covers

| Test | Scope |
|---|---|
| `test-x280-first-boot-check.sh` | Mocked first-boot collector: PASS report, FAIL propagation, evidence files, and read-only contract. |
| `test-bootstrap-archiso.sh` | Static source-review, commit identity, exact acknowledgement, and no-remote-pipe contract checks for the Arch ISO bootstrap. |
| `test-common-preflight.sh` | Logging and read-only preflight helpers |
| `test-installer-entry.sh` | Legacy `installer --help/--preflight` behavior and diagnostic-only boundary |
| `test-arch-installer-script.sh` | Static syntax/contract checks for the initial destructive installer on main; does not execute it |
| `test-arch-config-script.sh` | Static checks for target configuration; does not run it inside a real target |
| `test-pinned-device-path.sh` | Selected disk utilities against a disposable loop-backed image through inherited descriptor paths |
| `test-inventory.sh` | Host inventory and profile parsing using fixtures |
| `test-storage-discovery.sh` | Disk discovery using mocked `lsblk`/`swapon` data |
| `test-storage-plan.sh` | GPT geometry, alignment, capacity, overflow, and RAM-plus-margin swap arithmetic |
| `test-storage-prerequisites.sh` | Live prerequisite collector with mocked inputs/failure paths |
| `test-storage-confirmation.sh` | Plan review digest, exact confirmation, cancellation, and final revalidation |
| `test-storage-execution-dry-run.sh` | In-memory operation manifest and injected failure behavior |
| `test-storage-execution-boundary.sh` | Mock-only probes, gate consistency, stop behavior, and recovery ledger |
| `test-storage-topology.sh` | Synthetic sysfs, mountinfo, loop/overlay dependencies, and swap topology |
| `test-preflight-gate.sh` | Mocked preflight gate and failure propagation |
| `test-native-storage-handle.sh` | Native helper compile/CLI behavior; no real block device is opened |

| `test-base-system-fstab.sh` | Fstab generation preserves existing unrelated entries, is idempotent, and rejects conflicting root/EFI entries. |\n| `test-resume-arch-installer.sh` | Static safety contract for the checkpoint-specific continuation path; asserts it does not partition, format, or rerun pacstrap. |\n\nThe suite does not run a complete installer transaction. The disposable loop test formats only its temporary loop-backed image; it is not a physical NVMe test. It is bounded utility-interface coverage only and must never be treated as a substitute for the required destructive full-SSD installation test on the actual X280. Fixture/static checks do not establish that the installer boots or that every target-device race is impossible.

**Validation policy (REQ-INSTALL-006):** VM-based installer testing is explicitly out of scope and will not be performed. Keep automated coverage bounded to fixtures, mocks, static checks, and disposable loop-backed images. The destructive full-SSD replacement path must remain implemented; its end-to-end acceptance test is performed on the actual ThinkPad X280 only after the Stage 9 physical-test gate, recovery preparation, and explicit authorization. Loop-device tests are not substitutes for that physical test.

## Persistent test evidence

Each run creates a unique `reports/test-runs/<UTC timestamp>/` directory containing:
- `summary.md`: branch, commit, host/kernel metadata and per-test result.
- `combined.log`: combined stdout/stderr and skip reasons.
- `<test-name>.log`: individual test output.

The runner does not automatically commit reports. Inspect logs and review them for host-specific or sensitive information before sharing or committing. Reports apply only to their recorded checkout and host snapshot.

The consolidated physical readiness command `bash scripts/x280-install-readiness.sh` additionally creates `reports/live-readiness/<UTC timestamp>/summary.md` and `diagnostics.log`. It records each readiness check, checkout SHA, environment metadata, final result, and captured output; detected disk serial values are redacted from diagnostics. The script does not run `git add`, commit, or push. After reviewing the report, commit and push only the intended timestamped report directory. The test runner's `reports/test-runs/` remains available for deeper per-test logs.

## Live Arch ISO / X280 validation

The broad read-only validation command is:

```bash
bash scripts/live-validation.sh
```

It gathers host/boot/storage/network diagnostics, runs local quality checks when available, executes the canonical suite, and records output under `reports/live-validation/`. The report is local evidence, not automatically committed. It must be reviewed for sensitive details before sharing.

The target-specific read-only storage validator is:

```bash
bash scripts/validate-live-storage.sh
```

It requires UEFI, matches the configured X280 internal SSD identity, discovers whole disks, and invokes the live topology validator. It performs no partitioning, formatting, encryption, mounting, or disk writes. A successful result is evidence only for that live snapshot; it is not authorization to erase a disk.

The physical X280 validator has previously failed because the removable SD/MMC reader reported zero capacity. Discovery was changed to skip only numeric-zero whole-disk records with `RM=true`; zero-sized non-removable and unknown-size records remain fail-closed. The updated validator still requires a successful physical rerun after this fix.

## Arch ISO bootstrap

The operator-facing bootstrap is `scripts/bootstrap-archiso.sh`. It fetches the latest `main` checkout, prints its commit SHA, opens the relevant source files for manual review, runs the read-only live-readiness gate, and requires a second exact acknowledgement before launching the destructive installer. A failed readiness check blocks launch. See [Arch ISO bootstrap and source-review gate](../docs/16-ARCHISO-BOOTSTRAP.md). The bootstrap test is static contract coverage only; it does not run the bootstrap or the destructive installer.

## Installer distinction

- Top-level `installer --preflight`: read-only diagnostics only.
- `scripts/install-arch-x280.sh` on main: initial destructive Arch base installer. Its static test does not execute the script. The pinned-device integration test covers selected utility interfaces against a disposable loop image only.

The destructive installer must not be run until the gate in [Stage 9 — Initial Interactive Arch Installer](../docs/15-ARCH-INSTALLER-INITIAL-EXECUTION.md) is satisfied. Its scope, boot contract, and limitations are documented in [Installation and Disk](../docs/04-INSTALLATION-AND-DISK.md). Current CI evidence and commit references are maintained only in [Implementation Status](../docs/12-IMPLEMENTATION-STATUS-AND-CHANGELOG.md).

## Evidence interpretation

- PASS means the listed test passed for the recorded commit and environment.
- SKIP means an optional test dependency was unavailable; it is not a pass.
- A passing fixture suite does not prove physical hardware behavior.
- No VM installation/boot test is planned or required; the physical X280 destructive installation and first boot are the required end-to-end acceptance evidence.
- A non-empty UKI file does not prove firmware boot, LUKS unlock, or root mount.
- Physical installation, first boot, hibernation/resume, Wi-Fi, audio, suspend, and other hardware behavior remain NOT TESTED until observed on the actual X280.

## Physical first-boot evidence

After the initial install boots successfully on the actual X280 and the regular user has logged in, run `sudo /usr/local/sbin/x280-first-boot-check`. The collector writes a timestamped report under `reports/first-boot/` containing `summary.md`, `diagnostics.log`, `boot-status.txt`, `system-status.txt`, and `hardware.txt`. It is read-only, retains a report on failure, and exits non-zero if an acceptance check fails. Review all files for sensitive data before staging only the intended report directory. See [X280 first-boot test](../docs/17-X280-FIRST-BOOT-TEST.md).

## Destructive installer run logs

The destructive installer creates `/var/log/x280-installer/<UTC timestamp>/installer.log` before host preflight or storage operations. The directory is root-only (0700) and the file root-only (0600). If `/var/log` is unavailable, it uses `/run/x280-installer/`; that fallback is volatile. The Arch ISO may also keep `/var/log` on an ephemeral overlay, so copy the log to persistent media before reboot regardless of path. The installer prints the exact log path on exit.

The log contains stdout/stderr, stage markers, start/end metadata, exit status, and stage-specific storage validation diagnostics. It does not enable shell xtrace. Never enter secrets as command-line arguments; interactive prompts are intended to read them from the terminal. Hardware identifiers may appear in the log, so inspect and redact before sharing. See [Error Recovery and Reporting](../docs/10-ERROR-RECOVERY-AND-REPORTING.md).

This logging does not change the destructive boundary: final read-only revalidation must pass before the first `wipefs` operation. A `pre-operation-check:` failure means that particular operation was not invoked. A failure at or after a `disk-operation:` stage requires inspecting actual disk state because earlier operations may already have changed it; do not rerun blindly.
