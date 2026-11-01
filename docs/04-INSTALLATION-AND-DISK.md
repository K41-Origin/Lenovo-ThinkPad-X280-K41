# Installation and Disk

## Approved direction
Use an official, unmodified Arch ISO from USB and an interactive TUI. Replace Windows (user reports no data to retain). Use LUKS, ext4, a swapfile, and hibernation readiness. Use one standard Arch linux kernel.

## Mandatory safety gates
1. Detect and report UEFI/BIOS mode.
2. Inventory disks and show model, capacity, and stable identifiers.
3. Display the complete partition, encryption, mount, and sizing plan with rationale.
4. Verify the target matches the intended SSD.
5. Require explicit final confirmation immediately before destructive operations.
6. Stop if disk identity or boot/encryption/resume compatibility is ambiguous.
7. Never automatically repartition or reformat after interruption.

## Storage constraints
- Plan encrypted root with LUKS and ext4; final layout depends on actual disk and boot mode.
- Explain external recovery-key storage and verify recovery key-slot registration. If external storage is not confirmed, report that honestly.
- Size swapfile after checking RAM, ext4 behavior, and hibernation requirements.
- Size EFI System Partition based on verified bootloader and kernel/initramfs placement.
- Select a bootloader only after compatibility with UEFI, LUKS, ext4, and resume is verified. Otherwise stop before destructive operations.
- Do not automatically install Intel microcode under the current decision; report recommendation.

## Hibernation
Configure resume only after swapfile and boot arrangement are verified. Readiness does not prove actual hibernation works; manual test remains NOT TESTED until performed.

## Bootstrap and recovery
The official Arch ISO does not automatically launch this project installer. Document safe retrieval and integrity verification; do not pipe remote scripts into a shell. After interruption inspect actual state and show the last recorded stage; never assume it is safe to wipe again.

## Acceptance
- [ ] Boot mode and target disk identity reported.
- [ ] Proposed layout shown before final confirmation.
- [ ] Encryption/boot config checked; recovery key-slot registration checked without logging key material.
- [ ] Hibernation readiness separated from actual test.
- [ ] Critical failure stops safely.
