# X280 Desktop Environment — Physical Test Preparation

## Scope

This stage installs a manually-started Wayland desktop on an already installed and First-Boot-accepted Arch system. It does not participate in disk partitioning or the destructive Arch ISO installation flow.

Target stack:
- Hyprland compositor from the official Arch repository.
- Quickshell from the official Arch repository when Caelestia is skipped.
- `quickshell-git` from the AUR when Caelestia is selected, because the inspected stable `caelestia-shell` AUR metadata declares it as a dependency and it conflicts with the official `quickshell` package.
- Caelestia CLI and Shell from the AUR, after separately displaying and approving each checked-out PKGBUILD and .SRCINFO.
- PipeWire, WirePlumber, XDG Desktop Portal, Hyprland portal backend, GTK portal, and a minimal set of Wayland utilities.

The current Caelestia upstream recommends the stable `caelestia-shell` package. Earlier physical setup logs exposed successive missing dependencies because `makepkg --syncdeps` resolves dependencies from configured pacman repositories but does not build AUR dependencies. The desktop setup now delegates dependency handling to `lib/aur-dependency-resolver.sh`: it reads required and make dependencies from each checked-out `.SRCINFO`, checks installed packages with `pacman -T`, checks exact official repository packages with `pacman -Si`, and recursively clones missing AUR package bases. It detects recursion cycles, filters architecture-specific dependency fields to x86_64, requires package metadata to declare x86_64 or any support, validates that the checkout declares the requested package/provider, and builds dependencies before their parent. Each exact PKGBUILD and .SRCINFO is displayed and individually approved; only after approval, `makepkg --printsrcinfo` runs as the unprivileged builder and its output must exactly match the reviewed .SRCINFO before the unprivileged `makepkg --syncdeps --install` build. The known Caelestia CLI compatibility edge remains explicit: `python-materialyoucolor3` must be v3 and declare `provides = python-materialyoucolor`; the resolver checks that metadata and verifies the installed provider with `pacman -T`. AUR recipes are moving sources, not pinned project dependencies; review each exact checkout. The resolver currently resolves exact AUR package names plus this explicit compatibility alias; it does not implement a general AUR RPC provider search for arbitrary virtual provides.

## Safety and behavior

- Run `sudo bash scripts/setup-desktop-x280.sh` from the installed system as the regular wheel user.
- The script refuses root invocation without a real `SUDO_USER`, active graphical sessions, non-Arch systems, and pre-existing Hyprland/Caelestia configuration paths.
- Official packages are installed with pacman's normal signature verification. No repository or signature policy is changed.
- When Caelestia is selected, `base-devel` and the documented CLI runtime dependencies are installed from configured official repositories first. This supplies `debugedit` and `fakeroot`, the missing tools from the first failed trial.
- When Caelestia is selected, the official `quickshell` package is deliberately omitted because `quickshell-git` conflicts with it. When Caelestia is skipped, the official `quickshell` package is installed.
- AUR packages are built as the regular user, never root. The resolver recursively inspects required/make dependencies in each .SRCINFO, builds discovered AUR dependencies before their parent, detects cycles, and requires individual review/approval of each exact PKGBUILD/.SRCINFO. `makepkg --syncdeps --install` handles official repository dependencies only; it is not treated as an AUR resolver.
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
4. If selecting Caelestia, review and approve every AUR recipe displayed by the resolver in its discovered dependency order. The resolver may identify additional AUR packages as metadata changes. Verify package identity, sources, build commands, dependencies, and privilege behavior. The v3 `python-materialyoucolor3` provider must declare the legacy `python-materialyoucolor` name required by the current CLI metadata.
5. Log out to TTY1, sign in as the regular user, and run `start-hyprland`.
6. Test display, keyboard, touchpad, terminal, file manager, audio output/input, Wi-Fi, notifications, screenshot/portal behavior, screen sharing, lock, logout, and return to TTY.
7. Capture diagnostics and logs before making repairs. Do not configure automatic session launch until manual session stability is demonstrated.

## Current acceptance boundary

Automated shell tests can validate script syntax and safety guards. They cannot prove that Hyprland, GPU acceleration, Caelestia, audio, portals, touchpad gestures, suspend/resume, or battery behavior work on the physical X280. Those remain NOT TESTED until the laptop owner runs the physical test and uploads the evidence.


## Fourth desktop trial gate — 2026-11-09

The previous third desktop attempt failed while checking the Caelestia Shell AUR dependency `libcava`. The implementation has been changed from a hard-coded four-package build list to recursive required/make dependency traversal in `lib/aur-dependency-resolver.sh`. This removes the known failure mode where an additional AUR dependency is neither installed nor in an official repository and is simply rejected without attempting to resolve its AUR package.

Before starting the fourth physical desktop setup attempt:

1. Update the repository checkout to the reviewed latest `main` commit and inspect the exact resolver, setup script, and AUR recipes presented at runtime.
2. Run the automated desktop resolver fixture test through `bash tests/test-desktop-setup.sh` (and the canonical `bash tests/run.sh` suite).
3. Run `sudo bash scripts/setup-desktop-x280.sh` from a TTY on the already installed Arch system; this is a post-install desktop operation and does not repartition or erase the SSD.
4. Select Caelestia and review every discovered AUR package in the order presented. Decline unexpected or untrusted PKGBUILDs; preserve the generated timestamped report if any step fails.
5. Start Hyprland manually from TTY only after setup exits successfully, then perform the physical acceptance checks above.

The resolver's exact-name AUR lookup and the explicit Material You provider alias are intentionally conservative. It verifies the reviewed .SRCINFO against the approved PKGBUILD-generated metadata and rejects package metadata that does not declare x86_64 or any support. Arbitrary virtual AUR provides, split-package base discovery, and live AUR metadata availability are not generalized; unresolved or mismatched metadata must stop the setup rather than be guessed. A successful setup-script exit still does not constitute physical desktop acceptance.


## Fifth desktop trial gate — 2026-11-09

The fourth physical attempt built and installed `quickshell-git`, `python-materialyoucolor3`, and `caelestia-cli), then failed while building `libcava`. The captured terminal output shows pacman was asked to install the official build dependencies `meson` and `autoconf-archive`, but the next metadata dependency string (`libpipewire`) was consumed at pacman's confirmation prompt. This was caused by recursive dependency traversal running inside a `while read ... < <(...)` loop: nested build commands inherited the parent's process-substitution stream as stdin.

The resolver now materializes each package's dependency list with `mapfile` before recursing, iterates the resulting array, sends non-interactive metadata generation `/dev/null`, and attaches interactive `makepkg --syncdeps --install` to the controlling TTY. This prevents dependency names from being interpreted as pacman answers while preserving interactive confirmation.

Before the fifth physical desktop attempt:

1. Update to the latest reviewed `main` commit.
2. Run `bash tests/test-desktop-setup.sh` and `bash tests/run.sh`; stop on any failure.
3. Run `sudo bash scripts/setup-desktop-x280.sh` from a TTY on the already installed Arch system.
4. Review each displayed AUR recipe. In particular, when `libcava` is built, verify that pacman can display and complete its official dependency transaction for `meson` and `autoconf-archive`; do not type package names at the pacman confirmation prompt.
5. If setup completes, start `start-hyprland` manually and execute the physical acceptance checks above.

The fix addresses the observed fourth-attempt failure mechanism. It does not prove the next AUR build, Caelestia startup, or physical desktop session will succeed.
