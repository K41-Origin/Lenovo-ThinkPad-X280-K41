# Security and Authentication

## Accounts and login
Disable direct root login; use a normal user and sudo. User supplies username and hostname. Require LUKS passphrase at boot and separate account password at TTY login unless secure compatible integration is verified. Launch the desktop after TTY login only after session integration is verified. Require authentication after suspend/hibernate and provide a manual lock shortcut.

## Secrets and logs
Never log passwords, passphrases, LUKS recovery keys, tokens, cookies, or credentials. Temporary diagnostics may record stage, timestamp, package, error, and retry method only after secret redaction.

## Firewall and remote access
Firewall configuration must not activate before user approval. Candidate: firewalld with Public zone defaults and minimal inbound access, subject to compatibility review. Do not install or enable SSH server by default. Explain material security configuration before applying changes where approval is required.

## Network and package integrity
Use NetworkManager. Prefer encrypted DNS only with a verified implementation. On failure, notify and wait for manual choice; never silently fall back to plaintext DNS. Check DNS, HTTPS, and official Arch repository connectivity before package operations. Never disable signature or integrity verification.

## Service hardening
Audit enabled services before applying systemd restrictions. Apply restrictions only when compatibility is verified. Avoid duplicate daemons. USBGuard and AppArmor are not planned under the current decisions.

## Secure Boot and microcode
Secure Boot is planned disabled; check actual mode and explain mismatches. Intel microcode installation policy is owned by [Hardware, Power, and Network](07-HARDWARE-POWER-AND-NETWORK.md); follow REQ-HW-006 and the implementation-deviation record there.

## Acceptance
- [ ] Secrets absent from logs/reports.
- [ ] Root login disabled; sudo verified.
- [ ] Firewall inactive until approval; no default SSH server.
- [ ] Signature verification remains enabled.
- [ ] No automatic plaintext DNS fallback.
- [ ] Service hardening supported by compatibility evidence.
- [ ] Intel microcode follows REQ-HW-006 and the hardware policy owner.
