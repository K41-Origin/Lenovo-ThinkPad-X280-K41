# Stage 9 — Initial interactive Arch installer

## Status and scope

- Initial destructive entry point: `scripts/install-arch-x280.sh`.
- Interrupted-run continuation: `scripts/resume-arch-x280.sh` on the recovery branch; it is restricted to the recorded post-pacstrap/pre-configuration checkpoint.
- Implementation: IMPLEMENTED on `main`.
- Automated evidence: TESTED on the specific commits/runs recorded in [12 — Implementation Status](12-IMPLEMENTATION-STATUS-AND-CHANGELOG.md); the loop integration covers selected utilities against a disposable loop image.
- VM installation testing: OUT OF SCOPE by owner decision; no VM test will be performed.
- Physical X280 installation and first boot: NOT TESTED.
- Release/merge: merged into `main`; this is not a released or physically validated installer.

This is an initial destructive base-system installer, not the complete intended project installer. The legacy top-level `installer --preflight` remains read-only and is not its entry point.

## Implemented execution path

The script is intended to run manually as root from the official Arch ISO in UEFI mode. It checks required commands and host inventory, discovers whole-disk candidates, and requires the configured internal WDC PC SN730 target identity (model, exact capacity, and stable serial). It calculates the partition plan from runtime disk geometry and swap target from runtime RAM plus a configured 2 GiB margin.

Before disk writes, the script binds target identity to the plan, collects live prerequisites, displays the plan, requires exact plan-bound confirmation, and performs final revalidation. It then retains Bash descriptors for the disk and partitions and passes inherited `/proc/self/fd/N` paths to selected storage utilities.

The current target layout is:
- GPT, 1 GiB FAT32 ESP.
- Linux-LUKS GPT partition, LUKS2.
- ext4 directly on `/dev/mapper/cryptroot`.
- ESP mounted at `/mnt/efi`, root at `/mnt`.

The guarded `base_system::bootstrap` installs the minimal package set with `pacstrap -K` and generates UUID-based fstab. The target configuration script is copied into the target and run through `arch-chroot`; it prompts for hostname, username/password, timezone, and locale, configures sudo wheel access, creates the swapfile, and enables NetworkManager. Intel microcode is not installed automatically under the approved report-only policy.

The installer installs systemd-boot and configures a mkinitcpio UKI using the systemd-based `sd-encrypt` hook and `rd.luks.name=<LUKS-UUID>=cryptroot root=/dev/mapper/cryptroot rw` kernel command line. The default UKI target is `/efi/EFI/Linux/arch-linux.efi`. It checks for expected configuration artifacts and does not reboot automatically.

## Important boundaries and risks

- The installer is destructive and replaces the selected SSD. Its existence or passing CI is not authorization to run it.
- The separate native C helper in `native/storage-handle.c` is not called by this installer.
- The loop integration test validates selected utility interfaces through inherited descriptor paths against a disposable loop image. It does not prove all kernel TOCTOU races impossible, physical NVMe hot-unplug behavior, or successful boot.
- The earlier architecture plan assigned destructive storage ownership to `lib/storage.sh`; the current installer instead orchestrates destructive commands directly. This deviation is documented and remains an architectural item for review/refactor.
- The installer does not configure resume/hibernation, recovery-key storage/registration, Caelestia/Hyprland/Quickshell, ThinkPad power/thermal tuning, or BlackArch. Intel microcode is recommendation-only and is not installed automatically, in accordance with REQ-HW-006.
- No complete transactional rollback or automatic safe resume after partial disk mutation is claimed. After a failure following the first destructive operation, stop and inspect the real disk state; do not rerun blindly.
- A non-empty UKI file and generated configuration artifacts do not prove firmware boot, LUKS unlock, root mount, or successful first login.

## Installer diagnostics

The installer captures stdout/stderr and stage-specific validation failures in a root-only timestamped log at `/var/log/x280-installer/<UTC timestamp>/installer.log`, falling back to volatile `/run/x280-installer/` only when necessary. It prints the exact path on exit. Logging is initialized before host preflight and all storage operations; inability to initialize a secure log stops execution. The log does not use shell xtrace and must be reviewed for hardware identifiers before sharing. See [Error Recovery and Reporting](10-ERROR-RECOVERY-AND-REPORTING.md).

## Automated validation

The canonical runner is:

```bash
bash tests/run.sh
```

It writes persistent summaries and logs under `reports/test-runs/`. Required suite dependencies are `bash`, `jq`, and `python3`; the native helper compile/CLI test is skipped only if `cc` is unavailable. Installer/configuration tests include static assertions; they do not execute the full installer. The pinned-device test uses a temporary loop-backed image, never the physical SSD. This bounded test is not a VM installation and does not replace the required physical destructive test.

See [tests/README.md](../tests/README.md) for the single authoritative test procedure and [11 — Testing and Acceptance](11-TESTING-AND-ACCEPTANCE.md) for acceptance criteria and evidence boundaries.

## Recorded physical attempt and continuation path — 2026-11-08

The first physical installer attempt on the actual X280 passed the destructive storage plan gate and completed the following operations: disk signature removal, GPT/partition creation, LUKS2 formatting/opening, ESP FAT32 formatting, root ext4 formatting, mounting, and `pacstrap` package installation. It then stopped in `base_system::generate_fstab` because the package-created `/etc/fstab` was non-empty. The target disk was therefore already modified; this was not a preflight-only failure.

The fstab implementation has since been corrected to preserve comments and unrelated entries, add only missing root/`/efi` entries, reject conflicts/duplicates, and operate idempotently. CI includes regression coverage for these behaviors.

The laptop was powered off after that failure. The intended next operation is **continuation**, not a fresh installation:

1. Pull branch `fix/installer-diagnostics-stacked-2026-11-08` at the latest reviewed commit.
2. Do **not** run `scripts/bootstrap-archiso.sh`, `scripts/x280-install-readiness.sh`, `scripts/validate-live-storage.sh`, or `scripts/install-arch-x280.sh` for this already-partitioned target. The old blank-disk readiness gate is not applicable after the disk has been initialized, and the original installer would erase it again.
3. Run `bash scripts/resume-arch-x280.sh` as root from the official Arch ISO in UEFI mode.
4. The continuation script performs a narrow, read-only identity/layout/filesystem check for the exact configured SSD and existing GPT/ESP/LUKS2/ext4 layout. It does not repeat the broad readiness suite, partition, format, or run pacstrap. It unlocks the existing LUKS volume, checks ext4 read-only, mounts the existing filesystems, verifies the base packages, safely completes fstab, then proceeds with target configuration and UKI boot setup.
5. If any checkpoint differs from the recorded state, the script stops. Do not fall back to the destructive installer. Push its timestamped log/report for inspection.

This continuation path is deliberately narrow and tied to the known failure checkpoint. It is not a general-purpose resume engine for arbitrary partial installations. If the interactive target-configuration stage itself fails after making partial changes, stop and inspect state rather than rerunning the continuation script blindly.

## Validation and acceptance boundaries

- **TESTED:** current continuation code passed GitHub Actions run #367 (`42404161357`), including Bash syntax, ShellCheck, and 20 repository test scripts (20 passed, 0 failed, 0 skipped).
- The prior successful read-only readiness report remains historical evidence for the pre-installation snapshot; it is not rerun against a disk that is now intentionally partitioned and encrypted.
- The continuation script's own target identity, partition, LUKS2, filesystem, and package checks are required to bind the operation to the existing partial installation. These are not a repeat of the old blank-disk readiness gate.
- No successful physical installation or first boot is claimed until the continuation completes and the X280 boots from the installed SSD.
- VM installation testing remains OUT OF SCOPE by owner decision.
