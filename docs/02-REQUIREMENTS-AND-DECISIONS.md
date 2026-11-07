# Requirements and Decision Log

This document indexes approved planning decisions. Domain details live in the relevant document; avoid conflicting duplication.

## Installer architecture
- REQ-INSTALL-001 — APPROVED: Boot an official, unmodified Arch Linux ISO from USB; run the project's own installer from the ISO shell; use one interactive flow from base installation through desktop configuration.
- REQ-INSTALL-002 — APPROVED: Keep the implementation modular internally; one entry point coordinates focused modules.
- REQ-INSTALL-003 — APPROVED: Retrieve the latest repository code from `main` for each installation attempt. Display the resolved commit SHA so the version used is identifiable.
- REQ-INSTALL-004 — APPROVED: Do not pipe remote scripts directly into a shell. Bootstrap must retrieve code with Git and invoke the project entry point explicitly.
- REQ-INSTALL-005 — APPROVED: Read-only preflight, disk discovery, and storage-plan preparation/review may run before confirmation. No installation step that depends on the target disk, and no destructive storage action, may proceed until prerequisites pass, the complete plan for the identified target is displayed, and the user explicitly confirms that target and plan.

## Installation and storage
- REQ-DISK-001 — APPROVED: Replace Windows; the user reports no data to retain. This does not waive target identification or explicit confirmation.
- REQ-DISK-002 — APPROVED: Use LUKS2, ext4, and an encrypted-root swapfile; derive layout and swap sizing from verified runtime constraints. Hibernation readiness requires a verified resume configuration and remains distinct from a successful hardware resume test.
- REQ-DISK-003 — APPROVED: Identify the target, display its complete target-specific storage plan, and require explicit final confirmation before destructive work. Acceptance criteria and test mapping are owned by [Testing and Acceptance](11-TESTING-AND-ACCEPTANCE.md); detailed layout and safety procedure are owned by [Installation and Disk](04-INSTALLATION-AND-DISK.md).
- REQ-DISK-004 — APPROVED: Use one standard Arch `linux` kernel.
- REQ-DISK-005 — APPROVED: Actual hibernation/resume testing is manual; design readiness is not proof of successful resume.
- REQ-DISK-006 — APPROVED: Verify bootloader compatibility with UEFI, LUKS, ext4, and resume; stop before destructive work if no safe plan exists.
- DESIGN-STORAGE-001 — APPROVED: UEFI/GPT; one 1 GiB FAT32 ESP mounted at `/efi`; systemd-boot; one LUKS2 root container with ext4 directly on the unlocked mapper; encrypted-root swapfile; no LVM unless a verified requirement emerges.
- DESIGN-BOOT-001 — APPROVED: Official Arch `linux` kernel; mkinitcpio-native UKI under `/efi/EFI/Linux/`; systemd-boot discovers the UKI; source kernel and mkinitcpio configuration remain under `/boot` on encrypted root; one required default UKI and no required fallback UKI in the initial design; Secure Boot remains disabled. Exact hooks, kernel command line, package-update integration, and failure behavior require upstream verification and tests before implementation.
- DESIGN-HIBERNATION-001 — APPROVED DIRECTION: Keep swapfile inside encrypted ext4 root. Determine size from measured RAM, available capacity, and hibernation requirements. Use the unlocked mapper as resume device and calculate the actual ext4 swapfile physical offset; keep it synchronized whenever the file is recreated or relocated. Actual hibernate/resume remains NOT TESTED until exercised on the target hardware.

These decisions define the approved direction, not a finalized target-specific partition table, verified compatibility, or authorization to erase a disk. See [Installation and Disk](04-INSTALLATION-AND-DISK.md) for the canonical technical treatment and [Testing and Acceptance](11-TESTING-AND-ACCEPTANCE.md) for acceptance criteria.
## Security and authentication
- REQ-SEC-001 — APPROVED: Disable direct root login; use normal account and sudo.
- REQ-SEC-002 — APPROVED: LUKS passphrase at boot and account password at TTY login unless secure compatible integration is verified.
- REQ-SEC-003 — APPROVED: Never log passwords, recovery keys, tokens, or credentials.
- REQ-SEC-004 — APPROVED: Explain important security changes and obtain approval where specified.
- REQ-SEC-005 — APPROVED: Never disable package signature/integrity verification.
- REQ-SEC-006 — APPROVED: Secure Boot planned disabled; detect mode and explain mismatches.
- REQ-SEC-007 — APPROVED: No SSH server by default.
- REQ-SEC-008 — APPROVED: Do not activate firewall before approval; firewalld/Public zone is a candidate for review.

## Desktop, hardware, network
- REQ-DESKTOP-001 — APPROVED: TTY login then automatic desktop launch only after integration is verified.
- REQ-DESKTOP-002 — APPROVED: Dark theme, restrained animations, balanced performance and battery life.
- REQ-DESKTOP-003 — APPROVED: Minimal startup; avoid duplicate daemons.
- REQ-HW-001 — APPROVED: NetworkManager primary; Wi-Fi enabled by default.
- REQ-HW-002 — APPROVED: Bluetooth off by default, manually enabled.
- REQ-HW-003 — APPROVED: One compatible power-management approach.
- REQ-HW-004 — APPROVED: Firmware/kernel thermal control; no third-party fan controller.
- REQ-HW-005 — APPROVED: Suspend for short breaks and hibernate for longer idle, subject to safe verification.
- REQ-HW-006 — APPROVED: Do not automatically install Intel microcode; report the recommendation and leave installation to an explicit user decision.

## Packages and optional components
- REQ-PKG-001 — APPROVED: Weekly update checks and notifications only; no automatic installation.
- REQ-PKG-002 — APPROVED: Show package versions and sources; label AUR packages and ask before updates.
- REQ-PKG-003 — APPROVED: Prefer verified official repositories; no silent source substitution.
- REQ-AUR-001 — APPROVED: Interactive AUR review; build unprivileged; pause on suspicious changes.
- REQ-BLACKARCH-001 — APPROVED: Optional selected BlackArch tools, never the full collection or signature bypass.
- REQ-TOOLS-001 — APPROVED: Selective developer/bug-bounty tools per package policy.

## Reporting and recovery
- REQ-REPORT-001 — APPROVED: Generate AFTER-INSTALL-X280-K41.txt in English after health checks.
- REQ-REPORT-002 — APPROVED: Use VERIFIED, FAILED, NOT TESTED; exclude secrets.
- REQ-RECOVERY-001 — APPROVED: Inspect actual state after interruption; never automatically wipe again.
- REQ-RECOVERY-002 — APPROVED: Unknown critical failures stop for manual intervention.

## Verification still required
The following implementation details and evidence remain outstanding; their architectural direction may already be approved above:
- Linux-side verification of the owner-reported ThinkPad X280 baseline (recorded in `docs/13-X280-HARDWARE-BASELINE.md`), including exact wireless PCI/USB IDs and bound drivers.
- Current Caelestia/Quickshell/Hyprland dependencies and compatibility.
- systemd-boot and mkinitcpio UKI generation/update lifecycle, including ESP mount validation and preservation of the last known-good UKI.
- Exact `sd-encrypt` hook ordering, crypt device identification, kernel command line, and encrypted-root boot behavior.
- Swapfile sizing from the installed system, ext4 physical resume-offset calculation/maintenance, and an actual hibernate/resume test.
- Package availability; encrypted DNS implementation; service compatibility; module contracts; and acceptance tests.

## Requirement traceability and acceptance criteria

Use requirement IDs as stable references across design, implementation, tests, and reports. Keep the requirement statement concise here; record testable acceptance criteria under the owning requirement, and link related requirements rather than copying their full text.

Relationship labels:
- **Depends on**: this requirement cannot be safely satisfied until the referenced requirement/design is resolved.
- **Constrains**: this requirement imposes a safety or implementation limit on another requirement.
- **Verified by**: tests or review evidence that demonstrate the criterion; do not mark verified until evidence exists.
- **Related to**: shares a workflow or failure boundary, without implying that one requirement fully satisfies the other.

Initial traceability for storage safety:
- **REQ-INSTALL-005** depends on preflight and storage safety gates; it is the top-level gate that prevents installation logic from proceeding prematurely.
- **REQ-DISK-003** is verified by the storage-plan review, target-identity, cancellation, changed-target, and no-destructive-call tests listed in its acceptance criteria and in Testing and Acceptance.
- **REQ-DISK-002** constrains the storage plan's required design details; the exact layout must still be finalized from verified hardware and boot/resume compatibility.
- **REQ-DISK-006** constrains whether a safe storage/boot plan may proceed; unresolved compatibility must stop the flow before destructive work.
- **REQ-RECOVERY-001** governs restart/interruption behavior after a partial operation; it complements, but does not replace, pre-operation checks in REQ-DISK-003.

Traceability status is documentation-only at this stage. These links define intended relationships, not proof that code or tests exist or pass. When adding a requirement, update its owning domain, relationship links, acceptance criteria, and test mapping together. Avoid circular dependency claims; if a dependency cannot be resolved, record it as an open design question instead.

## Change process
When a decision changes, update its ID and owning domain document together, recording rationale and evidence. Do not mark anything implemented, tested, verified, or released without evidence.
