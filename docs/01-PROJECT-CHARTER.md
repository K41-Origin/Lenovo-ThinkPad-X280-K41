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
The project may need both an ISO-based installer and a post-install setup tool. Decide that boundary before implementation; a post-install script alone cannot install Arch onto a blank disk.

## Status vocabulary
- PLANNED: proposed, not implemented.
- APPROVED: user-approved requirement or decision.
- IMPLEMENTED: code or documentation exists.
- TESTED: a specified test was run.
- VERIFIED: behavior was confirmed with evidence.
- RELEASED: included in a designated release.

## Initial state
This is a documentation foundation. Described features are not thereby implemented or tested.
