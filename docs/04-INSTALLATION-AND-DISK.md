# Installation and Disk

## Ownership and approved design

This is the canonical technical document for target storage, encryption, boot, swap/resume, and disk recovery. Approved decisions are indexed in [02-REQUIREMENTS-AND-DECISIONS.md](02-REQUIREMENTS-AND-DECISIONS.md); implementation state and evidence are maintained in [12-IMPLEMENTATION-STATUS-AND-CHANGELOG.md](12-IMPLEMENTATION-STATUS-AND-CHANGELOG.md).

Approved target direction:
- Boot an official, unmodified Arch Linux ISO from USB in UEFI mode; start the project script manually.
- Replace the existing Windows installation. The owner reports no data needs to be retained; this does not waive identity, backup, and confirmation gates.
- GPT with a 1 GiB FAT32 EFI System Partition (ESP), mounted at `/efi` inside the target.
- One remaining-space Linux-LUKS partition (GPT type GUID `CA7D7CCB-63ED-4C53-861C-1742536059CC`), LUKS2, and ext4 directly on `/dev/mapper/cryptroot`; no LVM.
- Official Arch `linux` kernel, systemd-boot, and a mkinitcpio-generated UKI at `/efi/EFI/Linux/arch-linux.efi`.
- Swapfile inside encrypted ext4 root. Hibernation/resume remains disabled until the swapfile physical offset and complete boot lifecycle are implemented and verified.
- Secure Boot is planned disabled. The UKI is not Secure-Boot-authenticated under this policy.
- Do not automatically install an alternative kernel or introduce undocumented hardware-specific storage behavior.

## Current implementation on `main`

`scripts/install-arch-x280.sh` is an initial destructive installer on `main`, separate from the diagnostic-only top-level `installer`. It currently:
1. Requires root, UEFI, required commands, and matching X280 host inventory.
2. Discovers whole-disk candidates and requires the configured internal WDC PC SN730 model, exact capacity, and stable serial identity.
3. Calculates GPT geometry from actual disk capacity/sector sizes and swapfile target from runtime RAM plus a configured 2 GiB margin.
4. Binds the selected target to the plan, collects live prerequisites, renders the plan, requests exact plan-bound confirmation, and performs final revalidation.
5. Opens and retains Bash descriptors for the disk/partitions and passes inherited `/proc/self/fd/N` paths to selected disk utilities.
6. Wipes old signatures, creates GPT/ESP/Linux-LUKS partitions, formats FAT32 and LUKS2/ext4, opens `cryptroot`, and mounts root at `/mnt` and ESP at `/mnt/efi`.
7. Calls `base_system::bootstrap` for `pacstrap -K` and UUID-based fstab generation.
8. Runs `scripts/configure-arch-x280.sh` in `arch-chroot` to configure hostname, user/password, timezone, locale, sudo wheel access, swapfile, and NetworkManager. Intel microcode is recommendation-only and is not installed automatically by the current configuration script.
9. Installs systemd-boot and configures mkinitcpio with `HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block sd-encrypt filesystems fsck)`; kernel command line uses `rd.luks.name=<LUKS-UUID>=cryptroot root=/dev/mapper/cryptroot rw`.
10. Generates the default UKI, checks expected configuration artifacts, and does not reboot automatically.

This describes the current source path. Physical trial 4 confirms installer-process completion and UKI generation, but does not establish successful boot, LUKS unlock, or full physical-hardware acceptance. See [Stage 9 installer record](15-ARCH-INSTALLER-INITIAL-EXECUTION.md).

## Mandatory safety gates

The implementation and future changes must preserve these requirements:
- Require UEFI and an internal writable NVMe whole disk.
- Require exact target identity using the approved model, capacity, and stable identifier; device path or model alone is insufficient.
- Inspect mounted descendants, holders/slaves, live root/EFI dependencies, loop/overlay backing, and active swap. Unknown or unresolved topology fails closed.
- Display the complete target-specific partition and configuration plan before confirmation.
- Require explicit exact plan-bound confirmation, then freshly revalidate target identity and prerequisites before the first destructive operation.
- Never disable unrelated live-ISO swap as a shortcut.
- Never automatically retry or repeat destructive work after an interruption or partial failure.
- Do not log passphrases, passwords, recovery keys, or tokens.

**Architecture limitation:** the planned design assigns all destructive storage ownership to `lib/storage.sh`, but the current installer script orchestrates destructive commands directly. This is an acknowledged implementation deviation, not a completed module boundary. The native C helper is a separate read-only prototype and is not integrated. The inherited descriptor-path loop test provides limited interface evidence; it does not prove all TOCTOU or hardware failure modes impossible.

## Partition and filesystem layout

| Order | GPT type | Size | Format | Mount / purpose |
|---|---|---:|---|---|
| 1 | EFI System Partition `C12A7328-F81F-11D2-BA4B-00A0C93EC93B` | 1 GiB | FAT32 | `/efi` in target; systemd-boot and UKI |
| 2 | Linux LUKS `CA7D7CCB-63ED-4C53-861C-1742536059CC` | Remaining usable space | LUKS2 container | Encrypted root |
| Mapper | Not a GPT partition | Container payload | ext4 | `/`; kernel files, mkinitcpio configuration, swapfile |

The layout uses 1 MiB alignment and actual logical-sector geometry. The plan module validates GPT bounds and reserves metadata; it does not itself write a partition table. The installer uses the target-specific plan and exact confirmation before writing.

## Encryption and boot contract

- LUKS2 is created on the Linux-LUKS partition; ext4 is created on the opened mapper.
- The current initramfs contract is systemd-based `sd-encrypt`, not the BusyBox `encrypt` hook.
- The UKI kernel command line uses `rd.luks.name=<UUID>=cryptroot` and `root=/dev/mapper/cryptroot`.
- The ESP must be mounted at the expected target path before UKI generation or future updates. A missing or incorrect ESP must stop the operation rather than writing into an ordinary root-directory mountpoint.
- The current installer checks that the generated UKI and command-line/preset artifacts exist. This file-presence check is not proof that firmware/systemd-boot can boot the UKI or unlock the intended root.
- The current installer does not establish external recovery-key storage or verify recovery-key slot registration. This remains an unresolved recovery requirement; do not claim recovery-key readiness.

## Swap and hibernation

The current plan computes swapfile target size as measured runtime RAM plus a configured 2 GiB margin. The X280's reported 8 GiB RAM is planning context only; runtime values control the plan. The target configuration creates `/swapfile`, mode 0600, initializes it, and adds it to fstab.

Resume is deliberately not configured. For ext4 swapfile resume, a future implementation must:
1. Calculate the physical swapfile offset using a supported method after creation.
2. Configure the correct unlocked mapper as resume device and the verified offset.
3. Recalculate/update configuration whenever the swapfile is recreated, resized, or relocated.
4. Rebuild and inspect the UKI and prove kernel-update lifecycle preserves correct resume settings.

Hibernation readiness is distinct from a successful hibernate/resume cycle. Actual hardware hibernation remains NOT TESTED.

## Recovery and interrupted runs

The Arch ISO USB is the recovery medium; no fallback UKI is currently promised. If an operation fails after the first destructive command, stop. Do not rerun the installer or issue cleanup commands blindly. Inspect the actual partition table, LUKS state, mapper, mounts, and filesystem state in a fresh session, preserve logs without secrets, and require human review before any further write.

The current installer does not provide a complete transactional rollback or automatic resume workflow. Its final cleanup/unmount and post-failure recovery path require further review before any further destructive physical trial.

## Acceptance status

Detailed test cases live in [11-TESTING-AND-ACCEPTANCE.md](11-TESTING-AND-ACCEPTANCE.md). Current state:
- IMPLEMENTED: target discovery/validation, plan calculation/binding, confirmation/final revalidation, initial destructive installer, base bootstrap, target configuration, and initial UKI generation on `main`.
- TESTED (bounded): fixture/static tests and selected descriptor-pinned utilities against a disposable loop-backed image on the CI-tested commit.
- TESTED: physical installer process completed in trial 4 with exit status 0 and UKI generation. NOT TESTED: successful boot from the installed SSD, firmware UKI discovery, LUKS unlock/root mount, First Boot/first login, recovery-key registration, and hibernation/resume.
- OUT OF SCOPE BY OWNER DECISION: VM-based installer testing. Disposable loop-image tests remain permitted for bounded utility-interface coverage; they do not replace the required real-laptop destructive test.
- PLANNED: tested recovery/cleanup lifecycle, reusable storage executor boundary, resume-offset workflow, and subsequent desktop/hardware setup.

A passing CI run or the presence of a UKI file is not authorization to erase a disk and is not proof of a successful boot.
