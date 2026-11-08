# Implementation Status

## Current repository snapshot

**Snapshot date:** 2026-11-08  
**Default branch:** `main`  
**HEAD at last inspection:** `d88827627e800c67989bef1749fb52803ea8235e`

This is the concise current-state record. Detailed dated implementation notes and earlier status snapshots are preserved in the [implementation history archive](archive/12-IMPLEMENTATION-CHANGELOG-HISTORY-2026-11-08.md). Historical branch names, PR states, and CI outcomes in that archive are not current status.

## Current implementation matrix

| Area | Status | Current boundary |
|---|---|---|
| Arch ISO bootstrap and manual source-review gate | IMPLEMENTED | Fetches the reviewed `main` source, displays the resolved SHA, requires source review and a passing read-only readiness gate before launch. Static tests do not prove live ISO execution. |
| Initial encrypted Arch installer | IMPLEMENTED | Destructive base-system installer exists. It is not safe to run without the documented source review, live readiness, target-plan confirmation, recovery preparation, and explicit authorization. |
| Checkpoint-specific continuation | IMPLEMENTED | `scripts/resume-arch-x280.sh` supports the previously reported partial-install checkpoint; it avoids repartitioning, formatting, and rerunning pacstrap. Physical execution remains NOT TESTED. |
| First-boot evidence collector | IMPLEMENTED | Read-only collector and mocked tests exist. No successful physical first-boot report is recorded. |
| Host inventory and storage discovery/planning/revalidation | IMPLEMENTED | Read-only discovery, topology, planning, prerequisite, confirmation, and revalidation modules exist; automated tests use fixtures/mocks. |
| Base-system bootstrap and fstab handling | IMPLEMENTED | Guarded base package setup and idempotent fstab merge logic have automated coverage. |
| Native storage handle prototype | IMPLEMENTED (prototype) | Standalone read-only C prototype; it is not integrated into the installer and does not establish physical device-handle safety. |
| Desktop: Hyprland, Caelestia Shell, Quickshell | PLANNED | Upstream dependency and compatibility verification and implementation remain outstanding. |
| X280 power, battery, thermal, and device tuning | PLANNED | Requires verified runtime hardware evidence and physical testing. |
| Hibernation/resume and recovery-key lifecycle | PLANNED | Configuration and actual suspend/hibernate/resume/recovery validation remain outstanding. |
| Optional selective BlackArch integration | PLANNED | Must remain opt-in and limited to individually selected tools. |

## Current validation evidence

The last inspected `main` HEAD (`d88827627e800c67989bef1749fb52803ea8235e`) had:

- **Repository validation #403: SUCCESS** on that exact commit.
- **Bash validation #270: PENDING** at the time of inspection.
- Earlier successful tests and physical read-only observations are historical, commit-bound evidence. They do not validate later commits or prove a complete installation.

After this documentation change, CI must run again on the new HEAD. Do not carry forward the results above as validation of a later commit.

## Physical X280 checkpoint and outstanding gates

The latest owner-provided installer log recorded that the initial installation had passed final target revalidation, performed disk/partition/LUKS2/filesystem operations, mounted the target, and completed pacstrap, but stopped during fstab generation. The follow-up fstab correction and checkpoint-specific continuation path have since been implemented and covered by automated tests.

This does **not** establish the laptop's present boot state or prove that continuation works on hardware. The following remain **NOT TESTED**:

- Running the checkpoint-specific continuation on the actual X280.
- Successful firmware boot, UKI discovery, LUKS unlock, and first login.
- First-boot collector results from the physical system.
- Suspend/resume, hibernation, battery endurance, thermal behavior, Wi-Fi/audio, and desktop integration.

Do not rerun the initial destructive installer, bootstrap, or broad pre-install readiness flow against a disk that may already contain the partial installation. Follow the checkpoint-specific operator procedure and inspect the current physical state before any action. Never assume the target is blank.

## Branch inventory

At the last GitHub inspection, the repository had `main` and one remaining historical branch, `feat/x280-live-install-readiness-2026-11-07`. Treat `main` as the source of truth; do not re-merge historical branch work that is already integrated.

## Status vocabulary

- **PLANNED:** not implemented.
- **IMPLEMENTED:** code or documentation exists in the repository.
- **TESTED:** an identified test was executed for a stated commit/environment.
- **VERIFIED:** behavior was confirmed with appropriate evidence.
- **RELEASED:** incorporated into a designated release.
- **NOT TESTED:** no adequate evidence exists for the stated behavior.

## Current operator references

- [Installation and disk safety contract](04-INSTALLATION-AND-DISK.md)
- [Arch ISO bootstrap and source-review gate](16-ARCHISO-BOOTSTRAP.md)
- [Initial installer procedure and physical-test gate](15-ARCH-INSTALLER-INITIAL-EXECUTION.md)
- [Checkpoint-specific first-boot test and evidence](17-X280-FIRST-BOOT-TEST.md)
- [Test commands and evidence handling](../tests/README.md)
- [Acceptance criteria](11-TESTING-AND-ACCEPTANCE.md)

