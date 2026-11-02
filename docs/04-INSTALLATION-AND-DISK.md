# Installation and Disk

## Approved direction

- Boot the official, unmodified Arch Linux ISO from USB. The ISO does not automatically launch this project installer; the installer is started manually from the ISO environment.
- Use UEFI boot with a GPT partition table. Stop before destructive operations if the machine is not booted in UEFI mode.
- Replace the existing Windows installation. The user reports that no data needs to be retained; this does not waive the mandatory target-disk checks and final confirmation below.
- Use one 1 GiB FAT32 EFI System Partition (ESP), mounted at `/efi`.
- Use systemd-boot and a Unified Kernel Image (UKI) generated natively by mkinitcpio. The default UKI path is `/efi/EFI/Linux/arch-linux.efi`.
- Keep the kernel package files and mkinitcpio configuration on the encrypted root filesystem under `/boot`. The ESP must be mounted when generating or updating the UKI.
- Use the official Arch `linux` kernel; do not install an alternative kernel under the current decision.
- Use one LUKS2 container for root, with ext4 directly on the unlocked mapper device. Do not introduce LVM.
- Use a swapfile inside the encrypted ext4 root filesystem to prepare for hibernation. Determine its size only after inspecting actual RAM, available disk space, and the agreed hibernation policy.
- Secure Boot is disabled under the current decision. The UKI is therefore not signed or authenticated by Secure Boot; the ESP remains exposed to offline modification.
- Do not automatically install Intel microcode under the current decision; report the recommendation instead.

These are approved architecture decisions, not proof that the installer implementation or resulting system has been tested. Exact mkinitcpio hook ordering, kernel command line, resume configuration, package behavior, and end-to-end boot must be verified before destructive installation is enabled.

## Mandatory safety gates

1. Detect and report firmware boot mode. Require UEFI for the approved layout.
2. Inventory disks and show model, capacity, and stable identifiers.
3. Display the complete partition, encryption, filesystem, mount, swap, and boot plan with rationale.
4. Verify that the selected target matches the intended internal SSD using stable identifiers; do not rely on device names alone.
5. Require explicit final confirmation immediately before destructive operations, after showing the complete target-specific plan.
6. Stop if disk identity, partitioning, encryption, boot, or resume compatibility is ambiguous.
7. Never automatically repartition or reformat after interruption.
8. Keep partitioning, formatting, and other destructive storage operations exclusively in `lib/storage.sh`.
9. Never log encryption passphrases, recovery keys, or other key material.

## Storage layout

The approved logical layout is:

| Partition / device | Filesystem / format | Mount / purpose |
| --- | --- | --- |
| GPT ESP, 1 GiB | FAT32 | `/efi`; systemd-boot and generated UKI |
| Remaining target space | LUKS2 container | Encrypted root container |
| Unlocked LUKS mapper | ext4 | Root filesystem; kernel files, mkinitcpio configuration, and swapfile |

The installer must calculate and present exact partition boundaries and sizes from the detected target before asking for confirmation. Do not assume the remaining disk space is available without inspecting the actual device.

The ESP must be mounted at `/efi` before UKI generation. If it is missing or not the expected ESP, kernel/UKI update operations must fail visibly. They must not silently create or update files in an ordinary `/efi` directory on the root filesystem. A failed UKI build or copy must not overwrite or remove the last known-good UKI.

The default UKI is required. A separate fallback UKI is not required for the initial installation; the official Arch ISO USB is the recovery medium. Reconsider a fallback only after measuring the actual UKI size and available ESP headroom.

## Encryption and recovery

- Use LUKS2 for the root container and ext4 directly on the unlocked mapper device.
- Explain external recovery-key storage and verify recovery-key slot registration without exposing key material. If external storage or registration cannot be confirmed, report that honestly and stop where the recovery policy requires it.
- Use the systemd-based mkinitcpio `sd-encrypt` approach as the current implementation candidate. Verify the exact hook order, crypt device identification, kernel command line, and generated UKI contents against current Arch documentation before enabling destructive installation.
- Verify that the generated boot configuration unlocks the intended LUKS device and mounts the correct root filesystem.

## Swap and hibernation

- Create the swapfile inside the encrypted ext4 root filesystem.
- Choose swapfile size only after checking actual RAM, available space, and hibernation requirements; do not hardcode a size based only on the reported 8 GiB RAM and 256 GB SSD.
- Configure resume to use the unlocked mapper device and the correct physical swapfile offset.
- For an ext4 swapfile, calculate the physical offset using a suitable supported method after creation. Recalculate and update the resume configuration whenever the swapfile is created, resized, replaced, or relocated.
- Verify initramfs/UKI resume configuration and the resulting boot entry before claiming hibernation readiness.

Hibernation readiness does not prove that suspend-to-disk works. A real hibernate-and-resume cycle must be tested on the target hardware; until then, actual hibernation remains NOT TESTED.

## Bootstrap and recovery

- Retrieve the project at the latest `main` revision for each installation attempt and display the resolved commit SHA.
- Retrieve and review project code before execution. Do not pipe remote scripts directly into a shell, especially with elevated privileges.
- Document integrity verification and safe manual launch from the official Arch ISO.
- After interruption, inspect the actual disk and filesystem state and show the last recorded stage. Never assume it is safe to wipe or resume automatically.
- The Arch ISO USB remains the recovery medium; do not claim that a fallback UKI exists unless one has actually been implemented and verified.

## Acceptance

- [ ] Installer confirms UEFI mode and GPT target identity before proposing changes.
- [ ] Exact partition boundaries, sizes, encryption, filesystem, mount, swap, and boot plan are displayed before final confirmation.
- [ ] ESP is FAT32, 1 GiB, and mounted at `/efi`.
- [ ] Root uses LUKS2 with ext4 directly on the unlocked mapper device.
- [ ] systemd-boot and the native mkinitcpio UKI path are verified.
- [ ] Kernel/UKI updates fail visibly if the expected ESP is not mounted and preserve the last known-good UKI on failure.
- [ ] Encryption and boot configuration are checked; recovery-key slot registration is checked without logging key material.
- [ ] Swapfile size and physical resume offset are calculated from the actual installation state.
- [ ] Hibernation readiness is distinguished from a successful hardware hibernation test.
- [ ] Critical failures stop safely; interrupted runs never trigger automatic repartitioning or formatting.
