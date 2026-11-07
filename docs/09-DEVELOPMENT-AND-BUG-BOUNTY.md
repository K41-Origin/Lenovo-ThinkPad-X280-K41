# Development and Bug Bounty

## Goal and boundary

Provide a minimal development and web-application-security environment after the base operating system and desktop are verified. Do not silently install a large tool bundle or launch security scans.

## Package ownership

The canonical package allowlist, package-source policy, AUR workflow, optional BlackArch integration, and excluded applications are owned by [Package and Software Management](08-PACKAGE-AND-SOFTWARE-MANAGEMENT.md). This document does not repeat package names or installation procedures.

Firefox is the preferred browser and Bitwarden is the preferred password manager, subject to source verification and manual sign-in. Do not install browser extensions, change default-app associations, or create project/work directories without explicit approval.

## Authorized use

Use security tools only on systems and applications the user owns or is explicitly authorized to test. The installer must not silently launch scans, exploit checks, or network probes against third-party targets.

## Acceptance

- [ ] Tool sources and versions follow the package policy.
- [ ] Credentials, tokens, cookies, and recovery material are never logged.
- [ ] Optional services remain disabled/unconfigured until approved.
- [ ] No unrequested tools, browser extensions, or project directories are created.
- [ ] No scan or test is launched without an authorized target and explicit user intent.
