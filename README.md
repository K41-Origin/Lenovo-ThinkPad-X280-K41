# Lenovo-ThinkPad-X280-K41

A planned, modular, security-conscious Arch Linux installation and setup project for the Lenovo ThinkPad X280.

> **Project status:** planning and documentation foundation. The installer is not implemented. Describing a feature does not mean it exists or has been tested.

## Goals
- Interactive installation from an official, unmodified Arch Linux ISO.
- Carefully verified encrypted ext4 system with swapfile and hibernation readiness.
- Hyprland with Caelestia Shell / Quickshell, subject to verified upstream compatibility.
- ThinkPad hardware, power, and network configuration based on actual device inventory.
- Optional AUR workflow and selective BlackArch integration.
- Safe recovery, testable modules, and honest post-install reporting.

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

## Safety principles
- Inspect repository state before modifying existing work.
- Never perform destructive disk operations without explicit authorization and verified target identification.
- Never bypass package signature or integrity verification.
- Never pipe remote scripts directly into a shell.
- Build AUR packages as an unprivileged user.
- Never log passwords, encryption keys, tokens, or credentials.
- Report untested behavior honestly.

## Development status
See [implementation status and changelog](docs/12-IMPLEMENTATION-STATUS-AND-CHANGELOG.md). Technical architecture and upstream compatibility must be verified before installer implementation.

## License
See [LICENSE](LICENSE).
