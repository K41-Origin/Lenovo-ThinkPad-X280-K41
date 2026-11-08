# Lenovo-ThinkPad-X280-K41

A personal, modular, security-conscious Arch Linux installation and setup project for the Lenovo ThinkPad X280.

> **Project status (2026-11-09):** The encrypted Arch base installer and Arch ISO bootstrap are IMPLEMENTED. The physical First Boot report records 14 PASS, 0 FAIL, and 0 SKIP. The separate post-install Hyprland/Caelestia setup is IMPLEMENTED; the latest physical setup report (reports/desktop/20261108T190308Z/) records exit status 0. The recursive AUR dependency resolver is implemented, including .SRCINFO traversal, cycle and package/provider checks, per-recipe approval, and unprivileged builds. The latest desktop diagnostics confirm a running Hyprland session, Caelestia/Quickshell process, and working Caelestia IPC discovery. The ~/.cache ownership repair is VERIFIED, but cache creation after restarting Caelestia and the visual/interactive desktop checklist remain NOT TESTED. Bluetooth/BlueZ is unavailable in the captured environment. Hardware tuning, hibernation/resume, and selective BlackArch integration remain PLANNED.

## AI-assisted development

Repository-wide AI contribution rules are defined in [`AGENTS.md`](AGENTS.md). AI-assisted changes must follow those rules and verify repository writes and relevant tests before reporting completion.

## Goals
- One interactive installer launched from the shell of an official, unmodified Arch Linux ISO booted from USB.
- Retrieve the latest code from the repository's `main` branch, display the resolved commit SHA, and review relevant shell code before invoking the installer.
- Carefully verified encrypted ext4 system with swapfile and future hibernation readiness.
- Hyprland with Caelestia Shell / Quickshell, subject to verified upstream compatibility.
- ThinkPad hardware, power, and network configuration based on actual device inventory.
- Optional AUR workflow and selective BlackArch integration.
- Safe recovery, testable modules, and honest post-install reporting.

## Current repository structure

- `installer` — diagnostic-only entry point with `--help` and `--preflight`.
- `scripts/bootstrap-archiso.sh` — reviewed Arch ISO bootstrap that fetches latest `main`, displays its commit SHA, and requires source review, a passing read-only live-readiness gate, and a second exact acknowledgement before launching the destructive installer.
- `scripts/install-arch-x280.sh` — initial destructive encrypted Arch base installer; physical installer and First Boot acceptance are recorded separately.
- `scripts/audit-x280-hardware.sh` — read-only hardware, battery, thermal, graphics, network, and power-service inventory; reports are private and must be reviewed before sharing.\n- `scripts/audit-x280-power-management.sh` — focused read-only baseline for CPU frequency policy, EPP, Intel pstate, platform profile, AC/battery state, and power services.
- `scripts/set-x280-power-profile.sh` — explicit, reversible Power Profiles D-Bus selector for controlled power-saver/balanced comparison; no automatic tuning.
- `scripts/setup-desktop-x280.sh` — separate post-install Hyprland/Quickshell setup; delegates recursive Caelestia AUR dependency resolution to `lib/aur-dependency-resolver.sh` and requires per-recipe approval; setup exit is PASS; physical UI acceptance remains incomplete.
- `lib/aur-dependency-resolver.sh` — recursive required/make dependency traversal from AUR `.SRCINFO`, cycle detection, package/provider identity checks, explicit Material You v3 compatibility mapping, and unprivileged reviewed builds.
- `config/hardware/thinkpad-x280.conf` — declarative target profile, never disk-selection authority.
- `lib/inventory.sh` — read-only runtime host discovery and profile comparison.
- `lib/storage.sh` — read-only whole-disk discovery and fresh target validation; no partition/format/mount operations.
- `lib/storage-plan.sh`, `lib/storage-prerequisites.sh`, and `lib/storage-confirmation.sh` — target-bound storage planning, read-only prerequisite evidence, explicit confirmation, and final revalidation.
- `lib/storage-execution-dry-run.sh` — in-memory operation manifest and failure simulator.
- `lib/storage-execution-boundary.sh` — mock-only execution orchestration with per-operation identity probes and partial-failure ledger; it does not open or lock a real block device.
- `native/storage-handle.c` and `docs/14-STAGE-8-NATIVE-DEVICE-ACCESS.md` — Stage 8 read-only native descriptor-holder prototype and its canonical design/limitations; hardware behavior and executor integration remain unverified.
- `lib/base-system.sh` — guarded `pacstrap -K` base package installation and UUID-based fstab generation for an already mounted target. Desktop setup, validation, and reporting are implemented in separate modules. Hardware tuning remains PLANNED.
- `tests/run.sh` — canonical fixture-based test runner; `tests/helpers/` contains shared test-only fixtures. Test dependencies are `bash`, `jq`, and `python3`.
- `scripts/k41-live-validation.sh` — canonical read-only Live Validation entry point; combines strict Arch ISO/X280 readiness, host diagnostics, static analysis, tests, SSD identity/topology validation, installer diagnostics, and timestamped evidence.
- `scripts/x280-install-readiness.sh` and `scripts/live-validation.sh` — backward-compatible wrappers; both delegate to the canonical validator without duplicate implementations.
- `docs/` — project requirements, decisions, architecture, safety, and status.

## Intended workflow
1. Boot the official Arch Linux ISO from USB.
2. Connect to the network.
3. Obtain and independently review `scripts/bootstrap-archiso.sh` from the repository before executing it; follow [Arch ISO bootstrap and source-review gate](docs/16-ARCHISO-BOOTSTRAP.md).
4. Run the bootstrap from the official ISO shell. It fetches latest `main`, displays the resolved commit SHA, pages through relevant source files, requires an exact SHA-bound acknowledgement, runs the read-only readiness gate, and requires a second exact acknowledgement before launching the installer.
5. After readiness passes, inspect the installer’s target-specific storage plan, verify the exact internal SSD identity and backup/recovery arrangements, and only then enter the exact plan-bound confirmation. This is the point at which the selected SSD is erased.
6. The current initial installer configures an encrypted base Arch system only; desktop and optional components are not included.
7. Validate outcomes and create `AFTER-INSTALL-X280-K41.txt`.

**Installer trial-reset policy:** after a failed destructive Arch installation trial, preserve its evidence, reboot into the official Arch ISO, and restart the full installer from its first stage. Do not use the legacy continuation utility. Each fresh installer trial is destructive and requires exact target revalidation and explicit confirmation. This policy does not apply to post-install desktop setup or diagnostic retries; those do not require reinstalling Arch.

**Important:** `./installer --preflight` is read-only and is not the destructive installer. `scripts/install-arch-x280.sh` is destructive. A successful installer exit and generated UKI do not prove that the physical laptop boots successfully.

## Documentation index

- [Repository map and source-of-truth guide](docs/00-REPOSITORY-MAP-AND-SOURCE-OF-TRUTH.md) — connects requirements, canonical docs, scripts, libraries, tests, CI, and evidence artifacts.

### Project design and policy
- [Project charter](docs/01-PROJECT-CHARTER.md)
- [Requirements and decisions](docs/02-REQUIREMENTS-AND-DECISIONS.md)
- [Architecture and modules](docs/03-ARCHITECTURE-AND-MODULES.md)
- [Installation and disk](docs/04-INSTALLATION-AND-DISK.md)
- [Platform, security, and software policy](docs/05-PLATFORM-SECURITY-AND-SOFTWARE.md)

### Operations and verification
- [Error recovery and reporting](docs/10-ERROR-RECOVERY-AND-REPORTING.md)
- [Testing and acceptance](docs/11-TESTING-AND-ACCEPTANCE.md)
- [Implementation status and changelog](docs/12-IMPLEMENTATION-STATUS-AND-CHANGELOG.md)
- [X280 hardware baseline](docs/13-X280-HARDWARE-BASELINE.md)

### Implementation and operator references
- [Stage 8 — native block-device access design](docs/14-STAGE-8-NATIVE-DEVICE-ACCESS.md)
- [Stage 9 — initial interactive Arch installer](docs/15-ARCH-INSTALLER-INITIAL-EXECUTION.md)
- [Arch ISO bootstrap and source-review gate](docs/16-ARCHISO-BOOTSTRAP.md)
- [X280 first-boot test and evidence collection](docs/17-X280-FIRST-BOOT-TEST.md)
- [X280 desktop environment physical test](docs/19-X280-DESKTOP-TEST.md)
- [X280 desktop customization](docs/22-X280-DESKTOP-CUSTOMIZATION.md)
- [X280 hardware audit procedure](docs/20-X280-HARDWARE-AUDIT.md)\n- [X280 power-management baseline audit](docs/21-X280-POWER-MANAGEMENT-AUDIT.md)

### Historical record
- [Historical repository audit (2026-11-07)](docs/18-REPOSITORY-AUDIT-HISTORICAL.md)
- [Historical testing and acceptance record](docs/archive/11-TESTING-AND-ACCEPTANCE-HISTORY-2026-11-08.md)
- [Historical implementation changelog](docs/archive/12-IMPLEMENTATION-CHANGELOG-HISTORY-2026-11-08.md)

Operational target values are stored in `config/hardware/thinkpad-x280.conf`. Runtime inventory independently reads the running host. A profile match is not authorization to partition a disk.

## Storage safety boundary
- The approved installation scope is a full replacement of the internal SSD; Windows and recovery partitions are not retained. Full destructive installation validation is reserved for the actual ThinkPad X280; VM-based installation testing is excluded.
- The target must be an internal NVMe disk. Removable devices and non-NVMe devices are rejected by the current target validator.
- Discovery requires `lsblk`, `jq`, `swapon`, `readlink`, and `base64`. Missing commands, failed discovery, unknown removable/read-only/mount state, active swap descendants, mounted descendants, or duplicate WWN/serial values cause rejection.
- The selected target is re-discovered before validation; its path, size, and every supplied stable identity field must still match.
- These checks are a conservative safety gate, not proof that a disk is safe to erase. The initial installer uses retained Bash descriptors and inherited `/proc/self/fd` paths; its disposable loop test covers selected utility interfaces, not every kernel race or physical NVMe behavior. The Stage 8 C helper remains a separate read-only prototype and is not integrated with the installer.

## Validation policy

VM-based installer testing is explicitly out of scope (REQ-INSTALL-006). Automated checks may use fixtures, mocks, and disposable loop-backed images for bounded component coverage. The destructive full-SSD replacement workflow is intentionally retained: end-to-end installation and first-boot validation must take place on the actual ThinkPad X280 after the physical-test gates, recovery preparation, and explicit authorization are complete. This policy does not authorize running the installer now.

## Safety principles
- Never perform destructive disk operations without explicit authorization and verified target identification.
- Never bypass package signature or integrity verification.
- Never pipe remote scripts directly into a shell.
- Build AUR packages as an unprivileged user.
- Never log passwords, encryption keys, tokens, or credentials.
- Report untested behavior honestly.
- Latest `main` execution is the chosen update policy, but it carries a supply-chain risk: show the resolved SHA and review retrieved code before production use.

## Live validation and installation readiness on the ThinkPad

Run the canonical strict gate from the official Arch ISO as root:

```bash
bash scripts/k41-live-validation.sh --readiness
```

The canonical validator creates a timestamped readiness report under `reports/live-readiness/<UTC timestamp>/` (`summary.md` and serial-redacted `diagnostics.log`) and a detailed host report under `reports/live-validation/<UTC timestamp>.md`, updating `reports/live-validation/latest.md`. The supplemental `scripts/x280-archiso-test.sh` log is stored under `reports/x280-archiso-test/<UTC timestamp>/`. It records repository identity, host/boot/DMI/storage/network diagnostics, Bash syntax, ShellCheck and shfmt when installed, the canonical test suite, target-specific read-only SSD identity/topology, and installer diagnostics. The readiness gate checks root, Arch Linux, UEFI, ThinkPad X280 DMI identity, and required commands. Reports are local evidence; review them before sharing or committing. Neither PASS nor a report authorizes disk erasure.

The previous entry points remain available as compatibility wrappers:
- `bash scripts/x280-install-readiness.sh` delegates to `--readiness`.
- `bash scripts/live-validation.sh` delegates to `--diagnostics-only`, preserving broad diagnostics on a checked-out host without requiring the Arch ISO readiness conditions.
- `bash scripts/validate-live-storage.sh` remains the focused read-only SSD identity/topology validator used by strict readiness.

All paths are read-only. They do not partition, format, open LUKS, mount, install packages, change services/firmware, or write to block devices. See [test documentation](tests/README.md#live-arch-iso--x280-validation).

## Documentation ownership
Each topic has one canonical owner: requirements/decisions in `docs/02`, architecture/module boundaries in `docs/03`, storage and boot details in `docs/04`, platform/security/software policy in `docs/05`, test procedures in `tests/README.md`, acceptance/evidence boundaries in `docs/11`, and current implementation/CI status in `docs/12`. Stage records (`docs/14` and `docs/15-ARCH...`) document their specific implementation only. The historical repository audit (`docs/18-REPOSITORY-AUDIT-HISTORICAL.md`) records a dated review snapshot; it is not current status or a second source of technical procedures.

## Development status
See [implementation status and changelog](docs/12-IMPLEMENTATION-STATUS-AND-CHANGELOG.md).

## License
See [LICENSE](LICENSE).


## Approved project execution order

The active work sequence is:

1. **Desktop functional validation** — complete physical and automated acceptance of Hyprland, Caelestia/Quickshell, display, input, audio, networking, portals, locking, and session recovery.
2. **Desktop customization** — create the polished, minimal, refined monochromatic visual identity described in [Desktop Customization](docs/22-X280-DESKTOP-CUSTOMIZATION.md).
3. **Optional software integration** — review and implement only explicitly selected optional components, including selective BlackArch tools if still required.
4. **Final hardware and system customization** — defer X280 performance, thermal, power/battery, suspend/hibernate/resume, and extended stability work until the final project stage.

Do not start a later stage until the preceding stage's acceptance criteria are met. Battery and power-profile experimentation is not an active priority. This is a sequencing decision, not a claim that deferred work is complete.
