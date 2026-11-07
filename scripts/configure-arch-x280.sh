#!/usr/bin/env bash
# Interactive first-boot configuration executed inside the newly installed target.
set -Eeuo pipefail
umask 077

die() { printf 'ERROR: %s\\n' "$*" >&2; exit 1; }
info() { printf 'INFO: %s\\n' "$*" >&2; }
prompt() {
  local __result=$1 label=$2 default=$3 answer
  [[ -r /dev/tty && -w /dev/tty ]] || die "Interactive terminal is required."
  IFS= read -r -p "$label [$default]: " answer </dev/tty
  printf -v "$__result" '%s' "${answer:-$default}"
}

(( EUID == 0 )) || die "Run as root inside arch-chroot."
[[ -f /etc/arch-release ]] || die "This script must run inside the installed Arch target."
[[ $# -eq 1 && $1 =~ ^[0-9]+$ && $1 -gt 0 ]] || die "Expected swapfile size in bytes."

swap_bytes=$1
hostname='' username='' timezone='' locale=''
root_fs="$(findmnt -nro FSTYPE /)"
[[ $root_fs == ext4 ]] || die "Expected ext4 root filesystem, found: $root_fs"

prompt hostname "Hostname" "thinkpad-x280"
[[ $hostname =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{0,62}$ ]] || die "Invalid hostname."
prompt username "Initial username" "kai"
[[ $username =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || die "Invalid username."
if id "$username" >/dev/null 2>&1; then die "User already exists: $username"; fi

prompt timezone "Timezone" "Asia/Jakarta"
[[ $timezone =~ ^[A-Za-z0-9_+.-]+(/[A-Za-z0-9_+.-]+)*$ && $timezone != *..* ]] || die "Invalid timezone path."
[[ -f "/usr/share/zoneinfo/$timezone" ]] || die "Unknown timezone: $timezone"
prompt locale "Locale" "en_US.UTF-8"
[[ $locale =~ ^[A-Za-z0-9_@.-]+\.UTF-8$ ]] || die "Invalid locale name."
grep -Eq "^[#[:space:]]*${locale}[[:space:]]+UTF-8([[:space:]]|$)" /etc/locale.gen || die "Locale is not present in /etc/locale.gen: $locale"

info "Installing Intel microcode."
pacman -S --needed --noconfirm intel-ucode

info "Configuring locale, timezone, and hostname."
sed -i -E "s/^[#[:space:]]*${locale}[[:space:]]+UTF-8/${locale} UTF-8/" /etc/locale.gen
locale-gen
printf 'LANG=%s\\n' "$locale" > /etc/locale.conf
ln -sfn "/usr/share/zoneinfo/$timezone" /etc/localtime
hwclock --systohc
printf '%s\\n' "$hostname" > /etc/hostname
cat > /etc/hosts <<EOF_HOSTS
127.0.0.1 localhost
::1       localhost
127.0.1.1 $hostname.localdomain $hostname
EOF_HOSTS

info "Creating the initial administrator account."
useradd --create-home --groups wheel --shell /bin/bash "$username"
visudo -cf /etc/sudoers >/dev/null
printf '%s\\n' '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/10-k41-wheel
chmod 0440 /etc/sudoers.d/10-k41-wheel
visudo -cf /etc/sudoers.d/10-k41-wheel >/dev/null
info "Set the password for $username (password input is not logged)."
passwd "$username"

if [[ -e /swapfile || -e /swapfile.k41.tmp ]]; then die "Swapfile path already exists; refusing to overwrite."; fi
info "Creating planned swapfile ($swap_bytes bytes)."
swap_tmp=/swapfile.k41.tmp
trap 'rm -f -- "$swap_tmp"' EXIT
fallocate -l "$swap_bytes" "$swap_tmp"
chmod 0600 "$swap_tmp"
mkswap "$swap_tmp"
mv -- "$swap_tmp" /swapfile
trap - EXIT
if ! grep -qE '^[[:space:]]*/swapfile[[:space:]]' /etc/fstab; then
  printf '%s\\n' '/swapfile none swap defaults 0 0' >> /etc/fstab
fi

systemctl enable NetworkManager
info "Initial target configuration completed."
info "Hibernation/resume remains disabled until the swapfile resume offset is explicitly configured and verified."
