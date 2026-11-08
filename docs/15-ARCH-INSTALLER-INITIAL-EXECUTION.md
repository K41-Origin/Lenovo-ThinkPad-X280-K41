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

## Recorded physical trials and current failure — 2026-11-08

Two destructive full-installer attempts have been pushed as repository-local evidence:

- `reports/installer/20261108T060151Z/installer.log`
- `reports/installer/20261108T062317Z/installer.log`

The first attempt completed storage preparation, LUKS2/ext4/ESP formatting, mounting, `pacstrap`, fstab generation, target configuration, systemd-boot installation, and UKI generation. It then failed because the kernel-command-line assertion incorrectly expected `root=` at the start of a line. The argument is correctly written as a whitespace-delimited token on the same line as `rd.luks.name=...`; that validation was corrected.

The second attempt confirms the previous correction worked: it passed package installation and target configuration, created the swapfile, enabled NetworkManager, installed systemd-boot, and generated the UKI successfully. It then failed at the installer's final swapfile fstab postcondition.

### Current root cause

The configuration script writes this valid fstab entry:

```text
/swapfile none swap defaults 0 0
```

The installer previously checked for a line where `/swapfile` appeared in the **second** fstab column (the mountpoint). In fstab, the first column is the source, the second is the mountpoint, and the third is the filesystem type. For a swapfile, the correct fields are source `/swapfile`, target `none`, and type `swap`. The check therefore rejected a correctly configured entry.

The postcondition now counts entries whose first three fields exactly match `/swapfile none swap` and requires exactly one. The regression test covers valid, missing, and duplicate entries. This is a validation bug; the latest log shows that the swapfile was created and `mkswap` succeeded, but it does not establish that the installed system has booted.

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

- **TESTED:** the latest pre-fix installer branch passed Repository validation #502 and Bash validation #329. The current swapfile postcondition fix and regression tests require a new CI run.
- The prior successful read-only readiness report remains historical evidence for the pre-installation snapshot; it is not rerun against a disk that is now intentionally partitioned and encrypted.
- The continuation script's own target identity, partition, LUKS2, filesystem, and package checks are required to bind the operation to the existing partial installation. These are not a repeat of the old blank-disk readiness gate.
- No successful physical installation or first boot is claimed until the full installer completes and the X280 boots from the installed SSD.
- VM installation testing remains OUT OF SCOPE by owner decision.
