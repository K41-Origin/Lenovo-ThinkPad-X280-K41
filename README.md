# Lenovo-ThinkPad-X280-K41

A personal, modular, security-conscious Arch Linux installation and setup project for the Lenovo ThinkPad X280.

> **Project status:** the entry point supports `--help` and diagnostic-only `--preflight`. Installer orchestration and installation logic are not implemented. Read-only storage discovery/target validation and fixture tests are implemented; destructive storage execution remains unimplemented. No real disk has been modified.

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

- `installer` — diagnostic-only entry point with `--help` and `--preflight`; it always exits nonzero after preflight because installation is disabled.
- `config/hardware/thinkpad-x280.conf` — executable target profile for the project laptop (planning data, never runtime detection or disk-selection authority).
- `lib/inventory.sh` — read-only runtime host discovery and comparison against the target profile.\n- `lib/storage.sh` — read-only whole-disk discovery and target revalidation; no partition/format/mount operations.
- `lib/` — focused internal modules for preflight, storage, base system, bootloader, user setup, desktop, hardware, packages, security, validation, and reporting.
- `tests/` — test strategy and future isolated test coverage.
- `docs/` — project requirements, decisions, architecture, safety, and status.

## Intended workflow
1. Boot the official Arch Linux ISO from USB.
2. Connect to the network and run the documented bootstrap procedure from the ISO shell.
3. Retrieve the repository's latest `main` branch using Git and display the resolved commit SHA.
4. Review the resolved commit and all relevant shell code before executing any project code; stop if its source, integrity, or effects cannot be understood. See the manual bootstrap review procedure in [Architecture and modules](docs/03-ARCHITECTURE-AND-MODULES.md#manual-bootstrap-and-pre-execution-review).
5. Run diagnostic preflight checks. A complete installation plan is not implemented yet.
6. Require explicit confirmation of the identified target disk before destructive storage operations.
7. Install and configure the base system, desktop, and selected software in one interactive flow.
8. Validate outcomes and create `AFTER-INSTALL-X280-K41.txt`.

**Important:** the current repository does not yet implement installation. `./installer --preflight` is read-only diagnostics only and deliberately does not return success; do not treat it as approval to install.

## Documentation index
1. [Project charter](docs/01-PROJECT-CHARTER.md) — scope, goals, principles, and status vocabulary.
2. [Requirements and decisions](docs/02-REQUIREMENTS-AND-DECISIONS.md) — requirement IDs and approved planning choices.
3. [Architecture and modules](docs/03-ARCHITECTURE-AND-MODULES.md) — proposed layers and architecture gates.
4. [Installation and disk](docs/04-INSTALLATION-AND-DISK.md) — storage, encryption, boot, destructive-operation safety.
5. [Security and authentication](docs/05-SECURITY-AND-AUTHENTICATION.md) — account model, logs, firewall, package integrity.
6. [Desktop and user experience](docs/06-DESKTOP-AND-USER-EXPERIENCE.md) — session, shell, utilities, and interaction.
7. [Hardware, power, and network](docs/07-HARDWARE-POWER-AND-NETWORK.md) — hardware discovery, power policy, networking.
8. [Package and software management](docs/08-PACKAGE-AND-SOFTWARE-MANAGEMENT.md) — repositories, updates, AUR, BlackArch, tool policy.
9. [Development and bug bounty](docs/09-DEVELOPMENT-AND-BUG-BOUNTY.md) — developer tools and optional services.
10. [Error recovery and reporting](docs/10-ERROR-RECOVERY-AND-REPORTING.md) — failures, interruption, diagnostics, final report.
11. [Testing and acceptance](docs/11-TESTING-AND-ACCEPTANCE.md) — test strategy and release gates.
12. [Implementation status and changelog](docs/12-IMPLEMENTATION-STATUS-AND-CHANGELOG.md) — evidence-based status and history.
13. [X280 hardware baseline](docs/13-X280-HARDWARE-BASELINE.md) — owner-reported device specifications, evidence quality, and Linux verification checklist.

The operational target values are stored in `config/hardware/thinkpad-x280.conf`. `lib/inventory.sh` independently reads the running host and compares only facts it can actually observe. A profile match is not authorization to partition a disk.

## Safety principles
- Never perform destructive disk operations without explicit authorization and verified target identification.
- Never bypass package signature or integrity verification.
- Never pipe remote scripts directly into a shell.
- Build AUR packages as an unprivileged user.
- Never log passwords, encryption keys, tokens, or credentials.
- Report untested behavior honestly.
- Latest `main` execution is the chosen update policy, but it carries a supply-chain risk: a new commit may change privileged code. Show the resolved SHA and review the retrieved code before any production use.

## Development status
See [implementation status and changelog](docs/12-IMPLEMENTATION-STATUS-AND-CHANGELOG.md). The structure exists, but technical architecture, upstream compatibility, and installer behavior remain unfinished.

## License
See [LICENSE](LICENSE).
