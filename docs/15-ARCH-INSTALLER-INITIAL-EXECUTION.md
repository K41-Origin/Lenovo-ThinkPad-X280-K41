# Stage 9 — Initial interactive Arch installer

## Status and scope

- Initial destructive entry point: `scripts/install-arch-x280.sh`.
- Legacy continuation utility: `scripts/resume-arch-x280.sh` is retained for compatibility but is **not used** in the agreed trial-and-error workflow.
- Implementation: IMPLEMENTED on the integration branch pending merge into `main`.
- Automated validation: TESTED on the exact commit and GitHub Actions runs recorded in [12 — Implementation Status](12-IMPLEMENTATION-STATUS-AND-CHANGELOG.md).
- VM installation testing: OUT OF SCOPE by owner decision.
- Physical installer trial 4: installer completed with exit status 0; see the timestamped log below.
- Physical first boot from the internal SSD: NOT VERIFIED.

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

The installer installs systemd-boot and configures a mkinitcpio UKI using the systemd-based `sd-encrypt` hook and `rd.luks.name=<LUKS-UUID>=cryptroot root=/dev/mapper/cryptroot rw` kernel command line. The default UKI target is `/efi/EFI/Linux/arch-linux.efi`. It checks expected configuration artifacts and does not reboot automatically.

## Important boundaries and risks

- The installer is destructive and replaces the selected SSD. Its existence or passing CI is not authorization to run it. Every failed physical trial is followed by a reboot into the official Arch ISO and a fresh run of this full installer from its first stage; the continuation utility is not used.
- The separate native C helper in `native/storage-handle.c` is not called by this installer.
- The loop integration test validates selected utility interfaces through inherited descriptor paths against a disposable loop image. It does not prove all kernel TOCTOU races impossible, physical NVMe hot-unplug behavior, or successful boot.
- The earlier architecture plan assigned destructive storage ownership to `lib/storage.sh`; the current installer instead orchestrates destructive commands directly. This deviation remains an architectural item for review/refactor.
- The installer does not configure resume/hibernation, recovery-key storage/registration, Caelestia/Hyprland/Quickshell, ThinkPad power/thermal tuning, or BlackArch. Intel microcode is recommendation-only and is not installed automatically, in accordance with REQ-HW-006.
- No complete transactional rollback or automatic safe resume after partial disk mutation is claimed. After a failure following the first destructive operation, follow the agreed fresh-trial procedure; do not blindly continue from a checkpoint.
- A non-empty UKI file and generated configuration artifacts do not prove firmware boot, LUKS unlock, root mount, or successful first login.

## Installer diagnostics

The initial installer and legacy continuation utility write diagnostic output inside the checkout under `reports/installer/<UTC timestamp>/installer.log` and `reports/installer/resume-<UTC timestamp>/resume.log`. Run directories are root-owned mode 0700 and log files mode 0600. Logging requires the official Arch ISO and a checkout on `overlay` or `tmpfs`; it fails closed rather than writing outside the repository. Logging is initialized before preflight or storage operations. Logs do not use shell xtrace and must be reviewed for hardware identifiers before sharing. Copy the report directory to persistent storage before reboot.

## Automated validation

The canonical runner is:

```bash
bash tests/run.sh
```

It writes persistent summaries and logs under `reports/test-runs/`. Required suite dependencies are `bash`, `jq`, and `python3`; the native helper compile/CLI test is skipped only if `cc` is unavailable. Installer/configuration tests include static assertions; they do not execute the full installer. The pinned-device test uses a temporary loop-backed image, never the physical SSD. This bounded test is not a VM installation and does not replace physical testing.

See [tests/README.md](../tests/README.md) for the authoritative test procedure and [11 — Testing and Acceptance](11-TESTING-AND-ACCEPTANCE.md) for acceptance criteria and evidence boundaries.

## Recorded physical trials — 2026-11-08

Four full destructive installer trials are preserved as repository-local evidence:

- `reports/installer/20261108T060151Z/installer.log`
- `reports/installer/20261108T062317Z/installer.log`
- `reports/installer/20261108T064010Z/installer.log`
- `reports/installer/20261108T065251Z/installer.log`

| Trial | Result | Evidence |
|---|---|---|
| 1 | FAIL | Installer reached the UKI/configuration postcondition but rejected `root=/dev/mapper/cryptroot` because validation incorrectly expected it at the start of a line. The kernel command line stores it as a whitespace-delimited argument alongside `rd.luks.name=`. |
| 2 | FAIL | The base configuration, swapfile creation, NetworkManager, systemd-boot, and UKI stages completed, but the final fstab assertion searched for `/swapfile` in the mountpoint column. Correct fstab fields are source `/swapfile`, target `none`, type `swap`. |
| 3 | FAIL | Storage preparation and base package installation completed, but interactive configuration rejected the username `kai`. The username validation was corrected. |
| 4 | SUCCESS | The installer reached `[STAGE] completion`; UKI generation succeeded and the log records `Exit status: 0`. |

### Trial 4 completion evidence

The latest log, `reports/installer/20261108T065251Z/installer.log`, records:

- ThinkPad X280 and target SSD identification and revalidation.
- GPT partitioning, LUKS2 setup, ESP FAT32 and root ext4 formatting, and mounts.
- Base Arch package installation and fstab generation.
- Hostname, locale, timezone, user `kai`, and password configuration.
- 9.5 GiB swapfile creation and NetworkManager enablement.
- systemd-boot configuration and successful UKI generation at `/efi/EFI/Linux/arch-linux.efi`.
- Final stage `completion`, timestamp `2026-11-08T06:58:59Z`, and `Exit status: 0`.

The log also contains non-fatal mkinitcpio warnings: `/etc/vconsole.conf` was absent so defaults were used, and firmware for `qat_6xxx` may be missing. UKI generation nevertheless completed successfully.

**This establishes successful completion of the installer process as recorded in its log. It does not establish that the laptop has booted from the SSD.** Firmware detection, UKI launch, LUKS unlock, root mount, system startup, and first login remain unverified pending the separate physical First Boot Test.

## Required trial-and-error procedure

After any failed physical installer or first-boot attempt:

1. Preserve the diagnostic log and relevant evidence.
2. Reboot into the official Arch Linux ISO in UEFI mode.
3. Obtain the latest reviewed installer source and inspect the resolved commit.
4. Confirm target SSD identity and that no target partition is mounted or active as swap.
5. Run `bash scripts/install-arch-x280.sh` from the beginning after exact plan-bound confirmation.
6. Review the new timestamped log and fix the next reproducible failure before another full attempt.

The full installer deliberately re-creates the partition table and formats the selected SSD after explicit confirmation. Every new trial is destructive and starts from the first stage. Never run it against a disk containing data that must be retained. The legacy continuation utility is not part of this workflow.

## Validation and acceptance boundaries

- **TESTED:** GitHub Actions syntax/lint/test and shell/fixture checks passed on commit `8d1e0bd1b3ec8cbaca39da106160290f18111850`; see [12 — Implementation Status](12-IMPLEMENTATION-STATUS-AND-CHANGELOG.md). Later commits must be validated independently.
- **TESTED:** physical installer trial 4 exited 0 and recorded successful UKI generation.
- **NOT VERIFIED:** actual boot from internal SSD, firmware/UKI discovery, LUKS unlock, root mount, and first login.
- The old read-only readiness report is historical evidence for its earlier pre-installation snapshot; it is not evidence of the current disk state.
- VM installation testing remains OUT OF SCOPE by owner decision.
