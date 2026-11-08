# Platform, Security, and Software Policy

This document is the single policy owner for account security, desktop experience, hardware and power behavior, networking, package sources, developer tooling, and authorized security-testing workflows. Approved requirement IDs remain indexed in [Requirements and Decisions](02-REQUIREMENTS-AND-DECISIONS.md); implementation state belongs in [Implementation Status](12-IMPLEMENTATION-STATUS-AND-CHANGELOG.md).

## Security and authentication

### Accounts and login
- Disable direct root login; use a normal user and sudo.
- Require a LUKS passphrase at boot and a separate account password at TTY login unless secure compatible integration is verified.
- Launch the desktop after TTY login only after session integration is confirmed.
- Require authentication after suspend/hibernate and provide a manual lock shortcut.

### Secrets, firewall, and remote access
- Never log passwords, passphrases, LUKS recovery keys, tokens, cookies, or credentials.
- Firewall configuration must not activate before user approval. firewalld with Public-zone defaults is only a candidate pending compatibility review.
- Do not install or enable an SSH server by default.
- Explain material security changes and obtain approval where required.

### Network integrity and service hardening
- Use NetworkManager. Prefer encrypted DNS only with a verified implementation.
- If encrypted DNS fails, notify the user and wait for a manual decision; never silently fall back to plaintext DNS.
- Check DNS, HTTPS, and official Arch repository connectivity before package operations.
- Never disable package signature or integrity verification.
- Audit enabled services before applying systemd restrictions; apply restrictions only when compatibility is verified.
- Avoid duplicate daemons. USBGuard and AppArmor are not planned under current decisions.

### Secure Boot and microcode
- Secure Boot is planned disabled; detect actual mode and explain mismatches.
- Intel microcode is recommendation-only and must not be installed automatically (REQ-HW-006).

## Desktop experience

### Session and appearance
- Target Hyprland with Caelestia Shell / Quickshell, subject to verification of current upstream dependencies and compatibility.
- Use TTY login followed by desktop launch only after session integration is verified. No graphical login manager is planned.
- Prefer a dark theme, restrained animations, dynamic workspaces, and keyboard shortcuts.
- Three-finger gestures are conditional on verified hardware/software support.
- Keep startup minimal: only required desktop components, audio, network, notifications, and explicitly approved features.

### Utilities and privacy
- Prefer supported built-in Caelestia/Hyprland features. Verify dependencies before selecting alternatives.
- Target a power menu, battery and screenshot support where available, lightweight file manager, required Wayland screen-sharing portal, Wayland-compatible clipboard manager with history cleared at logout/reboot, notifications without duplicate daemons, and trusted ZIP/TAR/GZIP/7z/RAR support.
- Do not add a default PDF reader or unrequested startup applications.
- Firefox is the preferred browser; do not install extensions or change default-app associations automatically.
- Bitwarden is preferred, subject to source verification and manual sign-in.
- Do not create project/work directories automatically.

### Lid, suspend, and hibernation
- Suspend is the target for short breaks. Hibernate is a longer-idle option only after configuration and verification.
- A lid event alone cannot determine how long the laptop will remain idle.
- Authentication after resume must be checked. Hibernation readiness does not replace an actual hardware hibernate/resume test.

## Hardware, power, and network

### Hardware discovery and firmware
- Treat the owner-reported [X280 hardware baseline](13-X280-HARDWARE-BASELINE.md) as planning context, not runtime detection.
- Discover actual hardware and Wi-Fi/Bluetooth devices from the running Arch/Linux environment before device-specific changes. Never hard-code the reported baseline as disk-selection authority.
- Install official firmware only when required by detected hardware and basic functionality.
- Report Intel microcode as a recommendation; do not install it automatically.
- Use firmware/kernel thermal and fan control. Do not add third-party fan controllers or undocumented thermal tweaks.
- Monitor sensors only when supported.

### Power policy
- Target a fixed Balanced profile without automatic AC/battery switching.
- Use power-profiles-daemon only if compatible.
- Avoid competing power managers. Use one verified source of truth for power, suspend, hibernate, and lid actions.

### Network behavior
- NetworkManager is primary; Wi-Fi enabled by default.
- Bluetooth disabled by default and enabled manually.
- Before package installation, check DNS, HTTPS, and official Arch repository connectivity.
- Diagnose/retry recoverable failures. If disconnected beyond the planned five-minute recovery window, attempt reconnection for up to five minutes, then stop with instructions.
- After recovery, re-check connectivity and relevant integrity/status.
- Automatic time synchronization is not planned.

## Package and software management

### General policy and baseline tools
- Prefer verified official Arch repositories. Show package names, versions, and origins.
- Check updates weekly and notify only; never install automatically.
- Label AUR origin and ask before updates. Explain configuration migrations; mark unidentifiable changes unverified.
- Never silently substitute package sources or disable signature verification.
- Do not install `base-devel` automatically unless a verified workflow requires it.
- Verify current package names and availability before installation. Requested baseline tools include: curl, wget, bind (for `dig`), whois, Git, GitHub CLI (manual authentication; no tokens in logs), ShellCheck, shfmt, Python 3 and pip, Go, Node.js and npm (verify version rather than assuming LTS), and the open-source VS Code build from official Arch repositories if available.
- `nano` is included in the current minimal base package list; it is not part of the optional developer-tool bundle.
- Do not request OpenSSL as a separate application; allow it as a dependency when required.

### Not installed by default
The following remain optional, not default installations: fd, ripgrep, btop, mtr, httpie, Postman, pytest, pipx, and base-devel. Do not install Burp Suite Community, OWASP ZAP, or Docker by default. Podman/Podman Compose and Cockpit require source/compatibility verification and explicit opt-in; do not enable Cockpit automatically.

### AUR workflow
- No third-party AUR helper by default; use an interactive review workflow.
- Inspect PKGBUILD and related files, compare versions, and flag suspicious commands, network activity, privilege escalation, or system changes.
- Build as an unprivileged user, never root. Explain and confirm any separate privileged action.
- Review maintenance activity and warnings where available.
- On integrity failure, offer retry, diagnosis, or cancellation; never install unverified artifacts.

### Optional BlackArch
- No BlackArch tools by default.
- Use the official setup process and verify keyring/signatures.
- Select individual tools only; never install the entire collection.
- Verification failure must offer retry, diagnosis, or cancellation, never a bypass.

## Development and authorized security testing

Provide a minimal development and web-application-security environment only after the base operating system and desktop are verified. Do not silently install a large tool bundle or launch scans.

- Package allowlists, sources, AUR, BlackArch, and excluded applications follow the policies above.
- Use security tools only against systems and applications the user owns or is explicitly authorized to test.
- The installer must not silently launch scans, exploit checks, or network probes against third-party targets.
- Do not create project/work directories, install browser extensions, or change default-app associations without explicit approval.

## Acceptance checklist

- [ ] Secrets are absent from logs and reports.
- [ ] Direct root login is disabled and sudo is verified.
- [ ] Firewall remains inactive until approved; no default SSH server is enabled.
- [ ] Package signature verification remains enabled; no silent source substitution or automatic package installation occurs.
- [ ] Encrypted DNS failure has no automatic plaintext fallback.
- [ ] Service hardening and desktop components have compatibility evidence; duplicate daemons are absent.
- [ ] Actual hardware inventory informs firmware, network, thermal, and power configuration.
- [ ] Wi-Fi/Bluetooth defaults match the policy; no unsupported fan controller is installed.
- [ ] Intel microcode remains recommendation-only.
- [ ] AUR builds are reviewed and run unprivileged; BlackArch remains optional and selective.
- [ ] No unrequested applications, directories, extensions, scans, or third-party probes are introduced.
- [ ] Suspend/hibernate and authentication claims are supported by evidence.
