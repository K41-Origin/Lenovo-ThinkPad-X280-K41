# Architecture and Modules

## Purpose and authority

This document defines the implemented repository architecture and module ownership. It must remain consistent with:
- [Requirements and Decisions](02-REQUIREMENTS-AND-DECISIONS.md) — approved requirements and decisions.
- [Installation and Disk](04-INSTALLATION-AND-DISK.md) — canonical storage, encryption, boot, and recovery design.
- [Testing and Acceptance](11-TESTING-AND-ACCEPTANCE.md) — test contracts and evidence thresholds.
- [Implementation Status](12-IMPLEMENTATION-STATUS-AND-CHANGELOG.md) — current implementation and validation state.

The project charter in [01](01-PROJECT-CHARTER.md) owns status definitions. The domain documents own detailed policies; this architecture document does not duplicate their full procedures.

## Current architecture status — 2026-11-07

The repository contains two distinct entry paths:

1. `installer` is the original diagnostic entry point. It supports `--help` and read-only `--preflight`; it does not install Arch.
2. `scripts/install-arch-x280.sh` is a separate initial destructive installer on PR #9's feature branch. It performs target-specific storage operations, installs a minimal Arch base, runs target configuration, and generates a systemd-boot UKI. It is IMPLEMENTED, but physical installation and first boot are NOT TESTED.

Do not conflate these paths. The PR branch is not equivalent to merged/released code. See the status document for exact commit and CI evidence.

## Runtime flow implemented by the initial installer

The current script's observed sequence is:

1. Require root, Arch ISO prerequisites, UEFI mode, and a matching ThinkPad X280 host inventory.
2. Discover whole-disk candidates and require the configured internal WDC PC SN730 identity, capacity, and stable serial evidence.
3. Calculate GPT layout and runtime-RAM-plus-margin swapfile size; bind the target and collect live prerequisites.
4. Render the plan, require exact plan-bound confirmation, and perform final target/prerequisite revalidation.
5. Retain Bash file descriptors for the selected whole disk and partitions; pass inherited `/proc/self/fd/N` paths to selected storage utilities.
6. Create GPT/ESP/Linux-LUKS partition layout, format FAT32 and LUKS2/ext4, open the mapper, and mount root/ESP.
7. Call `base_system::bootstrap` for guarded `pacstrap -K` and UUID-based fstab generation.
8. Run `scripts/configure-arch-x280.sh` inside `arch-chroot` for hostname, user/password, timezone, locale, Intel microcode, sudo wheel access, swapfile, and NetworkManager.
9. Install systemd-boot and generate a mkinitcpio UKI using systemd-based `sd-encrypt` hooks and `rd.luks.name=`.
10. Check expected target configuration artifacts and stop without automatic reboot.

This is a factual description of code paths, not evidence that the complete workflow succeeds on the physical X280. VM installation/testing is explicitly out of scope under REQ-INSTALL-006.

## Module ownership and boundaries

| Component | Owns | Current boundary |
|---|---|---|
| `installer`, `lib/common.sh`, `lib/preflight.sh` | Diagnostic CLI and read-only preflight | IMPLEMENTED; diagnostic only |
| `lib/inventory.sh` | Read-only host CPU, memory, and DMI inventory/profile comparison | IMPLEMENTED; fixture-tested; actual X280 Linux inventory NOT TESTED |
| `lib/storage.sh`, `lib/storage-topology.sh` | Read-only disk discovery and live topology validation | IMPLEMENTED; fixture-tested; physical live validator NOT TESTED |
| `lib/storage-plan.sh` | Pure GPT layout and swap sizing calculations; plan serialization/binding | IMPLEMENTED; fixture-tested |
| `lib/storage-prerequisites.sh`, `lib/storage-confirmation.sh` | Read-only prerequisite evidence, exact confirmation, final revalidation | IMPLEMENTED; fixture-tested |
| `lib/storage-execution-dry-run.sh`, `lib/storage-execution-boundary.sh` | In-memory operation model and mock-only orchestration/recovery ledger | IMPLEMENTED; tests invoke mocks only |
| `lib/base-system.sh` | Guarded package bootstrap and fstab generation for already-mounted target | IMPLEMENTED; invoked by PR #9 installer |
| `scripts/install-arch-x280.sh` | Initial destructive installer orchestration | IMPLEMENTED on PR #9; destructive path NOT TESTED on hardware |
| `scripts/configure-arch-x280.sh` | Interactive initial target-system configuration | IMPLEMENTED; invoked through arch-chroot; full integration NOT TESTED |
| `native/storage-handle.c` | Standalone read-only native descriptor prototype | IMPLEMENTED; compile/CLI test only; not integrated with installer |
| `lib/bootloader.sh`, `lib/user-setup.sh`, `lib/desktop.sh`, `lib/hardware.sh`, `lib/packages.sh`, `lib/security.sh`, `lib/validation.sh`, `lib/report.sh` | Future domain-specific reusable modules | PLANNED placeholders; do not imply they are called by the installer |

### Storage execution distinction

The read-only storage modules and mock execution boundary do not own the PR #9 destructive implementation. The initial installer script currently orchestrates destructive commands directly, guarded by its target-plan confirmation and descriptor-pinned paths. This is an architectural deviation from the earlier planned rule that `lib/storage.sh` alone owns destructive operations. Do not describe that planned boundary as implemented. A future refactor must establish a tested executor contract before moving or expanding destructive behavior.

The Bash descriptor-pinned loop integration demonstrates that selected utilities accept the inherited `/proc/self/fd/N` paths in the tested disposable-loop scenario. It does not prove all kernel races impossible, establish exclusive kernel ownership, test physical NVMe hot-unplug, or validate the native C helper. The C helper remains separate and unused by the installer. See [Stage 8](14-STAGE-8-NATIVE-DEVICE-ACCESS.md) and [Stage 9](15-ARCH-INSTALLER-INITIAL-EXECUTION.md).

## Bootstrap and source policy

The intended operator workflow retrieves a reviewed repository revision and displays its resolved commit SHA before executing project code. A commit SHA provides traceability, not proof of safety. Review the entry point, every sourced module, all invoked scripts, privilege transitions, remote-code behavior, package verification, and destructive paths. Never pipe remote scripts directly into a shell.

The current PR #9 branch installer is a manually invoked script; it is not automatically launched by the Arch ISO and is not invoked by the top-level `installer --preflight`.

## Failure and privilege rules

- Keep read-only discovery, planning, confirmation, execution, and post-operation verification conceptually separate.
- Fail closed on unknown target identity, topology, prerequisites, or critical configuration.
- Cancellation and failed gates must not reach destructive operations.
- Do not disable unrelated live-ISO swap.
- Never log passphrases, account passwords, recovery keys, or tokens.
- After any failure once destructive work starts, stop and inspect actual disk state. Never automatically repeat partitioning or formatting.
- The installer does not reboot automatically; inspect and cleanly unmount only after verifying the resulting system.

## Testing layers and acceptance

The canonical test runner is `bash tests/run.sh`; see [tests/README.md](../tests/README.md). Static tests, fixture tests, and the disposable loop-device integration test provide bounded evidence. They do not prove full installation, UKI bootability, physical NVMe behavior, wireless/audio/power behavior, or hibernation.

Before physical destructive testing, the project still needs an independent review of the installer and its failure/cleanup paths, successful current CI, successful read-only live validation on the actual X280, and a documented operator test gate. The next end-to-end installation test is deliberately performed on the actual X280; no VM gate is required or planned. Detailed acceptance cases and current evidence are owned by [Testing and Acceptance](11-TESTING-AND-ACCEPTANCE.md).

## Deferred architecture

- Full reusable storage executor with a proven descriptor/capability contract.
- Physical X280 destructive installation and successful first boot (required acceptance; NOT TESTED).
- Resume-offset lifecycle and hibernation.
- Hyprland, Caelestia Shell, Quickshell, portals, audio, and session integration.
- Hardware/power/thermal tuning based on Linux-observed capabilities.
- Optional selective BlackArch integration.
- Final health validation and post-install report generation.
