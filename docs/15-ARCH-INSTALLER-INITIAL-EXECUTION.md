# Stage 9 — Initial interactive Arch installer

## Status and scope

- Initial destructive entry point: `scripts/install-arch-x280.sh`.
- Legacy continuation utility: `scripts/resume-arch-x280.sh` is retained for historical compatibility but is **not used** in the current trial-and-error workflow.
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

- The installer is destructive and replaces the selected SSD. Its existence or passing CI is not authorization to run it. In the agreed trial-and-error workflow, every failed physical attempt is followed by a reboot into the official Arch ISO and a fresh run of this full installer from its first stage; the continuation utility is not used.
- The separate native C helper in `native/storage-handle.c` is not called by this installer.
- The loop integration test validates selected utility interfaces through inherited descriptor paths against a disposable loop image. It does not prove all kernel TOCTOU races impossible, physical NVMe hot-unplug behavior, or successful boot.
- The earlier architecture plan assigned destructive storage ownership to `lib/storage.sh`; the current installer instead orchestrates destructive commands directly. This deviation is documented and remains an architectural item for review/refactor.
- The installer does not configure resume/hibernation, recovery-key storage/registration, Caelestia/Hyprland/Quickshell, ThinkPad power/thermal tuning, or BlackArch. Intel microcode is recommendation-only and is not installed automatically, in accordance with REQ-HW-006.
- No complete transactional rollback or automatic safe resume after partial disk mutation is claimed. After a failure following the first destructive operation, stop and inspect the real disk state; do not rerun blindly.
- A non-empty UKI file and generated configuration artifacts do not prove firmware boot, LUKS unlock, root mount, or successful first login.

## Installer diagnostics

The initial installer and checkpoint continuation capture stdout/stderr and stage-specific failures inside the checkout under `reports/installer/<UTC timestamp>/installer.log` and `reports/installer/resume-<UTC timestamp>/resume.log`. Run directories are root-owned mode 0700 and log files mode 0600. Logging requires the official Arch ISO and a checkout on `overlay` or `tmpfs`; it fails closed rather than writing outside the repository. Logging is initialized before preflight or storage operations. Logs do not use shell xtrace and must be reviewed for hardware identifiers before sharing. Copy the report directory to persistent storage before reboot. See [Error Recovery and Reporting](10-ERROR-RECOVERY-AND-REPORTING.md).

## Automated validation

The canonical runner is:

```bash
bash tests/run.sh
```

It writes persistent summaries and logs under `reports/test-runs/`. Required suite dependencies are `bash`, `jq`, and `python3`; the native helper compile/CLI test is skipped only if `cc` is unavailable. Installer/configuration tests include static assertions; they do not execute the full installer. The pinned-device test uses a temporary loop-backed image, never the physical SSD. This bounded test is not a VM installation and does not replace the required physical destructive test.

See [tests/README.md](../tests/README.md) for the single authoritative test procedure and [11 — Testing and Acceptance](11-TESTING-AND-ACCEPTANCE.md) for acceptance criteria and evidence boundaries.

## Recorded physical trial and current failure — 2026-11-08

The pushed diagnostic log at `reports/installer/20261108T060151Z/installer.log` records a full destructive run from commit `97f826713a61645f5946aec32529eb4940d250fc`. It confirms that the installer:

- Passed X280 hardware identification, UEFI, disk discovery, storage-plan confirmation, and final revalidation.
- Replaced the GPT layout, created the LUKS2 root container, formatted the ESP as FAT32 and root as ext4, and mounted both filesystems.
- Completed `pacstrap`, generated/validated fstab, configured hostname/locale/timezone/user/password/swapfile, and enabled NetworkManager.
- Installed systemd-boot and successfully generated the UKI at `/efi/EFI/Linux/arch-linux.efi`.
- Exited with status 1 during the final kernel-command-line assertions.

### Root cause identified

The installer wrote both kernel parameters on one line:

```text
rd.luks.name=<LUKS-UUID>=cryptroot root=/dev/mapper/cryptroot rw
```

But it validated the root parameter using an anchored expression, `^root=/dev/mapper/cryptroot`, which incorrectly assumes `root=` starts a new line. Kernel command-line arguments are whitespace-separated tokens on the same line. The assertion therefore returned false even though the UKI generation succeeded.

The correction changes the check to recognize `root=/dev/mapper/cryptroot` as a whitespace-delimited token anywhere on that line and adds a regression test using the same argument ordering. This is a validation bug, not evidence that the UKI generation itself failed. A successful UKI build still does not prove that firmware can boot it or that LUKS unlock and root mounting work.

The same log exposed a second issue: the installer set a process-wide `umask 077`, which was inherited by `pacstrap`. Pacman reported target directories such as `/mnt/etc`, `/mnt/var`, and `/mnt/var/lib` as mode 0700 where package metadata expected 0755. The installer now uses `umask 022` for normal system creation while setting log directories/files explicitly to 0700/0600. The package set also explicitly includes `iptables` and `mkinitcpio` to select the providers that were interactively requested during the trial. A regression test now checks those package selections.

### Required trial-and-error procedure

After any failed physical attempt:

1. Preserve and push the repository-local diagnostic log and relevant evidence.
2. Reboot into the official Arch Linux ISO in UEFI mode.
3. Obtain the latest reviewed installer branch/commit and inspect the changes.
4. Confirm the target SSD identity and that no target partition is mounted or active as swap.
5. Run `bash scripts/install-arch-x280.sh` from the beginning.
6. Review the new timestamped log and fix the next reproducible failure before another full attempt.

The installer deliberately re-creates the partition table and formats the target SSD after explicit plan-bound confirmation. Therefore every new trial is a fresh destructive installation, not a continuation. Never run it against a disk containing data that must be retained. The legacy continuation script is not part of this workflow.

## Validation and acceptance boundaries

- **TESTED:** current continuation code passed GitHub Actions run #375 (`42404369312`), including Bash syntax, ShellCheck, and 20 repository test scripts (20 passed, 0 failed, 0 skipped).
- The prior successful read-only readiness report remains historical evidence for the pre-installation snapshot; it is not rerun against a disk that is now intentionally partitioned and encrypted.
- The continuation script's own target identity, partition, LUKS2, filesystem, and package checks are required to bind the operation to the existing partial installation. These are not a repeat of the old blank-disk readiness gate.
- No successful physical installation or first boot is claimed until the continuation completes and the X280 boots from the installed SSD.
- VM installation testing remains OUT OF SCOPE by owner decision.
