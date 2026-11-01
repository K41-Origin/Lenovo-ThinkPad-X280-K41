# Requirements and Decision Log

This document indexes approved planning decisions. Domain details live in the relevant document; avoid conflicting duplication.

## Installation and storage
- REQ-INSTALL-001 — APPROVED: Official, unmodified Arch ISO from USB; interactive TUI; minimize typing.
- REQ-DISK-001 — APPROVED: Replace Windows; user reports no data to retain.
- REQ-DISK-002 — APPROVED: LUKS, ext4, swapfile, and hibernation readiness; size/layout based on verified constraints.
- REQ-DISK-003 — APPROVED: Show full disk plan and verify target identity before destructive work; require explicit final confirmation.
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
Actual hardware and wireless chipset; current Caelestia/Quickshell/Hyprland dependencies; bootloader and encrypted-root/resume design; package availability; encrypted DNS implementation; service compatibility; and final module boundaries.

## Change process
When a decision changes, update its ID and owning domain document together, recording rationale and evidence. Do not mark anything implemented, tested, verified, or released without evidence.
