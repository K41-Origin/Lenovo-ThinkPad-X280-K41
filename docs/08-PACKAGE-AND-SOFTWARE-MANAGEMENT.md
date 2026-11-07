# Package and Software Management

## General policy
Prefer verified official Arch repositories. Show package names, versions, and origins. Check updates weekly and notify only; never install automatically. Label AUR origin and ask before updates. Explain configuration migrations per update; mark unidentifiable changes unverified. Never disable signature verification or silently switch package sources. Do not install base-devel automatically unless a verified workflow requires it.

## Requested baseline tools
Verify current names and availability before installation: curl, wget, bind (for dig), whois; Git and GitHub CLI with manual authentication and no tokens in logs; ShellCheck and shfmt; Python 3 and pip; Go; Node.js and npm (verify version rather than assume LTS); VS Code open-source build from official Arch repository if available, without silent source substitution.

## Not installed by default
fd, ripgrep, btop, mtr, httpie, Postman, pytest, pipx, and base-devel. Nano is included in the current minimal base package list in `lib/base-system.sh`; it is not part of the optional developer-tool bundle. Do not request OpenSSL as an extra application; allow it as a dependency when required.

## AUR workflow
Custom interactive CLI; no third-party AUR helper by default. Inspect PKGBUILD and related files and compare versions. Flag suspicious commands, network activity, privilege escalation, and system changes. Build as an unprivileged user, never root. If a separate root action is required, explain it and request confirmation. Review maintenance activity and warnings where available. On integrity failure, offer retry, diagnosis, or cancel; never install unverified artifacts.

## Optional BlackArch
No tools initially. Use official setup and keyring/signature verification. Select individual tools, never the entire collection. Verification failure offers retry, diagnosis, or cancel, never bypass.

## Developer and bug-bounty applications
Firefox main browser; no automatic extensions or default associations. Bitwarden preferred, source verified and sign-in manual. Do not auto-create ~/Projects, ~/BugBounty, or ~/Tools. Do not install Burp Suite Community, OWASP ZAP, or Docker by default. Podman and Podman Compose only if trusted packages are verified, without automatic configuration. Cockpit only if verified; do not enable automatically, and use localhost-only binding only when verified.

## Acceptance
- [ ] Package source/version visible.
- [ ] No automatic updates or source substitution.
- [ ] AUR builds unprivileged and reviewed.
- [ ] BlackArch optional; verification never bypassed.
- [ ] Excluded applications are not installed as direct defaults.
