#!/usr/bin/env bash
# Resume the known Stage 9 partial install after pacstrap succeeded and fstab
# generation failed. This script NEVER partitions, formats, or runs pacstrap.
set -Eeuo pipefail
umask 077

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=lib/common.sh
source "$ROOT/lib/common.sh"
# shellcheck source=lib/base-system.sh
source "$ROOT/lib/base-system.sh"

EXPECTED_MODEL='WDC PC SN730 SDBQNTY-256G-1001'
EXPECTED_SERIAL='193839803177'
EXPECTED_CAPACITY='256060514304'
EXPECTED_BY_ID='/dev/disk/by-id/nvme-WDC_PC_SN730_SDBQNTY-256G-1001_193839803177'
MAPPER=/dev/mapper/cryptroot
ROOT_MOUNT=/mnt
ESP_MOUNT=/mnt/efi
LOG_DIR=
LOG_FILE=
stage=bootstrap

die() { k41::log_error "$1"; exit 1; }
stage() { stage=$1; shift; printf '\n[STAGE] %s — %s\n' "$stage" "$*"; }

init_logging() {
  local base timestamp suffix=0
  command -v tee >/dev/null 2>&1 || return 1
  command -v install >/dev/null 2>&1 || return 1
  base=/var/log/x280-installer
  if ! install -d -o root -g root -m 0700 "$base" 2>/dev/null; then
    base=/run/x280-installer
    install -d -o root -g root -m 0700 "$base" || return 1
    printf 'WARNING: log is in volatile /run.\n' >&2
  fi
  printf -v timestamp '%(%Y%m%dT%H%M%SZ)T' -1
  LOG_DIR="$base/resume-$timestamp"
  while ! mkdir -m 0700 -- "$LOG_DIR" 2>/dev/null; do
    suffix=$((suffix + 1))
    LOG_DIR="$base/resume-$timestamp-$suffix"
  done
  LOG_FILE="$LOG_DIR/resume.log"
  : >"$LOG_FILE"
  chmod 0600 "$LOG_FILE"
  exec > >(tee -a "$LOG_FILE") 2>&1
  printf 'X280 installer resume log\nStarted (UTC): %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  printf 'Repository: %s\nCommit: %s\n' "$ROOT" "$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || printf unknown)"
}

on_exit() {
  local rc=$?
  if [[ -n $LOG_FILE ]]; then
    printf 'Finished (UTC): %s\nExit status: %s\nLast stage: %s\nLog: %s\n' \
      "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$rc" "$stage" "$LOG_FILE"
    if (( rc != 0 )); then
      printf 'STOP: no automatic rollback or unmount was attempted. Inspect /mnt and /dev/mapper/cryptroot before any further action.\n' >&2
    fi
  fi
}

need_root() { (( EUID == 0 )) || die 'Run as root from the official Arch ISO.'; }
need_commands() {
  local cmd
  for cmd in lsblk readlink blkid sgdisk cryptsetup e2fsck mount mountpoint findmnt blockdev pacman arch-chroot bootctl install mkinitcpio awk grep sed date tee; do
    command -v "$cmd" >/dev/null 2>&1 || die "Required command missing: $cmd"
  done
}

need_root
init_logging || { printf 'FATAL: secure logging could not be initialized.\n' >&2; exit 1; }
trap on_exit EXIT
need_commands
[[ -d /sys/firmware/efi ]] || die 'Boot the official Arch ISO in UEFI mode.'
[[ ! -e "$MAPPER" ]] || die 'cryptroot mapper already exists; inspect it manually.'
! mountpoint -q "$ROOT_MOUNT" || die '/mnt is already mounted; inspect mounts manually.'
[[ -e "$EXPECTED_BY_ID" ]] || die "Expected stable SSD alias is missing: $EXPECTED_BY_ID"

stage target-identity 'Verify the already-installed target without running readiness or changing partitions'
disk="$(readlink -f -- "$EXPECTED_BY_ID")"
[[ -b $disk ]] || die 'Stable SSD alias does not resolve to a block device.'
model="$(lsblk -dnro MODEL "$disk" | sed 's/[[:space:]]*$//')"
serial="$(lsblk -dnro SERIAL "$disk" | sed 's/[[:space:]]*$//')"
transport="$(lsblk -dnro TRAN "$disk" | sed 's/[[:space:]]*$//')"
removable="$(lsblk -dnro RM "$disk" | sed 's/[[:space:]]*$//')"
readonly_flag="$(lsblk -dnro RO "$disk" | sed 's/[[:space:]]*$//')"
size_bytes="$(blockdev --getsize64 "$disk")"
[[ $model == "$EXPECTED_MODEL" && $serial == "$EXPECTED_SERIAL" && $size_bytes == "$EXPECTED_CAPACITY" ]] || die 'SSD model, serial, or exact byte capacity does not match the configured X280 target.'
[[ $transport == nvme && $removable == 0 && $readonly_flag == 0 ]] || die 'Target is not a writable, non-removable NVMe device.'
[[ $(blkid -s PTTYPE -o value "$disk") == gpt ]] || die 'Target does not contain the expected GPT partition table.'

disk_name=${disk##*/}
esp="/dev/${disk_name}p1"
root_part="/dev/${disk_name}p2"
[[ -b $esp && -b $root_part ]] || die 'Expected partition nodes p1 and p2 are not both present.'
sgdisk -i 1 "$disk" | grep -qi 'EF00' || die 'Partition 1 is not the expected EFI System Partition type.'
sgdisk -i 2 "$disk" | grep -qi '8309' || die 'Partition 2 is not the expected Linux LUKS type.'
[[ $(blkid -s TYPE -o value "$esp") == vfat ]] || die 'Partition 1 is not FAT/vfat.'
cryptsetup isLuks "$root_part" || die 'Partition 2 is not a LUKS container.'
cryptsetup luksDump "$root_part" | grep -qE '^[[:space:]]*Version:[[:space:]]+2
stage unlock 'Unlock existing LUKS2 root; no format operation is performed'
cryptsetup open "$root_part" cryptroot || die 'Could not unlock the existing LUKS partition.'
[[ $(blkid -s TYPE -o value "$MAPPER") == ext4 ]] || die 'Unlocked root filesystem is not ext4.'

stage filesystem-check 'Run a read-only ext4 consistency check before mounting'
if ! e2fsck -fn "$MAPPER"; then
  die 'Read-only ext4 check reported errors. Do not mount read-write; recovery is required.'
fi

stage mount-target 'Mount existing root and EFI filesystems'
mkdir -p "$ROOT_MOUNT"
mount "$MAPPER" "$ROOT_MOUNT"
mkdir -p "$ESP_MOUNT"
mount "$esp" "$ESP_MOUNT"
base_system::validate_mounts "$ROOT_MOUNT" || die 'Mounted root/EFI layout does not match the expected encrypted ext4 + vfat structure.'

stage verify-pacstrap 'Confirm pacstrap completed; do not rerun pacstrap'
[[ -f "$ROOT_MOUNT/etc/arch-release" ]] || die 'Target does not contain /etc/arch-release.'
pacman --root "$ROOT_MOUNT" -Q base linux linux-firmware cryptsetup networkmanager sudo e2fsprogs dosfstools || die 'Required base packages are incomplete; stop for separate recovery review.'
[[ ! -e "$ROOT_MOUNT/swapfile" && ! -e "$ROOT_MOUNT/swapfile.k41.tmp" ]] || die 'A swapfile already exists; this is not the expected pre-configuration checkpoint.'
[[ ! -s "$ROOT_MOUNT/etc/hostname" && ! -s "$ROOT_MOUNT/etc/locale.conf" ]] || die 'Target configuration appears to have started already; do not repeat interactive configuration.'
[[ ! -s "$ESP_MOUNT/EFI/Linux/arch-linux.efi" ]] || die 'A UKI already exists; this target appears further along than the recorded failure checkpoint.'

stage fstab 'Merge UUID-based root and EFI entries without replacing existing unrelated data'
base_system::generate_fstab "$ROOT_MOUNT" 'WRITE FSTAB' || die 'Safe fstab generation failed.'

stage target-configuration 'Continue the initial target configuration (interactive prompts)'
ram_kib="$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)"
[[ $ram_kib =~ ^[0-9]+$ ]] || die 'Could not determine live RAM size for the planned swapfile.'
swap_bytes=$((ram_kib * 1024 + 2 * 1024 * 1024 * 1024))
install -m 0700 "$ROOT/scripts/configure-arch-x280.sh" "$ROOT_MOUNT/root/k41-configure-arch-x280.sh"
arch-chroot "$ROOT_MOUNT" /root/k41-configure-arch-x280.sh "$swap_bytes" || die 'Interactive target configuration failed; inspect partial configuration before retrying.'
rm -f -- "$ROOT_MOUNT/root/k41-configure-arch-x280.sh"
install -D -m 0755 "$ROOT/scripts/x280-first-boot-check.sh" "$ROOT_MOUNT/usr/local/sbin/x280-first-boot-check"
[[ -x "$ROOT_MOUNT/usr/local/sbin/x280-first-boot-check" ]] || die 'First-boot evidence collector was not installed.'

stage boot-configuration 'Install systemd-boot and build the encrypted-root UKI'
arch-chroot "$ROOT_MOUNT" bootctl --esp-path=/efi install
root_uuid="$(blkid -s UUID -o value "$root_part")"
[[ -n $root_uuid ]] || die 'LUKS UUID could not be read.'
arch-chroot "$ROOT_MOUNT" /bin/bash -euo pipefail <<CHROOT
sed -i 's|^HOOKS=.*|HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block sd-encrypt filesystems fsck)|' /etc/mkinitcpio.conf
mkdir -p /efi/EFI/Linux /etc/kernel
printf '%s\n' 'rd.luks.name=$root_uuid=cryptroot root=/dev/mapper/cryptroot rw' > /etc/kernel/cmdline
sed -i -e "s/^PRESETS=.*/PRESETS=('default')/" -e '/^fallback_/d' -e '/^default_uki=/d' -e '/^default_image=/d' -e '/^default_cmdline=/d' /etc/mkinitcpio.d/linux.preset
printf '%s\n' 'default_uki="/efi/EFI/Linux/arch-linux.efi"' 'default_cmdline="/etc/kernel/cmdline"' >> /etc/mkinitcpio.d/linux.preset
systemctl enable NetworkManager
mkinitcpio -P
[[ -s /efi/EFI/Linux/arch-linux.efi ]]
[[ -s /etc/kernel/cmdline ]]
grep -q '^rd.luks.name=' /etc/kernel/cmdline
grep -q '^root=/dev/mapper/cryptroot' /etc/kernel/cmdline
CHROOT

stage completion 'Validate the resumed base Arch installation'
[[ -s "$ROOT_MOUNT/etc/fstab" ]] || die 'Target fstab is missing.'
grep -qE '^[^#].+[[:space:]]+/swapfile[[:space:]]+swap[[:space:]]' "$ROOT_MOUNT/etc/fstab" || die 'Swapfile entry is missing from fstab.'
[[ -s "$ESP_MOUNT/EFI/Linux/arch-linux.efi" ]] || die 'UKI was not created.'
[[ -s "$ROOT_MOUNT/etc/hostname" && -s "$ROOT_MOUNT/etc/locale.conf" && -L "$ROOT_MOUNT/etc/localtime" ]] || die 'Hostname, locale, or timezone configuration is incomplete.'
k41::log_info 'Initial encrypted Arch base installation has reached the completion checkpoint.'
k41::log_warn 'No reboot was performed. Inspect the result, then unmount /mnt/efi and /mnt and close cryptroot manually.'
k41::log_warn 'Desktop integration, X280 tuning, hibernation/resume, recovery-key handling, and selective BlackArch remain unimplemented.'
 || die 'Root container is not LUKS2.'

stage unlock 'Unlock existing LUKS2 root; no format operation is performed'
cryptsetup open "$root_part" cryptroot || die 'Could not unlock the existing LUKS partition.'
[[ $(blkid -s TYPE -o value "$MAPPER") == ext4 ]] || die 'Unlocked root filesystem is not ext4.'

stage filesystem-check 'Run a read-only ext4 consistency check before mounting'
if ! e2fsck -fn "$MAPPER"; then
  die 'Read-only ext4 check reported errors. Do not mount read-write; recovery is required.'
fi

stage mount-target 'Mount existing root and EFI filesystems'
mkdir -p "$ROOT_MOUNT"
mount "$MAPPER" "$ROOT_MOUNT"
mkdir -p "$ESP_MOUNT"
mount "$esp" "$ESP_MOUNT"
base_system::validate_mounts "$ROOT_MOUNT" || die 'Mounted root/EFI layout does not match the expected encrypted ext4 + vfat structure.'

stage verify-pacstrap 'Confirm pacstrap completed; do not rerun pacstrap'
[[ -f "$ROOT_MOUNT/etc/arch-release" ]] || die 'Target does not contain /etc/arch-release.'
pacman --root "$ROOT_MOUNT" -Q base linux linux-firmware cryptsetup networkmanager sudo e2fsprogs dosfstools || die 'Required base packages are incomplete; stop for separate recovery review.'
[[ ! -e "$ROOT_MOUNT/swapfile" && ! -e "$ROOT_MOUNT/swapfile.k41.tmp" ]] || die 'A swapfile already exists; this is not the expected pre-configuration checkpoint.'
[[ ! -s "$ROOT_MOUNT/etc/hostname" && ! -s "$ROOT_MOUNT/etc/locale.conf" ]] || die 'Target configuration appears to have started already; do not repeat interactive configuration.'
[[ ! -s "$ESP_MOUNT/EFI/Linux/arch-linux.efi" ]] || die 'A UKI already exists; this target appears further along than the recorded failure checkpoint.'

stage fstab 'Merge UUID-based root and EFI entries without replacing existing unrelated data'
base_system::generate_fstab "$ROOT_MOUNT" 'WRITE FSTAB' || die 'Safe fstab generation failed.'

stage target-configuration 'Continue the initial target configuration (interactive prompts)'
ram_kib="$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)"
[[ $ram_kib =~ ^[0-9]+$ ]] || die 'Could not determine live RAM size for the planned swapfile.'
swap_bytes=$((ram_kib * 1024 + 2 * 1024 * 1024 * 1024))
install -m 0700 "$ROOT/scripts/configure-arch-x280.sh" "$ROOT_MOUNT/root/k41-configure-arch-x280.sh"
arch-chroot "$ROOT_MOUNT" /root/k41-configure-arch-x280.sh "$swap_bytes" || die 'Interactive target configuration failed; inspect partial configuration before retrying.'
rm -f -- "$ROOT_MOUNT/root/k41-configure-arch-x280.sh"
install -D -m 0755 "$ROOT/scripts/x280-first-boot-check.sh" "$ROOT_MOUNT/usr/local/sbin/x280-first-boot-check"
[[ -x "$ROOT_MOUNT/usr/local/sbin/x280-first-boot-check" ]] || die 'First-boot evidence collector was not installed.'

stage boot-configuration 'Install systemd-boot and build the encrypted-root UKI'
arch-chroot "$ROOT_MOUNT" bootctl --esp-path=/efi install
root_uuid="$(blkid -s UUID -o value "$root_part")"
[[ -n $root_uuid ]] || die 'LUKS UUID could not be read.'
arch-chroot "$ROOT_MOUNT" /bin/bash -euo pipefail <<CHROOT
sed -i 's|^HOOKS=.*|HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block sd-encrypt filesystems fsck)|' /etc/mkinitcpio.conf
mkdir -p /efi/EFI/Linux /etc/kernel
printf '%s\n' 'rd.luks.name=$root_uuid=cryptroot root=/dev/mapper/cryptroot rw' > /etc/kernel/cmdline
sed -i -e "s/^PRESETS=.*/PRESETS=('default')/" -e '/^fallback_/d' -e '/^default_uki=/d' -e '/^default_image=/d' -e '/^default_cmdline=/d' /etc/mkinitcpio.d/linux.preset
printf '%s\n' 'default_uki="/efi/EFI/Linux/arch-linux.efi"' 'default_cmdline="/etc/kernel/cmdline"' >> /etc/mkinitcpio.d/linux.preset
systemctl enable NetworkManager
mkinitcpio -P
[[ -s /efi/EFI/Linux/arch-linux.efi ]]
[[ -s /etc/kernel/cmdline ]]
grep -q '^rd.luks.name=' /etc/kernel/cmdline
grep -q '^root=/dev/mapper/cryptroot' /etc/kernel/cmdline
CHROOT

stage completion 'Validate the resumed base Arch installation'
[[ -s "$ROOT_MOUNT/etc/fstab" ]] || die 'Target fstab is missing.'
grep -qE '^[^#].+[[:space:]]+/swapfile[[:space:]]+swap[[:space:]]' "$ROOT_MOUNT/etc/fstab" || die 'Swapfile entry is missing from fstab.'
[[ -s "$ESP_MOUNT/EFI/Linux/arch-linux.efi" ]] || die 'UKI was not created.'
[[ -s "$ROOT_MOUNT/etc/hostname" && -s "$ROOT_MOUNT/etc/locale.conf" && -L "$ROOT_MOUNT/etc/localtime" ]] || die 'Hostname, locale, or timezone configuration is incomplete.'
k41::log_info 'Initial encrypted Arch base installation has reached the completion checkpoint.'
k41::log_warn 'No reboot was performed. Inspect the result, then unmount /mnt/efi and /mnt and close cryptroot manually.'
k41::log_warn 'Desktop integration, X280 tuning, hibernation/resume, recovery-key handling, and selective BlackArch remain unimplemented.'
 || die 'Root container is not LUKS2.'

stage unlock 'Unlock existing LUKS2 root; no format operation is performed'
cryptsetup open "$root_part" cryptroot || die 'Could not unlock the existing LUKS partition.'
[[ $(blkid -s TYPE -o value "$MAPPER") == ext4 ]] || die 'Unlocked root filesystem is not ext4.'

stage filesystem-check 'Run a read-only ext4 consistency check before mounting'
if ! e2fsck -fn "$MAPPER"; then
  die 'Read-only ext4 check reported errors. Do not mount read-write; recovery is required.'
fi

stage mount-target 'Mount existing root and EFI filesystems'
mkdir -p "$ROOT_MOUNT"
mount "$MAPPER" "$ROOT_MOUNT"
mkdir -p "$ESP_MOUNT"
mount "$esp" "$ESP_MOUNT"
base_system::validate_mounts "$ROOT_MOUNT" || die 'Mounted root/EFI layout does not match the expected encrypted ext4 + vfat structure.'

stage verify-pacstrap 'Confirm pacstrap completed; do not rerun pacstrap'
[[ -f "$ROOT_MOUNT/etc/arch-release" ]] || die 'Target does not contain /etc/arch-release.'
pacman --root "$ROOT_MOUNT" -Q base linux linux-firmware cryptsetup networkmanager sudo e2fsprogs dosfstools || die 'Required base packages are incomplete; stop for separate recovery review.'
[[ ! -e "$ROOT_MOUNT/swapfile" && ! -e "$ROOT_MOUNT/swapfile.k41.tmp" ]] || die 'A swapfile already exists; this is not the expected pre-configuration checkpoint.'
[[ ! -s "$ROOT_MOUNT/etc/hostname" && ! -s "$ROOT_MOUNT/etc/locale.conf" ]] || die 'Target configuration appears to have started already; do not repeat interactive configuration.'
[[ ! -s "$ESP_MOUNT/EFI/Linux/arch-linux.efi" ]] || die 'A UKI already exists; this target appears further along than the recorded failure checkpoint.'

stage fstab 'Merge UUID-based root and EFI entries without replacing existing unrelated data'
base_system::generate_fstab "$ROOT_MOUNT" 'WRITE FSTAB' || die 'Safe fstab generation failed.'

stage target-configuration 'Continue the initial target configuration (interactive prompts)'
ram_kib="$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)"
[[ $ram_kib =~ ^[0-9]+$ ]] || die 'Could not determine live RAM size for the planned swapfile.'
swap_bytes=$((ram_kib * 1024 + 2 * 1024 * 1024 * 1024))
install -m 0700 "$ROOT/scripts/configure-arch-x280.sh" "$ROOT_MOUNT/root/k41-configure-arch-x280.sh"
arch-chroot "$ROOT_MOUNT" /root/k41-configure-arch-x280.sh "$swap_bytes" || die 'Interactive target configuration failed; inspect partial configuration before retrying.'
rm -f -- "$ROOT_MOUNT/root/k41-configure-arch-x280.sh"
install -D -m 0755 "$ROOT/scripts/x280-first-boot-check.sh" "$ROOT_MOUNT/usr/local/sbin/x280-first-boot-check"
[[ -x "$ROOT_MOUNT/usr/local/sbin/x280-first-boot-check" ]] || die 'First-boot evidence collector was not installed.'

stage boot-configuration 'Install systemd-boot and build the encrypted-root UKI'
arch-chroot "$ROOT_MOUNT" bootctl --esp-path=/efi install
root_uuid="$(blkid -s UUID -o value "$root_part")"
[[ -n $root_uuid ]] || die 'LUKS UUID could not be read.'
arch-chroot "$ROOT_MOUNT" /bin/bash -euo pipefail <<CHROOT
sed -i 's|^HOOKS=.*|HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block sd-encrypt filesystems fsck)|' /etc/mkinitcpio.conf
mkdir -p /efi/EFI/Linux /etc/kernel
printf '%s\n' 'rd.luks.name=$root_uuid=cryptroot root=/dev/mapper/cryptroot rw' > /etc/kernel/cmdline
sed -i -e "s/^PRESETS=.*/PRESETS=('default')/" -e '/^fallback_/d' -e '/^default_uki=/d' -e '/^default_image=/d' -e '/^default_cmdline=/d' /etc/mkinitcpio.d/linux.preset
printf '%s\n' 'default_uki="/efi/EFI/Linux/arch-linux.efi"' 'default_cmdline="/etc/kernel/cmdline"' >> /etc/mkinitcpio.d/linux.preset
systemctl enable NetworkManager
mkinitcpio -P
[[ -s /efi/EFI/Linux/arch-linux.efi ]]
[[ -s /etc/kernel/cmdline ]]
grep -q '^rd.luks.name=' /etc/kernel/cmdline
grep -q '^root=/dev/mapper/cryptroot' /etc/kernel/cmdline
CHROOT

stage completion 'Validate the resumed base Arch installation'
[[ -s "$ROOT_MOUNT/etc/fstab" ]] || die 'Target fstab is missing.'
grep -qE '^[^#].+[[:space:]]+/swapfile[[:space:]]+swap[[:space:]]' "$ROOT_MOUNT/etc/fstab" || die 'Swapfile entry is missing from fstab.'
[[ -s "$ESP_MOUNT/EFI/Linux/arch-linux.efi" ]] || die 'UKI was not created.'
[[ -s "$ROOT_MOUNT/etc/hostname" && -s "$ROOT_MOUNT/etc/locale.conf" && -L "$ROOT_MOUNT/etc/localtime" ]] || die 'Hostname, locale, or timezone configuration is incomplete.'
k41::log_info 'Initial encrypted Arch base installation has reached the completion checkpoint.'
k41::log_warn 'No reboot was performed. Inspect the result, then unmount /mnt/efi and /mnt and close cryptroot manually.'
k41::log_warn 'Desktop integration, X280 tuning, hibernation/resume, recovery-key handling, and selective BlackArch remain unimplemented.'
 || die 'Root container is not LUKS2.'

stage unlock 'Unlock existing LUKS2 root; no format operation is performed'
cryptsetup open "$root_part" cryptroot || die 'Could not unlock the existing LUKS partition.'
[[ $(blkid -s TYPE -o value "$MAPPER") == ext4 ]] || die 'Unlocked root filesystem is not ext4.'

stage filesystem-check 'Run a read-only ext4 consistency check before mounting'
if ! e2fsck -fn "$MAPPER"; then
  die 'Read-only ext4 check reported errors. Do not mount read-write; recovery is required.'
fi

stage mount-target 'Mount existing root and EFI filesystems'
mkdir -p "$ROOT_MOUNT"
mount "$MAPPER" "$ROOT_MOUNT"
mkdir -p "$ESP_MOUNT"
mount "$esp" "$ESP_MOUNT"
base_system::validate_mounts "$ROOT_MOUNT" || die 'Mounted root/EFI layout does not match the expected encrypted ext4 + vfat structure.'

stage verify-pacstrap 'Confirm pacstrap completed; do not rerun pacstrap'
[[ -f "$ROOT_MOUNT/etc/arch-release" ]] || die 'Target does not contain /etc/arch-release.'
pacman --root "$ROOT_MOUNT" -Q base linux linux-firmware cryptsetup networkmanager sudo e2fsprogs dosfstools || die 'Required base packages are incomplete; stop for separate recovery review.'
[[ ! -e "$ROOT_MOUNT/swapfile" && ! -e "$ROOT_MOUNT/swapfile.k41.tmp" ]] || die 'A swapfile already exists; this is not the expected pre-configuration checkpoint.'
[[ ! -s "$ROOT_MOUNT/etc/hostname" && ! -s "$ROOT_MOUNT/etc/locale.conf" ]] || die 'Target configuration appears to have started already; do not repeat interactive configuration.'
[[ ! -s "$ESP_MOUNT/EFI/Linux/arch-linux.efi" ]] || die 'A UKI already exists; this target appears further along than the recorded failure checkpoint.'

stage fstab 'Merge UUID-based root and EFI entries without replacing existing unrelated data'
base_system::generate_fstab "$ROOT_MOUNT" 'WRITE FSTAB' || die 'Safe fstab generation failed.'

stage target-configuration 'Continue the initial target configuration (interactive prompts)'
ram_kib="$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)"
[[ $ram_kib =~ ^[0-9]+$ ]] || die 'Could not determine live RAM size for the planned swapfile.'
swap_bytes=$((ram_kib * 1024 + 2 * 1024 * 1024 * 1024))
install -m 0700 "$ROOT/scripts/configure-arch-x280.sh" "$ROOT_MOUNT/root/k41-configure-arch-x280.sh"
arch-chroot "$ROOT_MOUNT" /root/k41-configure-arch-x280.sh "$swap_bytes" || die 'Interactive target configuration failed; inspect partial configuration before retrying.'
rm -f -- "$ROOT_MOUNT/root/k41-configure-arch-x280.sh"
install -D -m 0755 "$ROOT/scripts/x280-first-boot-check.sh" "$ROOT_MOUNT/usr/local/sbin/x280-first-boot-check"
[[ -x "$ROOT_MOUNT/usr/local/sbin/x280-first-boot-check" ]] || die 'First-boot evidence collector was not installed.'

stage boot-configuration 'Install systemd-boot and build the encrypted-root UKI'
arch-chroot "$ROOT_MOUNT" bootctl --esp-path=/efi install
root_uuid="$(blkid -s UUID -o value "$root_part")"
[[ -n $root_uuid ]] || die 'LUKS UUID could not be read.'
arch-chroot "$ROOT_MOUNT" /bin/bash -euo pipefail <<CHROOT
sed -i 's|^HOOKS=.*|HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block sd-encrypt filesystems fsck)|' /etc/mkinitcpio.conf
mkdir -p /efi/EFI/Linux /etc/kernel
printf '%s\n' 'rd.luks.name=$root_uuid=cryptroot root=/dev/mapper/cryptroot rw' > /etc/kernel/cmdline
sed -i -e "s/^PRESETS=.*/PRESETS=('default')/" -e '/^fallback_/d' -e '/^default_uki=/d' -e '/^default_image=/d' -e '/^default_cmdline=/d' /etc/mkinitcpio.d/linux.preset
printf '%s\n' 'default_uki="/efi/EFI/Linux/arch-linux.efi"' 'default_cmdline="/etc/kernel/cmdline"' >> /etc/mkinitcpio.d/linux.preset
systemctl enable NetworkManager
mkinitcpio -P
[[ -s /efi/EFI/Linux/arch-linux.efi ]]
[[ -s /etc/kernel/cmdline ]]
grep -q '^rd.luks.name=' /etc/kernel/cmdline
grep -q '^root=/dev/mapper/cryptroot' /etc/kernel/cmdline
CHROOT

stage completion 'Validate the resumed base Arch installation'
[[ -s "$ROOT_MOUNT/etc/fstab" ]] || die 'Target fstab is missing.'
grep -qE '^[^#].+[[:space:]]+/swapfile[[:space:]]+swap[[:space:]]' "$ROOT_MOUNT/etc/fstab" || die 'Swapfile entry is missing from fstab.'
[[ -s "$ESP_MOUNT/EFI/Linux/arch-linux.efi" ]] || die 'UKI was not created.'
[[ -s "$ROOT_MOUNT/etc/hostname" && -s "$ROOT_MOUNT/etc/locale.conf" && -L "$ROOT_MOUNT/etc/localtime" ]] || die 'Hostname, locale, or timezone configuration is incomplete.'
k41::log_info 'Initial encrypted Arch base installation has reached the completion checkpoint.'
k41::log_warn 'No reboot was performed. Inspect the result, then unmount /mnt/efi and /mnt and close cryptroot manually.'
k41::log_warn 'Desktop integration, X280 tuning, hibernation/resume, recovery-key handling, and selective BlackArch remain unimplemented.'
