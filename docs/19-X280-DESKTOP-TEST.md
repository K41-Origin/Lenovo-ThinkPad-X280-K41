# X280 Desktop Environment — Physical Test Preparation

## Scope

This stage installs a manually-started Wayland desktop on an already installed and First-Boot-accepted Arch system. It does not participate in disk partitioning or the destructive Arch ISO installation flow.

Target stack:
- Hyprland compositor from the official Arch repository.
- Quickshell from the official Arch repository when Caelestia is skipped.
- `quickshell-git` from the AUR when Caelestia is selected, because the inspected stable `caelestia-shell` AUR metadata declares it as a dependency and it conflicts with the official `quickshell` package.
- Caelestia CLI and Shell from the AUR, after separately displaying and approving each checked-out PKGBUILD and .SRCINFO.
- PipeWire, WirePlumber, XDG Desktop Portal, Hyprland portal backend, GTK portal, and a minimal set of Wayland utilities.

The current Caelestia upstream recommends the stable `caelestia-shell` package. The first physical setup log captured its `.SRCINFO` declaring `caelestia-cli` and `quickshell-git` as dependencies. `makepkg --syncdeps` resolves dependencies from configured pacman repositories; it does not build AUR dependencies. The setup therefore builds the AUR chain in order: `quickshell-git`, `caelestia-cli`, then `caelestia-shell`. Each package is cloned into a unique per-attempt directory and independently reviewed/approved. The recipes are moving AUR sources, not pinned project dependencies; re-review each exact checkout.

## Safety and behavior

- Run `sudo bash scripts/setup-desktop-x280.sh` from the installed system as the regular wheel user.
- The script refuses root invocation without a real `SUDO_USER`, active graphical sessions, non-Arch systems, and pre-existing Hyprland/Caelestia configuration paths.
- Official packages are installed with pacman's normal signature verification. No repository or signature policy is changed.
- When Caelestia is selected, `base-devel` and the documented CLI runtime dependencies are installed from configured official repositories first. This supplies `debugedit` and `fakeroot`, the missing tools from the first failed trial.
- When Caelestia is selected, the official `quickshell` package is deliberately omitted because `quickshell-git` conflicts with it. When Caelestia is skipped, the official `quickshell` package is installed.
- AUR packages are built as the regular user, never root. `makepkg --syncdeps --install` is used only after each exact PKGBUILD/.SRCINFO has been shown and explicitly approved. It installs repository dependencies but does not resolve AUR dependencies; the script handles the known Caelestia AUR dependency chain explicitly.
- Existing Hyprland and Caelestia configuration is not overwritten.
- Portal routing explicitly selects GTK as the default and Hyprland for Screenshot/ScreenCast; existing portal preference files are never overwritten.
- No display manager, autologin, automatic graphical target, Bluetooth service, firewall, power manager, hibernation, or hardware-specific tuning is enabled.
- The initial session is manual: sign in on TTY1 and run `start-hyprland`. This preserves a reliable TTY recovery path during physical testing.

## Per-attempt setup evidence

Every invocation of `scripts/setup-desktop-x280.sh` creates a unique report under `reports/desktop/<UTC timestamp>/`, including invocations that fail an early safety/preflight check. A collision in the same timestamp gets a numeric suffix. The report contains:

- `setup.log` — combined stdout/stderr, package-manager output, AUR review/build output, and explicit failing command/line when a command triggers the ERR trap.
- `summary.md` — start/end timestamps, exit status, result, and source commit.
- `system-info.txt` — repository commit/worktree state, hostname, kernel, architecture, Arch marker, invoking user, and script path.
- `packages-before.txt` and `packages-after.txt` — complete `pacman -Q` snapshots to identify package changes, including partial changes after failure.

The report directory and files are root-only (`0700`/`0600`) because the setup runs through sudo. Inspect with `sudo less reports/desktop/<timestamp>/setup.log` and `sudo cat reports/desktop/<timestamp>/summary.md`. Copy a report to a user-owned location before uploading or sharing it. Reports are local, are not committed automatically, and may reveal host/user/package information; review and redact them first. If the report directory cannot be created, the script stops before making desktop changes.

A setup-script `PASS` means only that the setup script exited successfully. It does not mean the compositor or physical hardware has passed testing.

## First physical test

1. Confirm the latest First Boot report is PASS and the system has working network access.
2. Review the script and the exact resolved repository commit.
3. Run `sudo bash scripts/setup-desktop-x280.sh`.
4. If selecting Caelestia, review and approve each displayed AUR recipe in this order: `quickshell-git`, `caelestia-cli`, `caelestia-shell`. Decline any recipe with unexpected commands, sources, dependencies, or privilege behavior.
5. Log out to TTY1, sign in as the regular user, and run `start-hyprland`.
6. Test display, keyboard, touchpad, terminal, file manager, audio output/input, Wi-Fi, notifications, screenshot/portal behavior, screen sharing, lock, logout, and return to TTY.
7. Capture diagnostics and logs before making repairs. Do not configure automatic session launch until manual session stability is demonstrated.

## Current acceptance boundary

Automated shell tests can validate script syntax and safety guards. They cannot prove that Hyprland, GPU acceleration, Caelestia, audio, portals, touchpad gestures, suspend/resume, or battery behavior work on the physical X280. Those remain NOT TESTED until the laptop owner runs the physical test and uploads the evidence.
