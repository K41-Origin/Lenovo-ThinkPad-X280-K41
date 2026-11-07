#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
script="$ROOT/scripts/resume-arch-x280.sh"
[[ -s $script ]]
bash -n "$script"
# This recovery entry point must never repeat any destructive/bootstrap phase.
for forbidden in 'wipefs' 'luksFormat' 'mkfs.fat' 'mkfs.ext4' 'sgdisk --zap-all' 'pacstrap'; do
  if grep -Fq "$forbidden" "$script"; then
    printf 'FAIL: resume script contains forbidden operation: %s\n' "$forbidden" >&2
    exit 1
  fi
done
grep -Fq 'cryptsetup open "$root_part" cryptroot' "$script"
grep -Fq 'e2fsck -fn "$MAPPER"' "$script"
grep -Fq "base_system::generate_fstab" "$script"
grep -Fq 'pacman --root "$ROOT_MOUNT" -Q base linux linux-firmware' "$script"
grep -Fq 'arch-chroot "$ROOT_MOUNT" /root/k41-configure-arch-x280.sh' "$script"
grep -Fq 'mkinitcpio -P' "$script"
printf 'PASS: resume entry point validates existing target and continues after pacstrap/fstab without repartitioning, formatting, or rerunning pacstrap\n'
