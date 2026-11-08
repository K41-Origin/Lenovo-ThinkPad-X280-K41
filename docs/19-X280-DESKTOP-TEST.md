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


## Physical desktop setup attempts — historical record

- Earlier attempts exposed missing AUR dependencies, including libcava. The fixed package list was replaced with the recursive resolver described above.
- Desktop attempt 4 failed during libcava dependency installation because a nested build consumed the parent's process-substitution input as pacman prompt input. The resolver was corrected to materialize dependency lists with mapfile, use /dev/null for non-interactive metadata generation, and connect interactive makepkg to /dev/tty.
- Desktop attempt 5 completed successfully: report reports/desktop/20261108T190308Z/ records exit status 0 and a 16m16s run. This verifies setup-script completion only; it does not establish that every AUR package remains reproducible or that the graphical desktop is accepted.

Do not repeat the full desktop setup merely to re-check the cache ownership issue. Desktop setup is a post-install operation and does not require a fresh Arch installation. Preserve the attempt reports as historical evidence; use the latest status below for current acceptance.

## Read-only desktop diagnostic collection

After starting Hyprland manually, open a terminal inside the running desktop and execute:

```bash
git pull --ff-only
bash scripts/test-desktop-x280.sh
```

The collector runs as the regular user (never with `sudo`) and writes a private report directory under `reports/desktop-diagnostics/<UTC timestamp>/` containing:

- `summary.md` — repository/kernel/session metadata and collection status.
- `diagnostics.txt` — installed desktop package versions, executable availability, Hyprland runtime information (when run inside Hyprland), audio, network device state, PCI/USB inventory, battery/thermal sysfs snapshot, and recent journal errors.
- `manual-checklist.md` — physical acceptance checklist to fill in with PASS, FAIL, or NOT TESTED.

The collector is read-only: it does not install packages, start/stop services, edit configuration, change network state, or invoke privileged commands. If run outside Hyprland, the report explicitly says the compositor runtime checks were not run; run it again from a terminal inside the active session for those checks. A command marked unavailable or returning non-zero is diagnostic evidence, not automatically a desktop failure (for example, an optional tool may not be installed).

Before committing the report, inspect all three files. Journal output and hardware inventory can contain machine-specific details; redact anything private. Then commit and push the report directory so it can be reviewed. Do not upload passwords, tokens, private keys, Wi-Fi credentials, or unrelated personal logs. The collection result only means the script completed; the manual checklist and diagnostic evidence determine physical acceptance.



## Focused Caelestia runtime test

The general desktop collector confirms package and process state, but it does not attempt to start Caelestia. For a focused runtime check, update the checkout and run this from a terminal inside the active Hyprland session:

```bash
git pull --ff-only
bash scripts/test-caelestia-x280.sh
```

The focused collector runs as the regular user and creates `reports/caelestia-diagnostics/<UTC timestamp>/` with:

- `summary.md` — session state, whether Caelestia was already running, and whether the test attempted startup.
- `diagnostics.txt` — installed package versions, CLI help, IPC command discovery, process state, Quickshell log output, and recent user journal errors.
- `manual-checklist.md` — visual and interactive checks that cannot be reliably automated.

If Caelestia is already running, the script leaves it untouched. If it is not running, the script attempts `caelestia shell -d`, waits briefly, checks runtime state, and deliberately leaves it running for manual UI testing. It does not kill the shell, install packages, edit configuration, or invoke privileged commands. A successful collection is not by itself proof that the UI works.

Fill in the manual checklist, inspect all report files for private data, then commit and push the report directory. Do not upload tokens, credentials, private keys, or unrelated personal logs.

### Stop Caelestia manually

To close only the Caelestia shell while keeping Hyprland running, use:

```bash
caelestia shell --kill
```

If that CLI action is unavailable, use Quickshell directly:

```bash
qs -c caelestia kill
```

Upstream usage references: the Caelestia shell README documents `caelestia shell -d` as the preferred start command, and the upstream discussion documents `caelestia shell --kill` / Quickshell kill as stop methods.


## Caelestia cache/state and Bluetooth diagnostics

The previous runtime report recorded permission errors while creating Mesa, Caelestia image-cache, and ddcutil cache paths, plus a BlueZ D-Bus warning. Do not apply recursive `chmod` or `chown` fixes based only on those messages. First update the checkout and run the read-only collector from a terminal inside the active Hyprland session:

```bash
git pull --ff-only
bash scripts/test-caelestia-permissions-x280.sh
```

It runs as the regular user (never with `sudo`) and creates `reports/caelestia-permissions-diagnostics/<UTC timestamp>/` containing:

- `summary.md` — capture time, source commit, kernel, and collection status.
- `diagnostics.txt` — user identity and relevant XDG cache/state paths; ownership, mode, path traversal and optional ACL metadata; Caelestia package state; Bluetooth service, controller and BlueZ D-Bus status; recent user journal errors.

The collector is read-only. It does not create or repair the inspected cache/state paths, change ownership or permissions, install packages, start/stop services, or invoke privileged commands. Missing optional commands or unavailable paths are recorded as diagnostic results; collection continues.

Review the report for private host/user details before committing and pushing it. Do not run broad recursive permission changes. Once the report is available, inspect the exact owner, group, mode, parent-directory traversal and ACL evidence before deciding on any narrowly scoped repair. A completed collection is not a pass for Caelestia or Bluetooth functionality.


### Cache ownership repair — current status

The permissions report reports/caelestia-permissions-diagnostics/20261108T194132Z/ established that ~/.cache was root:root, preventing the regular user from creating cache entries. The guarded repair script scripts/fix-caelestia-cache-permissions-x280.sh was added with dry-run by default and an explicit --apply mode. It only changes ownership of the real ~/.cache directory itself from root:root to the invoking user's UID:GID; it does not recurse or change permissions.

The latest permissions report reports/caelestia-permissions-diagnostics/20261108T194621Z/ verifies ~/.cache is now owned by kai:kai (UID/GID 1000), mode 755. This ownership correction is VERIFIED. The same capture found that the expected application cache subdirectories did not yet exist. The latest Caelestia runtime report reports/caelestia-diagnostics/20261108T194633Z/ found Caelestia already running and deliberately left it untouched. Its log includes cache permission warnings, but those messages may predate the ownership repair; therefore cache creation after a restart is NOT TESTED.

The missing scheme.json remains an observed warning with unknown significance. BlueZ service, bluetoothctl, and org.bluez were unavailable in the captured environment; this is separate from the cache ownership issue. Do not install or enable Bluetooth solely to silence a warning unless Bluetooth functionality is required and hardware is confirmed.

### One final targeted cache verification

No sixth full desktop setup attempt or repeated full diagnostics cycle is warranted. From a terminal inside the active Hyprland session, close only the Caelestia Quickshell instance and start it again:

```bash
qs -c caelestia kill
caelestia shell -d
```

The Quickshell help captured in the latest runtime report documents the kill subcommand; the Caelestia CLI's normal shell start form is `caelestia shell -d`. Then inspect whether the application creates its cache paths and whether new log entries contain permission errors:

```bash
stat ~/.cache/caelestia ~/.cache/caelestia/imagecache ~/.cache/ddcutil 2>&1
qs -c caelestia log
```

If the shell starts and the cache paths are created without new permission errors, mark cache runtime verification PASS and close this issue. If an optional path remains absent but no relevant error occurs, do not treat absence alone as failure. If a new permission error persists, capture only the relevant fresh log and path metadata before considering another change. Do not rerun the desktop installer, recursively change ownership, or repeat the entire diagnostic suite for this issue.

### Current physical acceptance

- Setup script exit: PASS (report 20261108T190308Z).
- Hyprland session and Caelestia/Quickshell process: detected in the latest desktop diagnostics.
- Caelestia IPC discovery: completed successfully.
- ~/.cache ownership: VERIFIED corrected.
- Cache creation after Caelestia restart: NOT TESTED.
- Manual panel, launcher, dashboard, notification, widget, wallpaper, indicator, and visual stability checks: NOT TESTED (latest checklist remains unfilled).
- Bluetooth/BlueZ functionality: NOT TESTED; BlueZ components were unavailable in the captured environment.

A completed diagnostic collection or successful setup-script exit is not a substitute for manual UI acceptance.
