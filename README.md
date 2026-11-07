# Lenovo-ThinkPad-X280-K41

A personal, modular, security-conscious Arch Linux installation and setup project for the Lenovo ThinkPad X280.

> **Project status (2026-11-07):** PR #9 contains an initial destructive X280 installer at `scripts/install-arch-x280.sh`, a target configuration script, guarded base bootstrap, and a disposable loop-device integration test. These are branch-only changes and are not part of `main` until merged. CI evidence covers syntax/static checks and loop-backed tool interfaces only; physical X280 installation and boot remain NOT TESTED. The separate top-level `installer --preflight` remains read-only diagnostics.

## AI-assisted development

Repository-wide AI contribution rules are defined in [`AGENTS.md`](AGENTS.md). AI-assisted changes must follow those rules and verify repository writes and relevant tests before reporting completion.

## Goals
- One interactive installer launched from the shell of an official, unmodified Arch Linux ISO booted from USB.
- Retrieve the latest code from the repository's `main` branch, display the resolved commit SHA, and review the relevant shell code before invoking the installer.
- Carefully verified encrypted ext4 system with swapfile and hibernation readiness.
- Hyprland with Caelestia Shell / Quickshell, subject to verified upstream compatibility.
- ThinkPad hardware, power, and network configuration based on actual device inventory.
- Optional AUR workflow and selective BlackArch integration.
- Safe recovery, testable modules, and honest post-install reporting.

## Current repository structure

- `installer` — diagnostic-only entry point with `--help` and `--preflight`; this is separate from the PR #9 destructive installer script.
- `config/hardware/thinkpad-x280.conf` — declarative target profile, never disk-selection authority.
- `lib/inventory.sh` — read-only runtime host discovery and profile comparison.
- `lib/storage.sh` — read-only whole-disk discovery and fresh target validation; no partition/format/mount operations.
- `lib/storage-plan.sh`, `lib/storage-prerequisites.sh`, and `lib/storage-confirmation.sh` — target-bound storage planning, read-only prerequisite evidence, explicit confirmation, and final revalidation.
- `lib/storage-execution-dry-run.sh` — in-memory operation manifest and failure simulator.
- `lib/storage-execution-boundary.sh` — mock-only execution orchestration with per-operation identity probes and partial-failure ledger; it does not open or lock a real block device.
- `native/storage-handle.c` and `docs/14-STAGE-8-NATIVE-DEVICE-ACCESS.md` — Stage 8 read-only native descriptor-holder prototype and its canonical design/limitations; hardware behavior and executor integration remain unverified.
- `lib/base-system.sh` — guarded `pacstrap -K` base package installation and UUID-based fstab generation for an already mounted target. Other desktop, hardware tuning, package/security policy, validation, and reporting modules remain PLANNED.
- `tests/run.sh` — canonical fixture-based test runner; `tests/helpers/` contains shared test-only fixtures. Test dependencies are `bash`, `jq`, and `python3`.
- `scripts/live-validation.sh` — read-only live-host validation for Arch ISO / X280; saves timestamped evidence and `reports/live-validation/latest.md`.
- `docs/` — project requirements, decisions, architecture, safety, and status.

## Intended workflow
1. Boot the official Arch Linux ISO from USB.
2. Connect to the network and run the documented bootstrap procedure from the ISO shell.
3. Retrieve the repository's latest `main` branch using Git and display the resolved commit SHA.
4. Review the resolved commit and all relevant shell code before executing any project code; stop if its source, integrity, or effects cannot be understood. See [manual bootstrap review](docs/03-ARCHITECTURE-AND-MODULES.md#manual-bootstrap-and-pre-execution-review).
5. Run read-only live validation and the canonical test suite; inspect their reports.
6. For the PR #9 branch only, review `scripts/install-arch-x280.sh` and all sourced modules before considering the destructive installer. It requires exact target-bound confirmation and erases the selected SSD.
7. The current initial installer configures an encrypted base Arch system only; desktop and optional components are not included.
8. Validate outcomes and create `AFTER-INSTALL-X280-K41.txt`.

**Important:** `./installer --preflight` is read-only and is not the destructive installer. `scripts/install-arch-x280.sh` on PR #9 is destructive and has not been validated on the physical X280. Do not run it until the documented review, test, and hardware-readiness gates are satisfied.

## Documentation index
1. [Project charter](docs/01-PROJECT-CHARTER.md)
2. [Requirements and decisions](docs/02-REQUIREMENTS-AND-DECISIONS.md)
3. [Architecture and modules](docs/03-ARCHITECTURE-AND-MODULES.md)
4. [Installation and disk](docs/04-INSTALLATION-AND-DISK.md)
5. [Security and authentication](docs/05-SECURITY-AND-AUTHENTICATION.md)
6. [Desktop and user experience](docs/06-DESKTOP-AND-USER-EXPERIENCE.md)
7. [Hardware, power, and network](docs/07-HARDWARE-POWER-AND-NETWORK.md)
8. [Package and software management](docs/08-PACKAGE-AND-SOFTWARE-MANAGEMENT.md)
9. [Development and bug bounty](docs/09-DEVELOPMENT-AND-BUG-BOUNTY.md)
10. [Error recovery and reporting](docs/10-ERROR-RECOVERY-AND-REPORTING.md)
11. [Testing and acceptance](docs/11-TESTING-AND-ACCEPTANCE.md)
12. [Implementation status and changelog](docs/12-IMPLEMENTATION-STATUS-AND-CHANGELOG.md)
13. [X280 hardware baseline](docs/13-X280-HARDWARE-BASELINE.md)
14. [Stage 8 — native block-device access design](docs/14-STAGE-8-NATIVE-DEVICE-ACCESS.md)
15. [Repository audit](docs/15-REPOSITORY-AUDIT.md)

Operational target values are stored in `config/hardware/thinkpad-x280.conf`. Runtime inventory independently reads the running host. A profile match is not authorization to partition a disk.

## Storage safety boundary
- The approved installation scope is a full replacement of the internal SSD; Windows and recovery partitions are not retained.
- The target must be an internal NVMe disk. Removable devices and non-NVMe devices are rejected by the current target validator.
- Discovery requires `lsblk`, `jq`, `swapon`, `readlink`, and `base64`. Missing commands, failed discovery, unknown removable/read-only/mount state, active swap descendants, mounted descendants, or duplicate WWN/serial values cause rejection.
- The selected target is re-discovered before validation; its path, size, and every supplied stable identity field must still match.
- These checks are a conservative safety gate, not proof that a disk is safe to erase. PR #9 adds a separate installer that uses retained Bash descriptors and inherited `/proc/self/fd` paths; its disposable loop test covers selected utility interfaces, not every kernel race or physical NVMe behavior. The Stage 8 C helper remains a separate read-only prototype and is not integrated with the installer.

## Safety principles
- Never perform destructive disk operations without explicit authorization and verified target identification.
- Never bypass package signature or integrity verification.
- Never pipe remote scripts directly into a shell.
- Build AUR packages as an unprivileged user.
- Never log passwords, encryption keys, tokens, or credentials.
- Report untested behavior honestly.
- Latest `main` execution is the chosen update policy, but it carries a supply-chain risk: show the resolved SHA and review retrieved code before production use.

## Live validation on the ThinkPad

Two distinct read-only checks are available. `bash scripts/live-validation.sh` collects broad host/storage diagnostics and runs local quality checks plus the canonical test suite. `bash scripts/validate-live-storage.sh` verifies UEFI mode, matches the configured X280 SSD model/serial, and runs the repository's live storage target/topology validator. Both are intended to be read-only; neither authorizes disk erasure. The second script has not yet been executed on the physical X280, and its success must not be inferred from screenshots of raw system commands. Reports from `live-validation.sh` are local evidence, are not automatically committed, and must be reviewed before sharing. See [test documentation](tests/README.md#live-arch-iso--thinkpad-validation).

## Development status
See [implementation status and changelog](docs/12-IMPLEMENTATION-STATUS-AND-CHANGELOG.md).

## License
See [LICENSE](LICENSE).
