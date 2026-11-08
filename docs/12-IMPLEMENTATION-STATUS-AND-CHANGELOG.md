# Implementation Status

## Current repository snapshot

**Snapshot date:** 2026-11-09  
**Inspected implementation HEAD:** `2e1943996a549c67fb72e873d341fa9658bd0fad`  
**Default branch:** `main`

This document records the latest inspected repository state and physical installer evidence. Historical branch names, PR states, and CI outcomes in the [implementation history archive](archive/12-IMPLEMENTATION-CHANGELOG-HISTORY-2026-11-08.md) are historical only.

## Current implementation matrix

| Area | Status | Current boundary |
|---|---|---|
| Arch ISO bootstrap and manual source-review gate | IMPLEMENTED | Fetches reviewed `main` source, displays resolved SHA, and requires source review plus a passing read-only readiness gate before launch. |
| Initial encrypted Arch installer | IMPLEMENTED | Destructive base-system installer exists. It must only run after documented source review, live readiness, target-plan confirmation, recovery preparation, and explicit operator authorization. |
| Fresh-trial recovery workflow | IMPLEMENTED (documented) | Every failed physical trial is restarted from the official Arch ISO using the full installer from its first stage. The legacy continuation utility is not part of this workflow. |
| Installer diagnostic logging | IMPLEMENTED | Full logs are stored in timestamped repository-local report directories with root-only permissions; installer refuses unsupported runtime/checkouts. Preserve logs before reboot. |
| First-boot evidence collector | IMPLEMENTED / VERIFIED | Read-only collector and automated tests exist. Physical First Boot report `20261108T083237Z`: 14 PASS, 0 FAIL, 0 SKIP; secure ESP masks and effective modes were confirmed. |
| Host inventory and storage discovery/planning/revalidation | IMPLEMENTED | Read-only discovery, topology, planning, prerequisite, confirmation, and revalidation modules exist; automated tests use fixtures/mocks. |
| Base-system bootstrap and fstab handling | IMPLEMENTED | Guarded base package setup; ESP is mounted with owner-only VFAT masks and `/efi` fstab options are normalized to `fmask=0177,dmask=0077`; regression coverage added. |
| Native storage handle prototype | IMPLEMENTED (prototype) | Standalone read-only C prototype; not integrated into the installer and does not establish physical device-handle safety. |
| Desktop setup foundation and attempt evidence | IMPLEMENTED | Manual post-install Hyprland/Quickshell setup, per-attempt timestamped logs, and package snapshots are on `main`. Physical X280 desktop session remains NOT TESTED. |
| Caelestia AUR dependency handling | IMPLEMENTED (recursive resolver; repository validation PASS) | `lib/aur-dependency-resolver.sh` recursively reads required/make dependencies from `.SRCINFO`, checks installed and official packages, clones missing exact-name AUR packages, filters dependencies to x86_64, rejects unsupported architecture metadata, detects cycles, validates package/provider identity, and builds dependencies before parents after per-recipe approval. After approval, it regenerates `.SRCINFO` from the reviewed PKGBUILD as the unprivileged builder and requires an exact metadata match. The Material You v3 compatibility alias remains explicit and verified. Arbitrary AUR virtual-provider discovery is not generalized. Physical AUR build and desktop session remain NOT TESTED. |
| X280 power, battery, thermal, and device tuning | PLANNED | Requires verified runtime hardware evidence and physical testing. |
| Hibernation/resume and recovery-key lifecycle | PLANNED | Configuration and actual suspend/hibernate/resume/recovery validation remain outstanding. |
| Optional selective BlackArch integration | PLANNED | Must remain opt-in and limited to individually selected tools. |

## Latest desktop resolver implementation — 2026-11-09

The fourth desktop trial is gated on the recursive AUR dependency resolver replacing the previous fixed four-package build sequence.

- `lib/aur-dependency-resolver.sh` — IMPLEMENTED. Parses `.SRCINFO` required/make dependencies, checks installed packages and exact official repository package names, recursively clones missing AUR package bases, detects dependency cycles, checks package/provider identity, and builds dependencies before their parents.
- `scripts/setup-desktop-x280.sh` — IMPLEMENTED. Sources the resolver and invokes it for the four Caelestia roots; existing manual approval and unprivileged `makepkg --syncdeps --install` behavior is retained.
- `tests/test-desktop-setup.sh` — UPDATED. Adds syntax checks and fixture coverage for versioned dependency normalization, `.SRCINFO` package/provider matching, dependency/makedepends extraction, and x86_64 architecture acceptance/rejection.
- `docs/19-X280-DESKTOP-TEST.md` and `README.md` — UPDATED to describe the resolver boundary and fourth-trial procedure.
- Implementation commits: resolver `eba9239`; setup integration `716c57a`; fixture tests `7cd3284`; metadata validation hardening `ce6a300`; architecture and approved PKGBUILD/.SRCINFO consistency checks `2e19439`.
- The latest implementation commit is `2e1943996a549c67fb72e873d341fa9658bd0fad`. GitHub Actions **Repository validation** run `42506874266` completed SUCCESS for this exact commit. The separate Bash validation run for this commit was cancelled when the following documentation commit was pushed; its replacement workflow must complete before the physical trial.
- No AUR package was built in CI or by this development session. The physical desktop setup and Hyprland/Caelestia session remain NOT TESTED.

Resolver limitations are deliberate: dependency package names are looked up as exact AUR package bases, except the explicitly mapped Material You v3 provider. Generic AUR RPC search for arbitrary virtual providers and split-package base discovery are not implemented. Unresolved or mismatched metadata stops the setup rather than being guessed.

## Current validation evidence

Latest desktop setup correction:
- PR #26 merged to `main` as `94494dce70a6dd01cacc5d77883d24f3a4c3b3cc`.
- Second physical desktop attempt report `reports/desktop/20261108T095950Z/`: FAIL (exit 1). `quickshell-git` built and installed; `caelestia-cli` preflight failed because `python-materialyoucolor` was not installed or available in official repositories. This is a separate AUR package dependency, not an official-repository package.
- Exact PR head `8260604d70e50df191c522cd6b7b9f8c5431e738`: GitHub Actions **Repository validation** run `42468208174` SUCCESS and **Bash validation** run `42468208092` SUCCESS.
- These CI checks cover Bash syntax, ShellCheck, formatting, and repository fixture tests. They do not execute AUR builds or validate a physical Hyprland/Caelestia session.
- PR #28 merged as `351122b29a5d0e2a242843ffbcbbc66546cdddcf`.
- Exact PR #28 head `34c944967f517d878da4fcad5bd42f52eb319c94`: GitHub Actions **Repository validation** run `42471094388` SUCCESS and **Bash validation** run `42471094373` SUCCESS.
- PR #28 added a v3 version guard to the legacy AUR package name. Follow-up review found upstream documents `python-materialyoucolor3` as the v3 package and `python-materialyoucolor` as legacy v2. PR #30 corrects the build order to use `python-materialyoucolor3`.
- PR #30 requires the v3 `.SRCINFO` to declare `provides = python-materialyoucolor` and checks `pacman -T python-materialyoucolor` immediately after installation. It fails closed if the v3 package cannot satisfy the current `caelestia-cli` dependency.
- PR #30 merged as `b395930e28097b44d127a1b6ba1f8f701d60c157`. Exact PR #30 head `446be34832b16494d700fd61a27da71f5e644350`: GitHub Actions **Repository validation** run `42471524866` SUCCESS and **Bash validation** run `42471524877` SUCCESS.
- CI does not build the moving AUR recipes or validate the physical desktop session. Physical AUR build and desktop acceptance remain NOT TESTED.


For source commit `2aafbdbbec5da671adb05c023c9f28bd1fcba0bb` (a historical inspected `main` HEAD; newer PR-specific checks must be evaluated against their exact head SHA):

- GitHub Actions check **Syntax, lint, and test suite: SUCCESS** (completed 2026-11-08T07:23:14Z).
- GitHub Actions check **shell-and-fixture-tests: SUCCESS** (completed 2026-11-08T07:22:47Z).
- Both check runs report this exact `head_sha`; these results apply only to that commit. The documentation changes in this branch require their own checks after they are committed.
- These are GitHub Actions check-run results, not physical hardware evidence.

Automated success does not establish successful physical boot or validate every hardware behavior.

## Physical X280 installer trials — 2026-11-08

Four full destructive installer trials are preserved in `reports/installer/`:

| Trial | Log | Result | Failure / outcome |
|---|---|---|---|
| 1 | `20261108T060151Z/installer.log` | FAIL | Kernel command-line postcondition incorrectly expected `root=` at the beginning of a line, although it is a whitespace-delimited token on the same line as `rd.luks.name=`. |
| 2 | `20261108T062317Z/installer.log` | FAIL | Swapfile fstab postcondition searched for `/swapfile` in the mountpoint column instead of the source column. |
| 3 | `20261108T064010Z/installer.log` | FAIL | Username validation rejected the default/input `kai`; validation was corrected. |
| 4 | `20261108T065251Z/installer.log` | SUCCESS | Installer reached `completion`, generated the UKI, and recorded `Exit status: 0`. |

Trial 4 records successful completion of target storage preparation, LUKS2/ext4/ESP setup, base package installation, fstab generation, user/locale/timezone/hostname configuration, swapfile creation, NetworkManager enablement, systemd-boot configuration, and UKI generation. The final log reports the UKI at `/efi/EFI/Linux/arch-linux.efi`.

Warnings in the successful log include missing `/etc/vconsole.conf` (mkinitcpio used defaults) and possibly missing `qat_6xxx` firmware. UKI generation still succeeded; these warnings are not evidence of a successful firmware boot.

**Acceptance boundary:** installer execution is TESTED/SUCCESS for trial 4. Physical firmware boot, UKI discovery by firmware, LUKS unlock, root mount, system startup, and first login remain **NOT TESTED** until the actual laptop boots from the internal SSD and the first-boot evidence collector is run.

## Required trial-and-error policy

After any failed physical installation or first-boot attempt:

1. Preserve the diagnostic log and relevant evidence.
2. Reboot into the official Arch Linux ISO in UEFI mode.
3. Obtain and review the latest installer source and resolved commit.
4. Reconfirm target SSD identity and that no target partition is mounted or active as swap.
5. Run the full destructive installer from its first stage after exact plan-bound confirmation.
6. Review the new report before another trial.

Do not use `scripts/resume-arch-x280.sh` for this workflow. A fresh trial erases/recreates the selected SSD; preserve anything required before proceeding.

## Other outstanding gates

- First Boot from the internal SSD and first-boot evidence collection: **VERIFIED for report `20261108T083237Z` (14 PASS)**.
- Desktop setup foundation, logging, and recursive Caelestia AUR dependency handling: **IMPLEMENTED on `main`; current resolver CI validation pending; first three physical desktop attempts FAIL; fourth desktop attempt and physical session NOT TESTED**.
- X280 tuning, hibernation/resume, and selective BlackArch: **PLANNED**.
- VM installation testing: **OUT OF SCOPE** by owner decision.
- No release is claimed.

## Status vocabulary

- **PLANNED:** not implemented.
- **IMPLEMENTED:** code or documentation exists in the repository.
- **TESTED:** an identified test was executed for a stated commit/environment.
- **VERIFIED:** behavior was confirmed with appropriate evidence.
- **RELEASED:** incorporated into a designated release.
- **NOT TESTED:** the behavior has not been exercised with the evidence required for its claim, or testing has not yet occurred.

## Current operator references

- [Installation and disk safety contract](04-INSTALLATION-AND-DISK.md)
- [Arch ISO bootstrap and source-review gate](16-ARCHISO-BOOTSTRAP.md)
- [Initial installer procedure and physical-trial record](15-ARCH-INSTALLER-INITIAL-EXECUTION.md)
- [X280 first-boot test and evidence](17-X280-FIRST-BOOT-TEST.md)
- [Test commands and evidence handling](../tests/README.md)
- [Acceptance criteria](11-TESTING-AND-ACCEPTANCE.md)
