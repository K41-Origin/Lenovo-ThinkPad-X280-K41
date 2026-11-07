# Stage 9 — Interactive Arch installer (initial execution path)

Status: **IMPLEMENTED, NOT YET TESTED ON HARDWARE**.

Entry point:

```bash
sudo ./scripts/install-arch-x280.sh
```

Run from the official Arch ISO booted in UEFI mode. The script requires root and checks for the storage, Arch installation, and partitioning commands before showing a disk list. It first verifies the host against the ThinkPad X280 inventory profile. It selects only discovered writable, non-removable NVMe whole disks with a WWN or serial, then requires the verified WDC PC SN730 model, exact capacity, and expected serial. The operator chooses the index and must type the exact destructive confirmation generated from the reviewed storage plan.

## Current actions

1. Discover and validate the selected NVMe target.
2. Calculate GPT/ESP/root geometry using the existing planner and runtime RAM.
3. Review target identity, layout, encryption, filesystem, and boot policy.
4. Require exact confirmation and refresh read-only prerequisites.
5. Recheck the selected disk identity before each external storage command.
6. Preserve unrelated live-ISO swap, erase old signatures, create GPT + ESP + Linux-LUKS-type root partitions.
7. Format FAT32/ext4, open LUKS, mount at `/mnt` and `/mnt/efi`.
8. Use the guarded `base_system::bootstrap` module to install the approved minimal Arch package set and generate UUID-based fstab.\n9. Run `scripts/configure-arch-x280.sh` inside the target to interactively set hostname, initial username/password, timezone, locale, Intel microcode, sudo access, and the planned ext4 swapfile.\n10. Install systemd-boot, configure a mkinitcpio UKI with the LUKS UUID kernel command line, and enable NetworkManager.

## Critical limitations

- This is an initial real installer path, not the complete project installer.
- The installer opens and retains the selected whole-disk and partition block descriptors in the Bash process, then passes inherited /proc/self/fd paths to wipefs, sgdisk, partprobe, cryptsetup, and mkfs tools. It checks that each retained descriptor matches the reviewed kernel major:minor identity and that the original /dev path still resolves to that descriptor. This avoids re-resolving the selected /dev pathname for the destructive tool opens. The isolated loop-device integration test exercises these tool interfaces. Physical NVMe hot-unplug/controller failure behavior and the complete hardware transaction remain untested; do not claim that the loop test proves all hardware races impossible.
- No automated hardware test has been run by maintainers. Do not run it against a disk containing data that is not backed up.
- The script currently stops after a minimal bootable base-system setup. It does not disable unrelated live-ISO swap. Caelestia/Hyprland/Quickshell, resume/hibernation, X280 power/thermal tuning, and optional BlackArch are not installed by this stage.
- The first physical run must be treated as an integration test. Save the terminal output and test report, inspect the generated partition table and mounted system before reboot.

## Operator safety

The script is destructive. It must only be run from the Arch ISO after confirming the displayed model, capacity, stable identifier, and exact target path. A successful command sequence is not equivalent to a verified boot. If any step fails after partitioning begins, stop and inspect the disk; do not blindly rerun.


## Automated checks

`tests/test-arch-installer-script.sh` and `tests/test-arch-config-script.sh` perform `bash -n` and static checks for the X280 hardware guard, confirmation/revalidation ordering, LUKS2 setup, guarded base bootstrap, user/sudo configuration, swapfile setup, and UKI settings. `tests/test-pinned-device-path.sh` additionally runs disk tools against a temporary loop-backed image using inherited pinned descriptors; it never targets a physical disk. These tests do not prove bootability or physical NVMe hot-unplug behavior. The complete suite includes this test through `bash tests/run.sh`.
