# Stage 9 — Interactive Arch installer (initial execution path)

Status: **IMPLEMENTED, NOT YET TESTED ON HARDWARE**.

Entry point:

```bash
sudo ./scripts/install-arch-x280.sh
```

Run from the official Arch ISO booted in UEFI mode. The script requires root and checks for the storage, Arch installation, and partitioning commands before showing a disk list. It selects only discovered writable, non-removable NVMe whole disks with a WWN or serial. The operator chooses the index and must type the exact destructive confirmation generated from the reviewed storage plan.

## Current actions

1. Discover and validate the selected NVMe target.
2. Calculate GPT/ESP/root geometry using the existing planner and runtime RAM.
3. Review target identity, layout, encryption, filesystem, and boot policy.
4. Require exact confirmation and refresh read-only prerequisites.
5. Recheck the selected disk identity before each external storage command.
6. Disable active swap, erase old signatures, create GPT + ESP + LUKS2 root partitions.
7. Format FAT32/ext4, open LUKS, mount at `/mnt` and `/mnt/efi`.
8. Install a minimal Arch base with `pacstrap -K`, generate UUID fstab, install systemd-boot, configure the encrypt initramfs hook, and enable NetworkManager.

## Critical limitations

- This is an initial real installer path, not the complete project installer.
- External tools open the device pathname independently. Rechecking major:minor, size, serial, and WWN before each operation reduces accidental target drift but does **not** close the kernel device-rebinding/TOCTOU window. The existing native helper's exclusive descriptor cannot safely be held while invoking utilities that independently open the same block device. Do not describe this script as race-proof.
- No automated hardware test has been run by maintainers. Do not run it against a disk containing data that is not backed up.
- The script currently stops after a minimal bootable base-system setup. Caelestia/Hyprland/Quickshell, user creation, locale/timezone/hostname, swapfile creation, resume configuration, X280 power/thermal tuning, and optional BlackArch are not installed by this stage.
- The first physical run must be treated as an integration test. Save the terminal output and test report, inspect the generated partition table and mounted system before reboot.

## Operator safety

The script is destructive. It must only be run from the Arch ISO after confirming the displayed model, capacity, stable identifier, and exact target path. A successful command sequence is not equivalent to a verified boot. If any step fails after partitioning begins, stop and inspect the disk; do not blindly rerun.
