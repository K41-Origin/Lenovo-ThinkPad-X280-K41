# Repository-Wide Audit — 2026-11-07

## Audit record

- **Repository:** `K41-Origin/Lenovo-ThinkPad-X280-K41`
- **Audited branch:** `main`
- **Audited commit:** `8aa3a447ca1b5fa7cae52dd94759d83fab8aaf9a`
- **Audit date:** 2026-11-07
- **Repository visibility:** public at audit time
- **Scope:** complete recursive tracked-file inventory; installer entry point; production Bash modules; storage planning, confirmation, mock execution boundary, and native C helper; test suite; CI workflow and latest run; hardware profile; hardware baseline; relevant architecture/testing/status documentation.
- **Method:** GitHub repository tree/blob inspection, source/document review, and GitHub Actions run/job inspection. No code was executed on the physical laptop during this audit. No disk, package database, service, firmware setting, or network configuration was changed.

This report supersedes the 2026-11-03 audit snapshot below. Historical statements and older run references in earlier changelog entries remain historical evidence, not the current baseline.

## Executive summary

The repository has a useful safety-first foundation and a clear modular structure. It is **ready for additional read-only hardware validation**, but it is **not ready for destructive installation or real storage execution**.

The most important distinctions are:

1. The Stage 8 native C helper is implemented as a read-only prototype and has compile/CLI test coverage. It has **not** been tested against a real block device, and it is not integrated into the Bash storage boundary.
2. The physical ThinkPad X280 has already been observed in an Arch Linux ISO session. User-provided terminal photographs document UEFI mode, USB and internal NVMe identities, partition layout, visible mount/loop topology, and no active swap in those snapshots. These observations do **not** prove the repository's own live discovery/topology validator has run successfully.
3. `scripts/validate-live-storage.sh` exists and is intended to perform that programmatic read-only validation, but its physical-device execution remains NOT TESTED.
4. No real storage executor, partitioning, formatting, LUKS operation, filesystem creation, mounting, or complete Arch installation workflow is implemented.

## Repository inventory

At the audited commit, the recursive Git tree contains **58 tracked files**:

| Category | Count / observation |
|---|---:|
| Markdown files | 18 |
| Bash files (`.sh`) | 35 |
| Native C source | 1 |
| Hardware configuration | 1 |
| GitHub Actions workflow | 1 |
| Files without extension | 2 |
| Test scripts | 12 |
| Main documentation set | 15 numbered documents |

The top-level structure remains compact: `.github/`, `config/`, `docs/`, `lib/`, `native/`, `scripts/`, and `tests/`, plus project root files. No broad directory restructuring is indicated by this audit.

## CI evidence

GitHub Actions run **#185** (run ID `42349907205`) completed with conclusion `success` on the exact audited commit `8aa3a447ca1b5fa7cae52dd94759d83fab8aaf9a`.

Verified successful steps:

- Dependency installation.
- Bash syntax validation.
- ShellCheck.
- Configured shfmt check for the test infrastructure.
- Canonical repository test suite.

This is automated CI evidence. It does not establish physical NVMe behavior, real exclusive-open semantics, end-to-end installer operation, or destructive-operation safety.

A prior run (#184) failed at the formatting check and skipped the test suite; the later successful run #185 is the current CI evidence. Do not treat the earlier failure as the current result.

## Component audit

### Installer and overall architecture

- `installer` supports `--help` and diagnostic-only `--preflight`.
- Preflight is not installation approval and intentionally returns nonzero while installation is disabled.
- The nine domain module placeholders remain PLANNED; they do not implement base-system, bootloader, user, desktop, hardware, package, security, validation, or reporting installation workflows.
- No interactive end-to-end installer orchestration exists.

**Assessment:** the diagnostic entry point is intentionally limited and appropriately fails closed. Installation remains PLANNED.

### Storage foundation

The repository separates discovery, topology analysis, GPT planning, prerequisite evidence, explicit confirmation, dry-run simulation, and mock execution orchestration.

Implemented/tested boundaries include:

- Read-only whole-disk discovery and target identity checks.
- Sysfs dependency/topology analysis and mount/swap relationship checks, with fixture tests.
- GPT layout calculation without disk mutation.
- Plan-bound confirmation and fresh prerequisite revalidation.
- Eight-step in-memory dry-run manifest and deterministic failure simulation.
- Mock-only execution boundary with per-operation target probes and partial-failure/recovery ledger.

The mock boundary does not open or hold a real block-device handle. Path rechecks do not eliminate kernel-level TOCTOU races. No production storage callback or destructive executor exists.

**Assessment:** useful testable foundation; not a real storage execution system.

### Stage 8 native block-device helper

`native/storage-handle.c` is present and its isolated compile/CLI tests are included in CI. The prototype opens a supplied `/dev/<name>` path read-only with exclusive/no-follow/close-on-exec/nonblocking flags, checks the opened object with `fstat`, rejects non-block and partition devices, reads supported geometry/read-only attributes through descriptor ioctls, reports major:minor and optional diskseq, and retains the descriptor until stdin EOF.

Still outstanding:

- Runtime testing against disposable loop/block devices.
- Evidence for `O_EXCL` behavior with mounted/active descendants and competing openers.
- Stable WWN/serial correlation against the retained descriptor.
- Explicit removable/internal-NVMe validation.
- Expected-plan binding and a versioned Bash/helper protocol.
- Lifecycle supervision, hot-unplug and failure tests.
- Proof that every future partition/LUKS/filesystem operation uses the retained capability rather than independently reopening a pathname.

**Assessment:** IMPLEMENTED as a prototype; NOT TESTED on block-device runtime; NOT integrated; no executor.

### Physical ThinkPad X280 evidence

The current hardware evidence is not limited to the Windows baseline. `docs/11-TESTING-AND-ACCEPTANCE.md` records physical Arch ISO observations from user-provided terminal photographs dated 2026-11-07.

Observed in the captured snapshots:

- UEFI boot and Arch Linux ISO environment.
- Installer USB as removable media.
- Internal WDC PC SN730 NVMe at `/dev/nvme0n1`, including the serial-based by-id alias.
- Existing Windows partition layout.
- Live root using overlay/loop-backed Arch ISO storage.
- No active swap entries in the displayed snapshots.
- An additional SD/MMC reader distinct from both the installer USB and internal NVMe.

These are VERIFIED as displayed, point-in-time observations. They do not establish ongoing state, and photographs of raw commands do not test project code. The repository's `storage::discover_candidates`, `storage::validate_target`, and `scripts/validate-live-storage.sh` have not yet been demonstrated running successfully on the laptop.

### Hardware identity and owner-specific data

The X280 baseline distinguishes owner-reported/Windows-observed specifications from Linux observations. The SSD model and serial are intentionally retained in the target-specific live-validation path because this is a single-laptop project and the unique serial is useful evidence for identifying the intended internal device.

The repository is **public** at audit time. Therefore the SSD serial is publicly visible. It has been retained in this synchronization at the owner's explicit direction; this is an acknowledged exposure trade-off, not a statement that device-unique identifiers are generally safe to publish. The battery serial and unrelated identifiers remain excluded.

## Documentation synchronization findings

The audit identified stale descriptions that understated the current implementation:

| File | Stale statement | Synchronization required |
|---|---|---|
| `README.md` | Stage 8 helper described as unimplemented | Identify the read-only native prototype and its test/runtime boundary |
| `docs/03-ARCHITECTURE-AND-MODULES.md` | No native handle implemented | Distinguish prototype from tested block-device runtime and executor |
| `docs/11-TESTING-AND-ACCEPTANCE.md` | Eleven tests / old run #149 presented as current | Record 12 test scripts and successful run #185; separate CI from physical observations |
| `docs/12-IMPLEMENTATION-STATUS-AND-CHANGELOG.md` | Old CI baseline and 51-file audit snapshot | Record current audited commit, CI run, hardware evidence, and remaining gates |
| `docs/13-X280-HARDWARE-BASELINE.md` | General unique-ID exclusion conflicted with retained SSD serial | Document the deliberate SSD-serial exception and public-repository exposure |
| `docs/15-REPOSITORY-AUDIT.md` | 2026-11-03 snapshot treated as current | Replace with this current audit while retaining history in changelog |

The target-specific serial in `scripts/validate-live-storage.sh` is deliberately preserved. No device identity value or hardware profile value is being generalized or replaced.

## Readiness matrix

| Area | Status | Evidence / next gate |
|---|---|---|
| Repository structure | IMPLEMENTED | 58 tracked files inspected |
| Bash syntax and lint | TESTED | CI run #185 passed |
| Fixture test suite | TESTED | 12 test scripts passed in CI run #185 |
| Host inventory | TESTED (fixtures) | Physical Linux inventory still needs execution/evidence |
| Raw X280 Arch ISO observations | VERIFIED (limited) | User-provided terminal photographs, Stages 8–9 |
| Project live storage validator | NOT TESTED on hardware | Run `scripts/validate-live-storage.sh` on the X280 and preserve output |
| Storage discovery/topology on actual X280 | NOT TESTED by project code | Require successful live validator evidence |
| GPT plan on actual X280 | NOT TESTED | Must be reviewed as a non-executing plan |
| Native helper compile/CLI | TESTED | CI run #185 |
| Native helper block-device runtime | NOT TESTED | Disposable-device tests first |
| Descriptor-to-executor safety contract | PLANNED | Prove descriptor-bound operation path |
| Real storage executor | NOT IMPLEMENTED | Separate design, security review, and tests required |
| Arch base installation | PLANNED | No installation workflow exists |
| Desktop / Caelestia / Quickshell | PLANNED | Upstream dependency/version validation and implementation pending |
| Power/thermal/hardware tuning | PLANNED | Must be based on Linux-observed hardware capabilities |
| BlackArch integration | PLANNED / OPTIONAL | Selective tools only; not a prerequisite |

## Prioritized next actions

### P0 — Before any destructive installation work

1. Execute `scripts/validate-live-storage.sh` in the physical X280 Arch ISO session. This is read-only. Inspect the complete output; do not infer success from raw `lsblk` photographs.
2. If validation fails or reports unknown topology/identity, stop and diagnose the exact missing evidence. Do not weaken fail-closed checks to obtain a pass.
3. Add disposable loop-device tests for native helper open/FD/ioctl behavior, including competing openers and active/mounted child scenarios. These tests must never target the internal SSD.
4. Resolve stable-identity correlation and the descriptor-to-operation design. A pathname-based utility reopening the device does not inherit the helper's retained descriptor protection.
5. Define and test the real executor only after the descriptor-bound operation path and recovery behavior are reviewed.

### P1 — Before calling the project an Arch installer

1. Implement and test base Arch installation in an isolated VM.
2. Implement the approved encryption, filesystem, UKI/systemd-boot, swapfile, and resume lifecycle with current upstream documentation.
3. Implement account/security configuration, post-install validation, and recovery/reporting.
4. Test full installation and reboot/unlock in a disposable VM before any controlled physical installation.

### P2 — After a verified base system

1. Verify current upstream dependencies and installation methods for Hyprland, Caelestia Shell, and Quickshell.
2. Implement desktop, network, audio, Bluetooth, and hardware configuration in isolated stages.
3. Add X280-specific battery, thermal, suspend/resume, and power tests based on observed Linux capabilities.

### P3 — Optional software

Implement selective BlackArch integration only after the base installation and security/update model are stable.

## Audit limitations

- This audit inspected GitHub repository content and CI evidence; it did not execute the code locally or on the X280.
- CI success proves only the checks in the workflow.
- Physical evidence was provided as terminal photographs; the auditor did not independently execute the displayed commands.
- No native helper block-device runtime, disposable-device test, VM installation, real storage operation, or desktop installation was performed.
- No destructive operation was attempted or authorized.

## Audit conclusion

The repository is **ready for the next read-only live-validation step**, not for disk erasure or installation. Preserve the modular architecture and the owner-specific SSD identity. The immediate next gate is to run the existing read-only live storage validator on the X280 and inspect its output. Do not implement or enable a destructive executor until live topology, native descriptor behavior, and the descriptor-to-operation contract have independent evidence.
