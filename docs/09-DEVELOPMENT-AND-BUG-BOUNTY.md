# Development and Bug Bounty

## Goal
Provide a minimal development and web-application-security environment without silently installing a large tool bundle.

## Browser and credentials
Firefox is the primary browser. Do not install extensions or alter default-app associations automatically. Bitwarden is preferred; verify its package source and let the user sign in manually. Never log credentials, tokens, cookies, or recovery material.

## Requested development tools
Verify current official package names and availability: Git and GitHub CLI with manual authentication; ShellCheck and shfmt; Python 3 and pip; Go; Node.js and npm with version verification; VS Code open-source build from official Arch repositories if available, without silent source substitution.

## Optional services and excluded tools
Podman and Podman Compose may be installed if trusted/verified but must not be configured automatically. Cockpit may be installed if trusted/verified but must not be enabled automatically; localhost-only binding requires verified configuration. Do not install Burp Suite Community, OWASP ZAP, or Docker by default. Do not automatically create ~/Projects, ~/BugBounty, or ~/Tools. Avoid excluded utilities listed in the package policy.

## Authorized use
Use security tools only on systems and applications the user owns or is explicitly authorized to test. The installer should not silently launch scans.

## Acceptance
- [ ] Sources and versions visible.
- [ ] No credentials in logs.
- [ ] Optional services remain disabled/unconfigured until approved.
- [ ] No unrequested tools or directories created.
