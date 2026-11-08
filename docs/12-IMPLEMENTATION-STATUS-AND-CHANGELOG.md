# Implementation Status and Current Evidence

## Current repository snapshot

- **Status date:** 2026-11-09
- **Default branch:** `main`
- **Latest inspected commit before this documentation refresh:** `820992833eef8b7664d60b013f996ff687d01d75` (desktop diagnostic reports).
- **Source implementation commit referenced by those reports:** `82abf6cc27a36fe3633db731e50e3df03b62fa48`.
- **Latest inspected CI status for the report commit:** no status checks or workflow runs were returned by the GitHub connector. Do not infer CI success from earlier commits.

This file is the canonical current status summary. Detailed historical trial logs remain under `reports/`; older implementation chronology is retained in `docs/archive/`. Do not copy old trial instructions into current operator procedures.

## Current implementation matrix

| Area | Status | Current evidence and boundary |
|---|---|---|
| Arch ISO bootstrap and source-review gate | IMPLEMENTED | Fetches reviewed `main`, displays the resolved SHA, and requires source review, a passing read-only readiness gate, and a second acknowledgement before launch. |
| Initial encrypted Arch installer | IMPLEMENTED | Destructive base-system installer exists. Physical installer trial 4 completed with exit status 0 and generated the UKI. A successful installer exit alone does not prove firmware boot. |
| First Boot validation | IMPLEMENTED / VERIFIED | Physical report `reports/first-boot/20261108T083237Z/` records 14 PASS, 0 FAIL, and 0 SKIP. |
| Host inventory and storage safety modules | IMPLEMENTED | Read-only discovery, target-bound planning, prerequisite evidence, confirmation, revalidation, dry-run, and mock execution boundaries exist. Physical and kernel-race limitations remain documented. |
| Base-system bootstrap and fstab handling | IMPLEMENTED | Guarded base package setup and UUID-based fstab generation; ESP permission masks are enforced and checked. |
| Native storage handle | IMPLEMENTED (prototype) | Standalone read-only C prototype; not integrated into the installer and not proof of physical device-handle safety. |
| Post-install Hyprland/Caelestia setup | IMPLEMENTED | Separate manual TTY-launched setup with timestamped logs and package snapshots. Latest setup report records exit status 0. |
| Recursive AUR dependency resolver | IMPLEMENTED | Resolves required/make dependencies from reviewed `.SRCINFO`, checks installed/official packages, recursively resolves exact AUR names, detects cycles, validates package/provider identity and architecture, and builds as an unprivileged user after per-recipe approval. The Material You v3 compatibility alias is explicit. Generic arbitrary AUR virtual-provider discovery is not implemented. |
| Hyprland runtime | TESTED | Latest desktop diagnostics detected Hyprland 0.57.1 on the X280, 1920×1080@60 internal display, Intel UHD 620/i915, keyboard, touchpad, TrackPoint, PipeWire, and connected Wi-Fi. This is runtime inventory, not complete hardware acceptance. |
| Caelestia runtime and IPC | TESTED | Caelestia/Quickshell process detected; startup/configuration had previously logged Configuration Loaded; IPC target discovery completed. Manual UI acceptance remains NOT TESTED. |
| Caelestia cache ownership | VERIFIED | Latest permissions report confirms `~/.cache` is owned by the regular user (UID/GID 1000), mode 755. The guarded repair changes only the top-level cache directory owner/group, not contents recursively. |
| Cache creation after Caelestia restart | NOT TESTED | Latest runtime collector found Caelestia already running and did not restart it. Its captured log may contain pre-repair warnings. One targeted restart/inspection is the only remaining cache check. |
| Bluetooth/BlueZ | NOT TESTED | Latest permissions report found no bluetooth.service, bluetoothctl, or available org.bluez D-Bus service. Bluetooth functionality was not validated. |
| Manual desktop UI acceptance | NOT TESTED | Panel, launcher, dashboard, notifications, widgets, wallpaper/theme, indicators, and visual stability checklist remains unfilled. |
| Read-only X280 hardware audit | IMPLEMENTED | `scripts/audit-x280-hardware.sh` collects CPU, memory, DMI non-unique identity, PCI/USB, storage topology without serials/UUIDs, graphics, network state, battery, thermal, and power-service inventory. Physical report `958dc3b9f53f9f7ac0a6960e0d58e31c004fb27c` has been reviewed; USB/renderer/Vulkan details were incomplete because optional tools were absent. |
| Read-only X280 power-management baseline collector | IMPLEMENTED / VERIFIED | Physical report `reports/power-management-audit/20261108T203517Z/` confirms Intel pstate, powersave governor, balance_power EPP, PPD active with balanced profile, and working D-Bus despite broken powerprofilesctl Python import. |
| Explicit X280 power-profile selector | IMPLEMENTED | `scripts/set-x280-power-profile.sh` detects the PPD D-Bus endpoint, checks exposed profiles, applies only explicit allowlisted requests, and verifies ActiveProfile. Controlled power-saver A/B test and rollback on the physical laptop remain NOT TESTED. |\n| X280 power, battery, thermal, and device tuning | PLANNED | Hardware report reviewed; detailed CPU policy/EPP/platform-profile baseline and physical acceptance tests remain necessary before selecting changes. |
| Hibernation/resume and recovery-key lifecycle | PLANNED | Configuration and physical suspend/hibernate/resume/recovery validation remain outstanding. |
| Optional selective BlackArch integration | PLANNED | Must remain opt-in and limited to individually selected tools. |

## Hardware audit review\n\nThe physical hardware report committed in `958dc3b9f53f9f7ac0a6960e0d58e31c004fb27c` identifies an i5-8250U/X280 with UHD 620/i915, 8 GB RAM, WD SN730 NVMe, Intel 8265 Wi-Fi, and LGC 01AV470 battery. Captured full-charge capacity was 43.66 Wh against 47.88 Wh design capacity (approximately 91.2%); this sysfs snapshot is not a calibrated battery-health test. The power-profiles-daemon service was active, so no competing manager should be enabled without further investigation. A focused CPU/EPP/platform-profile baseline collector is implemented and its physical report `reports/power-management-audit/20261108T203517Z/` has been reviewed. The D-Bus fallback confirms the active `balanced` profile; the `powerprofilesctl` Python frontend remains broken. A reversible profile selector is implemented; an actual power-saver A/B measurement remains pending.\n\n## Latest desktop setup and evidence

The fifth physical desktop setup attempt is recorded in `reports/desktop/20261108T190308Z/`:

- Start: 2026-11-08 19:03:08 UTC.
- Finish: 2026-11-08 19:19:24 UTC.
- Duration: 16m16s.
- Exit status: 0.
- Result: setup script PASS.

This confirms that the setup script completed. It does not establish visual desktop acceptance, suspend/resume, all hardware functions, or long-term stability.

Latest focused diagnostics:

- `reports/desktop-diagnostics/20261108T192834Z/` — broad desktop inventory; collection completed, not a hardware PASS.
- `reports/caelestia-permissions-diagnostics/20261108T194132Z/` — initial permissions evidence: `~/.cache` was root-owned.
- `reports/caelestia-permissions-diagnostics/20261108T194621Z/` — verifies `~/.cache` is now user-owned; expected application cache subdirectories were absent at capture.
- `reports/caelestia-diagnostics/20261108T194633Z/` — Caelestia was already running, Quickshell process and IPC were detected, but the collector deliberately did not restart the shell. Manual checklist remains NOT TESTED.

The cache ownership issue is therefore closed at the filesystem ownership layer. Runtime cache creation after a restart is not yet verified. Do not repeat the full desktop setup or full diagnostics suite to answer that narrow question; follow the single targeted procedure in [desktop test documentation](19-X280-DESKTOP-TEST.md).

## AUR resolver implementation and CI evidence

The recursive resolver replaced the earlier hard-coded package build list after physical attempts exposed missing AUR dependencies and an interactive stdin bug.

- `lib/aur-dependency-resolver.sh` — recursive metadata dependency traversal, cycle detection, architecture filtering, package/provider identity checks, and approved unprivileged builds.
- `scripts/setup-desktop-x280.sh` — invokes the resolver for the Caelestia package roots.
- `tests/test-desktop-setup.sh` — resolver fixtures and safety/syntax checks.
- Resolver implementation baseline `2e1943996a549c67fb72e873d341fa9658bd0fad`: Repository validation run `42506874266` SUCCESS.
- Documentation commit `75f3caea501c2b29e25051baa9f2eaaa116f4229`: Repository validation run `42506958197` and Bash validation run `42506958174` SUCCESS.

These CI results apply only to the named commits. They do not prove that moving AUR recipes build successfully today or that the physical desktop UI passes. No CI success is claimed for the latest report commit unless a check result is independently available.

## Installer and desktop trial history

- The first three destructive installer trials failed on postcondition/validation defects; installer trial 4 completed successfully. Full logs are retained under `reports/installer/`.
- The physical First Boot report then recorded 14 PASS, 0 FAIL, 0 SKIP.
- Early desktop attempts exposed missing AUR dependencies. Desktop attempt 4 failed because recursive dependency commands consumed pacman's interactive stdin. The resolver was changed to materialize dependency lists with `mapfile`, send metadata generation to `/dev/null`, and attach interactive makepkg to `/dev/tty`.
- Desktop attempt 5 completed with exit status 0 as recorded above.

Installer trial recovery and desktop setup retries are different workflows. A failed destructive Arch installer trial requires the documented fresh-install recovery process and explicit target revalidation. A desktop setup retry is a post-install operation and does not justify reinstalling Arch.

## Current priority and deferred stages

1. **CURRENT — Desktop functional validation.** Complete the manual Hyprland/Caelestia UI and hardware-interaction checklist, including display, input, audio, Wi-Fi, portals, locking, logout, and TTY recovery. Bluetooth remains NOT TESTED until its availability/requirement is resolved. Setup-script exit and process detection do not constitute desktop acceptance.
2. **NEXT — Desktop customization.** After functional acceptance, implement the premium, minimal, monochromatic visual design. Detailed scope and acceptance are in `docs/22-X280-DESKTOP-CUSTOMIZATION.md`.
3. **THEN — Optional software integration.** Review and implement only optional components explicitly selected by the owner. Selective BlackArch remains PLANNED and opt-in.
4. **FINAL STAGE — Hardware and system customization.** Defer CPU/GPU/performance tuning, thermal optimization, power/battery tuning, suspend/hibernate/resume testing, and extended system-stability/regression testing until stages 1–3 are accepted.

The hardware and power audit collectors remain implemented evidence-gathering tools. The explicit power-profile selector remains implemented, but no power-saver A/B campaign or battery optimization is currently required. Do not enable competing power managers or apply device-specific tuning ahead of the final stage.

## Status vocabulary

- **PLANNED:** not implemented.
- **IMPLEMENTED:** code or documentation exists in the repository.
- **TESTED:** an identified test was executed for a stated commit/environment.
- **VERIFIED:** behavior was confirmed with appropriate evidence.
- **RELEASED:** incorporated into a designated release.
- **NOT TESTED:** behavior has not been exercised with the evidence required for its claim.

## Canonical operator references

- [Installation and disk safety contract](04-INSTALLATION-AND-DISK.md)
- [Arch ISO bootstrap and source-review gate](16-ARCHISO-BOOTSTRAP.md)
- [Initial installer procedure](15-ARCH-INSTALLER-INITIAL-EXECUTION.md)
- [X280 first-boot test and evidence](17-X280-FIRST-BOOT-TEST.md)
- [Desktop setup and physical acceptance](19-X280-DESKTOP-TEST.md)
- [Test commands and evidence handling](../tests/README.md)
- [Acceptance criteria](11-TESTING-AND-ACCEPTANCE.md)

No release is claimed.
