# Requirements and Decision Log

This document indexes approved planning decisions. Domain details live in the relevant document; avoid conflicting duplication.

## Installer architecture
- REQ-INSTALL-001 — APPROVED: Boot an official, unmodified Arch Linux ISO from USB; run the project's own installer from the ISO shell; use one interactive flow from base installation through desktop configuration.
- REQ-INSTALL-002 — APPROVED: Keep the implementation modular internally; one entry point coordinates focused modules.
- REQ-INSTALL-003 — APPROVED: Retrieve the latest repository code from `main` for each installation attempt. Display the resolved commit SHA so the version used is identifiable.
- REQ-INSTALL-004 — APPROVED: Do not pipe remote scripts directly into a shell. Bootstrap must retrieve code with Git and invoke the project entry point explicitly.
- REQ-INSTALL-005 — APPROVED: Read-only preflight, disk discovery, and storage-plan preparation/review may run before confirmation. No installation step that depends on the target disk, and no destructive storage action, may proceed until prerequisites pass, the complete plan for the identified target is displayed, and the user explicitly confirms that target and plan.

## Installation and storage
- REQ-DISK-001 — APPROVED: Replace Windows; user reports no data to retain.
- REQ-DISK-002 — APPROVED: LUKS, ext4, swapfile, and hibernation readiness; size/layout based on verified constraints.
- REQ-DISK-003 — APPROVED: Show full disk plan and verify target identity before destructive work; require explicit final confirmation.
  - Acceptance criteria (specified; not yet implemented or tested):
    1. Before any destructive storage action, identify the selected disk using available stable identity details and show the user which physical device is targeted; a transient device path alone must not resolve an ambiguous identity.
    2. Display the complete proposed storage plan for that target, including partition layout, encryption, filesystems, and swap/resume-related choices, before asking for final confirmation.
    3. Require an explicit confirmation tied to the displayed target and plan. Cancellation or any failed prerequisite must stop before destructive actions.
    4. If the target cannot be identified unambiguously, the plan is incomplete, or the target identity no longer matches at execution time, abort without making destructive changes.
    5. Keep plan review, target validation, confirmation, execution, and post-operation verification as distinct stages so each can be tested independently.
  - Traceability: REQ-INSTALL-005 (global execution gate); REQ-DISK-002 (storage/encryption/swap design); REQ-DISK-006 (bootloader compatibility and stop condition); REQ-RECOVERY-001 (safe behavior after interruption); see Architecture and Modules and Testing and Acceptance for module boundaries and verification strategy.
- REQ-DISK-004 — APPROVED: One standard Arch linux kernel.
- REQ-DISK-005 — APPROVED: Actual hibernation test is manual; readiness is not proof of successful resume.
- REQ-DISK-006 — APPROVED: Verify bootloader compatibility with UEFI, LUKS, ext4, and resume; stop before destructive work if no safe plan exists.

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
Actual hardware and wireless chipset; current Caelestia/Quickshell/Hyprland dependencies; bootloader and encrypted-root/resume design; package availability; encrypted DNS implementation; service compatibility; module contracts; and acceptance tests.

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
