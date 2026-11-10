#!/usr/bin/env bash
# Install the K41 Plymouth theme and rebuild configured initramfs/UKI presets.
# Does not alter LUKS metadata, TPM enrollment, kernel command line, or bootloader entries.
set -Eeuo pipefail
umask 077

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
info() { printf 'INFO: %s\n' "$*"; }
(( EUID == 0 )) || die "Run with sudo: sudo bash scripts/k41-install-plymouth-theme.sh"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../../../.." && pwd -P)"
SOURCE_DIR="$SCRIPT_DIR/../themes/plymouth/k41"
THEME_DIR="/usr/share/plymouth/themes/k41"
[[ -s "$SOURCE_DIR/k41.plymouth" && -s "$SOURCE_DIR/k41.script" ]] || die "K41 theme source files are missing."
command -v plymouth-set-default-theme >/dev/null 2>&1 || die "Plymouth is not installed."
command -v mkinitcpio >/dev/null 2>&1 || die "mkinitcpio is unavailable."
# Arch's Plymouth package supplies the matching systemd transition units and
# wires them into reboot/poweroff targets. The selected K41 theme is reused by
# these units in shutdown/reboot mode; do not create competing custom units.
for unit_path in \
    /usr/lib/systemd/system/plymouth-reboot.service \
    /usr/lib/systemd/system/plymouth-poweroff.service \
    /usr/lib/systemd/system/plymouth-halt.service \
    /usr/lib/systemd/system/reboot.target.wants/plymouth-reboot.service \
    /usr/lib/systemd/system/poweroff.target.wants/plymouth-poweroff.service \
    /usr/lib/systemd/system/halt.target.wants/plymouth-halt.service; do
    [[ -e $unit_path ]] || die "Plymouth reboot/shutdown integration is incomplete: missing $unit_path"
done
[[ -r /etc/mkinitcpio.conf ]] || die "/etc/mkinitcpio.conf is missing."
[[ -r /etc/kernel/cmdline ]] || die "/etc/kernel/cmdline is missing."
mountpoint -q /efi || die "/efi is not mounted; refusing to rebuild UKI to an unmounted path."
grep -Eq '^[[:space:]]*HOOKS=.*systemd.*plymouth.*sd-encrypt' /etc/mkinitcpio.conf ||
    die "Expected hook order systemd -> plymouth -> sd-encrypt is not configured."
grep -Eq '(^|[[:space:]])quiet([[:space:]]|$)' /etc/kernel/cmdline ||
    die "quiet is missing from /etc/kernel/cmdline."
grep -Eq '(^|[[:space:]])splash([[:space:]]|$)' /etc/kernel/cmdline ||
    die "splash is missing from /etc/kernel/cmdline."
[[ -s /etc/mkinitcpio.d/linux.preset ]] || die "Expected linux mkinitcpio preset is missing."

current_theme="$(plymouth-set-default-theme 2>/dev/null || true)"
timestamp="$(date -u +'%Y%m%dT%H%M%SZ')"
backup_dir="/var/lib/k41/boot-experience/theme-backups/$timestamp"
install -d -m 0700 "$backup_dir"
printf '%s\n' "${current_theme:-unknown}" >"$backup_dir/previous-theme"
if [[ -e /etc/plymouth/plymouthd.conf ]]; then
    cp -a /etc/plymouth/plymouthd.conf "$backup_dir/plymouthd.conf"
fi
if [[ -d $THEME_DIR ]]; then
    cp -a "$THEME_DIR" "$backup_dir/k41-theme.previous"
fi

install -d -m 0755 "$THEME_DIR"
install -m 0644 "$SOURCE_DIR/k41.plymouth" "$THEME_DIR/k41.plymouth"
install -m 0644 "$SOURCE_DIR/k41.script" "$THEME_DIR/k41.script"
plymouth-set-default-theme k41

info "Rebuilding initramfs and UKI presets with the K41 Plymouth theme."
if ! mkinitcpio -P; then
    printf 'ERROR: mkinitcpio failed. Backup: %s\n' "$backup_dir" >&2
    printf 'Restore the previous theme with: sudo plymouth-set-default-theme %q\n' "${current_theme:-bgrt}" >&2
    exit 1
fi
[[ -s /efi/EFI/Linux/arch-linux.efi ]] || die "Expected UKI /efi/EFI/Linux/arch-linux.efi is missing after rebuild."

info "K41 Plymouth theme installed and configured."
info "Previous theme and config backup: $backup_dir"
info "No LUKS/TPM metadata or enrollment was changed."
warn_msg="Physical reboot test is still required; verify early splash, LUKS fallback prompt, and lock-screen handoff."
printf 'WARN: %s\n' "$warn_msg" >&2
