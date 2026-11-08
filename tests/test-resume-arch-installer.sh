#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
script="$ROOT/scripts/resume-arch-x280.sh"
[[ -s $script ]]
bash -n "$script"
# This recovery entry point must never repeat any destructive/bootstrap phase.
if grep -Eq '^[[:space:]]*(run_step[[:space:]].*[[:space:]])?(wipefs|pacstrap|mkfs\.fat|mkfs\.ext4|cryptsetup[[:space:]]+luksFormat|sgdisk[[:space:]]+--zap-all)([[:space:]]|$)' "$script"; then
  printf 'FAIL: resume script contains a destructive/bootstrap command\\n' >&2
  exit 1
fi
grep -Fq 'cryptsetup open "$root_part" cryptroot' "$script"
grep -Fq 'base="$ROOT/reports/installer"' "$script"
grep -Fq 'findmnt -nro FSTYPE -T "$ROOT"' "$script"
if grep -Eq '/var/log/x280-installer|/run/x280-installer' "$script"; then
  printf 'FAIL: continuation logs must remain inside the repository checkout\\n' >&2
  exit 1
fi
grep -Fq '[[ -e $log_dir ]] ||' "$script"
grep -Fq 'e2fsck -fn "$MAPPER"' "$script"
grep -Fq "base_system::generate_fstab" "$script"
grep -Fq 'pacman --root "$ROOT_MOUNT" -Q base linux linux-firmware' "$script"
grep -Fq 'arch-chroot "$ROOT_MOUNT" /root/k41-configure-arch-x280.sh' "$script"
grep -Fq 'mkinitcpio -P' "$script"
printf 'PASS: resume entry point validates existing target and continues after pacstrap/fstab without repartitioning, formatting, or rerunning pacstrap\n'
