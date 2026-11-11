#!/usr/bin/env bash
# Install the K41 Plymouth theme and regenerate the existing Arch UKI.
# Does not edit mkinitcpio hooks/kernel cmdline, boot entries, LUKS, TPM,
# systemd units, getty/autologin, or desktop-session configuration.
set -Eeuo pipefail
umask 077

die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
info() { printf 'INFO: %s\n' "$*"; }

(( EUID == 0 )) || die "Run with sudo: sudo bash stages/stage-5-desktop-customization/workstreams/01-boot-experience/scripts/k41-install-plymouth-theme.sh"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
SOURCE_DIR="$SCRIPT_DIR/../themes/plymouth/k41"
THEME_DIR="/usr/share/plymouth/themes/k41"
MKINITCPIO_CONF="/etc/mkinitcpio.conf"
KERNEL_CMDLINE="/etc/kernel/cmdline"
LINUX_PRESET="/etc/mkinitcpio.d/linux.preset"
EFI_MOUNT="/efi"

for command_name in \
    date findmnt grep install mountpoint mkinitcpio plymouth-set-default-theme \
    sed stat; do
    command -v "$command_name" >/dev/null 2>&1 || die "Required command is unavailable: $command_name"
done

[[ -d /sys/firmware/efi ]] || die "UEFI firmware mode is required."
[[ -r $MKINITCPIO_CONF ]] || die "Missing $MKINITCPIO_CONF."
[[ -r $KERNEL_CMDLINE ]] || die "Missing $KERNEL_CMDLINE."
[[ -r $LINUX_PRESET ]] || die "Missing $LINUX_PRESET."
[[ -s $SOURCE_DIR/k41.plymouth && -s $SOURCE_DIR/k41.script ]] || die "K41 Plymouth theme source is incomplete."
mountpoint -q "$EFI_MOUNT" || die "$EFI_MOUNT is not mounted; refusing to rebuild an unmounted EFI path."
[[ "$(findmnt -nro FSTYPE --target "$EFI_MOUNT")" == "vfat" ]] || die "$EFI_MOUNT is not a vfat EFI filesystem."

# Validate the existing systemd-initramfs + encrypted-root hook order.
# The installer deliberately refuses to rewrite HOOKS automatically.
mapfile -t hook_assignments < <(grep -E '^[[:space:]]*HOOKS[[:space:]]*=' "$MKINITCPIO_CONF" || true)
(( ${#hook_assignments[@]} == 1 )) || die "Expected exactly one active HOOKS assignment in $MKINITCPIO_CONF."

hook_line=${hook_assignments[0]}
[[ $hook_line =~ ^[[:space:]]*HOOKS[[:space:]]*=[[:space:]]*\(([^)]*)\)[[:space:]]*(#.*)?$ ]] ||
    die "Unsupported HOOKS syntax; refusing to guess the active initramfs configuration."
read -r -a hooks <<< "${BASH_REMATCH[1]}"

hook_index() {
    local wanted=$1 index
    for index in "${!hooks[@]}"; do
        if [[ ${hooks[index]} == "$wanted" ]]; then
            printf '%s\n' "$index"
            return 0
        fi
    done
    return 1
}

systemd_index="$(hook_index systemd)" || die "The systemd hook is missing."
plymouth_index="$(hook_index plymouth)" || die "The Plymouth hook is missing."
encrypt_index="$(hook_index sd-encrypt)" || die "The sd-encrypt hook is missing."
(( systemd_index < plymouth_index && plymouth_index < encrypt_index )) ||
    die "Invalid hook order; expected systemd -> plymouth -> sd-encrypt."

grep -Eq '(^|[[:space:]])splash([[:space:]]|$)' "$KERNEL_CMDLINE" ||
    die "The existing UKI command line is missing the splash argument."

# Read the configured UKI destination without sourcing the preset as shell code.
mapfile -t uki_paths < <(sed -nE 's/^[[:space:]]*default_uki="([^"]+)".*/\1/p' "$LINUX_PRESET")
(( ${#uki_paths[@]} == 1 )) || die "Expected exactly one double-quoted default_uki in $LINUX_PRESET."
UKI_PATH=${uki_paths[0]}
[[ $UKI_PATH == "$EFI_MOUNT/"* && $UKI_PATH != *"/../"* ]] ||
    die "The configured UKI path is outside $EFI_MOUNT: $UKI_PATH"
[[ -s $UKI_PATH ]] || die "The configured UKI does not exist or is empty: $UKI_PATH"

[[ ! -L $THEME_DIR ]] || die "Refusing to write through a symlink: $THEME_DIR"
[[ -d /usr/share/plymouth/themes ]] || die "Plymouth theme directory is missing; install the signed Arch plymouth package first."
command -v plymouth >/dev/null 2>&1 || die "Plymouth client is unavailable."

previous_theme="$(plymouth-set-default-theme 2>/dev/null || true)"
timestamp="$(date -u +'%Y%m%dT%H%M%SZ')"
BACKUP_DIR="/var/lib/k41/boot-experience/theme-backups/$timestamp"
install -d -m 0700 "$BACKUP_DIR"

printf '%s\n' "${previous_theme:-unknown}" >"$BACKUP_DIR/previous-theme"
cp -a "$UKI_PATH" "$BACKUP_DIR/$(basename -- "$UKI_PATH").before"
if [[ -f /boot/initramfs-linux.img ]]; then
    cp -a /boot/initramfs-linux.img "$BACKUP_DIR/initramfs-linux.img.before"
fi
if [[ -e /etc/plymouth/plymouthd.conf ]]; then
    cp -a /etc/plymouth/plymouthd.conf "$BACKUP_DIR/plymouthd.conf.before"
    : >"$BACKUP_DIR/plymouthd.conf.present"
fi
if [[ -d $THEME_DIR ]]; then
    cp -a "$THEME_DIR" "$BACKUP_DIR/k41-theme.before"
    : >"$BACKUP_DIR/k41-theme.present"
fi

info "Installing K41 Plymouth theme files."
install -d -m 0755 "$THEME_DIR"
install -m 0644 "$SOURCE_DIR/k41.plymouth" "$THEME_DIR/k41.plymouth"
install -m 0644 "$SOURCE_DIR/k41.script" "$THEME_DIR/k41.script"

info "Selecting K41 and rebuilding the initramfs/UKI through plymouth-set-default-theme."
if ! plymouth-set-default-theme -R k41; then
    die "Plymouth theme selection or initramfs/UKI rebuild failed. Backup retained at $BACKUP_DIR. Do not reboot until the boot image is repaired or restored."
fi

selected_theme="$(plymouth-set-default-theme 2>/dev/null || true)"
[[ $selected_theme == "k41" ]] || die "Plymouth did not report k41 as the selected theme. Backup retained at $BACKUP_DIR."
[[ -s $UKI_PATH ]] || die "The configured UKI is missing after rebuild. Backup retained at $BACKUP_DIR."

info "K41 Plymouth theme installed and selected."
info "UKI destination verified: $UKI_PATH"
info "Backup retained at: $BACKUP_DIR"
printf 'INFO: Existing HOOKS, kernel command line, bootloader entries, LUKS/TPM metadata, systemd units, getty/autologin, and desktop configuration were not modified.\n'
printf 'WARN: A physical reboot is still required to verify the rendered splash and encrypted-root prompt.\n' >&2
