# Stage 9 — Initial interactive Arch installer

## Status and scope

- Source: `scripts/install-arch-x280.sh` and `scripts/configure-arch-x280.sh` on PR #9 branch `feature/base-system-bootstrap-2026-11-07`.
- Implementation: IMPLEMENTED on the feature branch.
- Automated evidence: TESTED on the specific commits/runs recorded in [12 — Implementation Status](12-IMPLEMENTATION-STATUS-AND-CHANGELOG.md); the loop integration covers selected utilities against a disposable loop image.
- VM installation: NOT TESTED.
- Physical X280 installation and first boot: NOT TESTED.
- Release/merge: not implied by branch implementation.

This is an initial destructive base-system installer, not the complete intended project installer. The legacy top-level `installer --preflight` remains read-only and is not its entry point.

## Implemented execution path

The script is intended to run manually as root from the official Arch ISO in UEFI mode. It checks required commands and host inventory, discovers whole-disk candidates, and requires the configured internal WDC PC SN730 target identity (model, exact capacity, and stable serial). It calculates the partition plan from runtime disk geometry and swap target from runtime RAM plus a configured 2 GiB margin.

Before disk writes, the script binds target identity to the plan, collects live prerequisites, displays the plan, requires exact plan-bound confirmation, and performs final revalidation. It then retains Bash descriptors for the disk and partitions and passes inherited `/proc/self/fd/N` paths to selected storage utilities.

The current target layout is:
- GPT, 1 GiB FAT32 ESP.
- Linux-LUKS GPT partition, LUKS2.
- ext4 directly on `/dev/mapper/cryptroot`.
- ESP mounted at `/mnt/efi`, root at `/mnt`.

The guarded `base_system::bootstrap` installs the minimal package set with `pacstrap -K` and generates UUID-based fstab. The target configuration script is copied into the target and run through `arch-chroot`; it prompts for hostname, username/password, timezone, and locale, installs Intel microcode, configures sudo wheel access, creates the swapfile, and enables NetworkManager.

The installer installs systemd-boot and configures a mkinitcpio UKI using the systemd-based `sd-encrypt` hook and `rd.luks.name=<LUKS-UUID>=cryptroot root=/dev/mapper/cryptroot rw` kernel command line. The default UKI target is `/efi/EFI/Linux/arch-linux.efi`. It checks for expected configuration artifacts and does not reboot automatically.

## Important boundaries and risks

- The installer is destructive and replaces the selected SSD. Its existence or passing CI is not authorization to run it.
- The separate native C helper in `native/storage-handle.c` is not called by this installer.
- The loop integration test validates selected utility interfaces through inherited descriptor paths against a disposable loop image. It does not prove all kernel TOCTOU races impossible, physical NVMe hot-unplug behavior, or successful boot.
- The earlier architecture plan assigned destructive storage ownership to `lib/storage.sh`; the current installer instead orchestrates destructive commands directly. This deviation is documented and remains an architectural item for review/refactor.
- The installer does not configure resume/hibernation, recovery-key storage/registration, Caelestia/Hyprland/Quickshell, ThinkPad power/thermal tuning, or BlackArch.
- No complete transactional rollback or automatic safe resume after partial disk mutation is claimed. After a failure following the first destructive operation, stop and inspect the real disk state; do not rerun blindly.
- A non-empty UKI file and generated configuration artifacts do not prove firmware boot, LUKS unlock, root mount, or successful first login.

## Automated validation

The canonical runner is:

```bash
bash tests/run.sh
```

It writes persistent summaries and logs under `reports/test-runs/`. Required suite dependencies are `bash`, `jq`, and `python3`; the native helper compile/CLI test is skipped only if `cc` is unavailable. Installer/configuration tests include static assertions; they do not execute the full installer. The pinned-device test uses a temporary loop-backed image, never the physical SSD.

See [tests/README.md](../tests/README.md) for the single authoritative test procedure and [11 — Testing and Acceptance](11-TESTING-AND-ACCEPTANCE.md) for acceptance criteria and evidence boundaries.

## Physical-test gate

**Do not begin physical destructive testing based solely on this document.** The next physical test is blocked until:
1. Current branch CI is green for the latest documentation/code commit.
2. The read-only `scripts/validate-live-storage.sh` has been run successfully on the actual X280 Arch ISO after the zero-capacity removable-reader fix, with its report reviewed.
3. The installer, target identity, plan, destructive command ordering, descriptor behavior, and all failure/cleanup paths receive a final independent review.
4. The operator confirms backup/recovery arrangements and the exact target identity from the live environment.
5. The final test procedure and stop conditions are approved.

No destructive physical test, successful VM installation, or successful X280 boot is claimed in this document.
