# Project Charter

## Purpose
Build a reliable, modular, secure, reproducible Arch Linux installation and setup system for the Lenovo ThinkPad X280.

## Target and goals
- Target hardware: ThinkPad X280; planning baseline is Intel Core i5-8250U, 8 GB RAM, 256 GB SSD, Intel UHD Graphics 620. Verify the actual machine before device-specific changes.
- OS: Arch Linux; desktop target: Hyprland with Caelestia Shell / Quickshell after upstream compatibility is verified.
- Priorities: aesthetics, performance, battery life, web application security and bug-bounty workflows.
- Optional: selected BlackArch tools, never the entire collection by default.

## Principles
1. Inspect repository state before modifying it.
2. Separate installation, post-install setup, optional components, hardware tuning, tests, and docs.
3. Require explicit authorization and verified disk identity before destructive operations.
4. Never bypass package signature checks or install unverified packages.
5. Never pipe remote scripts directly into a shell; never build AUR packages as root.
6. Never log secrets.
7. Distinguish implementation from test evidence.

## Scope
The approved initial direction is one interactive installer launched from the shell of an official Arch Linux ISO; see `docs/02-REQUIREMENTS-AND-DECISIONS.md` and `docs/03-ARCHITECTURE-AND-MODULES.md` for the authoritative decision and design details.

Whether to provide a separate post-install setup tool remains an open scope question and is not required by the current decision. A post-install script alone cannot install Arch onto a blank disk.

## Status vocabulary
This charter owns the project-status definitions used across the repository:
- PLANNED: proposed, not implemented.
- APPROVED: user-approved requirement or decision.
- IMPLEMENTED: code or documentation exists.
- TESTED: a specified test was run.
- VERIFIED: behavior was confirmed with evidence.
- RELEASED: included in a designated release.

Other documents must use these definitions rather than maintain competing definitions. AI workflow instructions in `AGENTS.md` may add evidence and reporting rules, but should refer here for the status meanings.

## Initial state
This is a documentation foundation. Described features are not thereby implemented or tested.
