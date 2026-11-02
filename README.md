# Lenovo-ThinkPad-X280-K41

A personal, modular, security-conscious Arch Linux installation and setup project for the Lenovo ThinkPad X280.

> **Project status:** the entry point supports `--help` and diagnostic-only `--preflight`. Installer orchestration and installation logic are not implemented. Read-only storage discovery and target revalidation are implemented with fixture tests; destructive storage execution remains unimplemented. No real disk has been modified.

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

- `installer` — diagnostic-only entry point with `--help` and `--preflight`; installation remains disabled.
- `config/hardware/thinkpad-x280.conf` — declarative target profile, never disk-selection authority.
- `lib/inventory.sh` — read-only runtime host discovery and profile comparison.
- `lib/storage.sh` — read-only whole-disk discovery and fresh target validation; no partition/format/mount operations.
- `lib/` — focused internal modules for preflight, storage, base system, bootloader, user setup, desktop, hardware, packages, security, validation, and reporting.
- `tests/` — test strategy and isolated fixture tests.
- `docs/` — project requirements, decisions, architecture, safety, and status.

## Intended workflow
1. Boot the official Arch Linux ISO from USB.
2. Connect to the network and run the documented bootstrap procedure from the ISO shell.
3. Retrieve the repository's latest `main` branch using Git and display the resolved commit SHA.
4. Review the resolved commit and all relevant shell code before executing any project code; stop if its source, integrity, or effects cannot be understood. See [manual bootstrap review](docs/03-ARCHITECTURE-AND-MODULES.md#manual-bootstrap-and-pre-execution-review).
5. Run diagnostic preflight checks. A complete installation plan is not implemented yet.
6. Require explicit confirmation of the identified internal NVMe target before destructive storage operations.
7. Install and configure the base system, desktop, and selected software in one interactive flow.
8. Validate outcomes and create `AFTER-INSTALL-X280-K41.txt`.

**Important:** the current repository does not implement installation. `./installer --preflight` is read-only diagnostics only and deliberately does not return success; do not treat it as approval to install.

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

Operational target values are stored in `config/hardware/thinkpad-x280.conf`. Runtime inventory independently reads the running host. A profile match is not authorization to partition a disk.

## Storage safety boundary
- The approved installation scope is a full replacement of the internal SSD; Windows and recovery partitions are not retained.
- The target must be an internal NVMe disk. Removable devices and non-NVMe devices are rejected by the current target validator.
- Discovery requires `lsblk`, `jq`, `swapon`, `readlink`, and `base64`. Missing commands, failed discovery, unknown removable/read-only/mount state, active swap descendants, mounted descendants, or duplicate WWN/serial values cause rejection.
- The selected target is re-discovered before validation; its path, size, and every supplied stable identity field must still match.
- These checks are a conservative safety gate, not proof that a disk is safe to erase. The storage module performs no destructive operation.

## Safety principles
- Never perform destructive disk operations without explicit authorization and verified target identification.
- Never bypass package signature or integrity verification.
- Never pipe remote scripts directly into a shell.
- Build AUR packages as an unprivileged user.
- Never log passwords, encryption keys, tokens, or credentials.
- Report untested behavior honestly.
- Latest `main` execution is the chosen update policy, but it carries a supply-chain risk: show the resolved SHA and review retrieved code before production use.

## Development status
See [implementation status and changelog](docs/12-IMPLEMENTATION-STATUS-AND-CHANGELOG.md).

## License
See [LICENSE](LICENSE).
