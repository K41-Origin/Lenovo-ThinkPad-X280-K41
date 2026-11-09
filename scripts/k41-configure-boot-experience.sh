#!/usr/bin/env bash
# Configure a Plymouth boot splash and TPM2 auto-unlock for the encrypted root.
# TPM enrollment is additive: the existing LUKS passphrase slot is retained.
set -Eeuo pipefail
umask 077

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
info() { printf 'INFO: %s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }

(( EUID == 0 )) || die "Run with sudo: sudo bash scripts/k41-configure-boot-experience.sh"
[[ -d /sys/firmware/efi ]] || die "UEFI boot is required."
[[ -r /etc/mkinitcpio.conf && -r /etc/kernel/cmdline ]] || die "Expected mkinitcpio and UKI command-line configuration is missing."
mountpoint -q /efi || die "/efi is not mounted; refusing to rebuild a UKI onto an unmounted path."
command -v cryptsetup >/dev/null 2>&1 || die "cryptsetup is required."
command -v systemd-cryptenroll >/dev/null 2>&1 || die "systemd-cryptenroll is required."
command -v python3 >/dev/null 2>&1 || die "python3 is required."
command -v mkinitcpio >/dev/null 2>&1 || die "mkinitcpio is required."

root_source="$(findmnt -no SOURCE /)"
[[ $root_source == /dev/mapper/cryptroot ]] || die "Root is not mounted from /dev/mapper/cryptroot (found: $root_source)."
crypt_device="$(cryptsetup status cryptroot | awk -F: '/^[[:space:]]*device:/ {gsub(/^[[:space:]]+/, "", $2); print $2; exit}')"
[[ -n $crypt_device && -b $crypt_device ]] || die "Could not resolve the active cryptroot backing device."
cryptsetup isLuks "$crypt_device" || die "The cryptroot backing device is not a LUKS volume."
luks_version="$(cryptsetup luksDump "$crypt_device" | awk '/^Version:/ {print $2; exit}')"
[[ $luks_version == 2 ]] || die "TPM2 enrollment requires LUKS2 (found: ${luks_version:-unknown})."

grep -Eq '(^|[[:space:]])rd\.luks\.name=[^[:space:]]+=cryptroot([[:space:]]|$)' /etc/kernel/cmdline ||
  die "/etc/kernel/cmdline does not map rd.luks.name to cryptroot."
grep -Eq '(^|[[:space:]])root=/dev/mapper/cryptroot([[:space:]]|$)' /etc/kernel/cmdline ||
  die "/etc/kernel/cmdline does not use /dev/mapper/cryptroot."
grep -Eq '^[[:space:]]*HOOKS=.*systemd.*sd-encrypt' /etc/mkinitcpio.conf ||
  die "Expected systemd + sd-encrypt mkinitcpio hooks were not found."
grep -Eq 'default_uki=.*arch-linux\.efi' /etc/mkinitcpio.d/linux.preset ||
  die "Expected /efi/EFI/Linux/arch-linux.efi UKI preset was not found."

tpm_list="$(systemd-cryptenroll --tpm2-device=list 2>&1)" || die "TPM2 discovery failed: $tpm_list"
grep -q '/dev/tpmrm0' <<<"$tpm_list" || die "TPM2 resource-manager device /dev/tpmrm0 was not discovered."

printf '\nK41 boot-experience setup\n'
printf 'Root LUKS device: %s\n' "$crypt_device"
printf 'TPM2 device: /dev/tpmrm0\n'
printf 'Secure Boot: disabled (reported by the latest device audit)\n'
printf '\nIMPORTANT: TPM2 auto-unlock removes the boot-time passphrase prompt only while the enrolled TPM and PCR 7 state match. The existing LUKS passphrase remains as recovery. Secure Boot is currently disabled, so PCR 7 does not establish a Secure-Boot-verified boot chain. Firmware/boot policy changes may require recovery with the passphrase and TPM re-enrollment.\n'
printf 'This script will add the Plymouth hook and quiet splash arguments, rebuild the UKI, then enroll a TPM2 key in LUKS.\n'
printf 'Continue? [y/N] '
IFS= read -r answer </dev/tty
[[ $answer =~ ^[Yy]([Ee][Ss])?$ ]] || die "Cancelled; no changes were made."

timestamp="$(date -u +'%Y%m%dT%H%M%SZ')"
backup_dir="/var/lib/k41/boot-experience/backups/$timestamp"
install -d -m 0700 "$backup_dir"
cp -a /etc/mkinitcpio.conf "$backup_dir/mkinitcpio.conf"
cp -a /etc/kernel/cmdline "$backup_dir/kernel-cmdline"
if [[ -e /etc/plymouth/plymouthd.conf ]]; then
  cp -a /etc/plymouth/plymouthd.conf "$backup_dir/plymouthd.conf"
  : >"$backup_dir/plymouthd.conf.present"
fi
printf '%s\n' "$crypt_device" >"$backup_dir/luks-device"
chmod 0600 "$backup_dir/luks-device"

# A LUKS header backup must be stored on a different physical disk.
printf '\nEnter an absolute path on an external disk for the LUKS header backup.\n'
printf 'Example: /run/media/%s/USB/k41-cryptroot-header.img\n' "${SUDO_USER:-user}"
printf 'Header backup path: '
IFS= read -r header_backup </dev/tty
[[ $header_backup == /* && $header_backup != */ && ! -e $header_backup ]] ||
  die "Header backup path must be an unused absolute file path."
header_parent="$(dirname -- "$header_backup")"
[[ -d $header_parent ]] || die "Header backup directory does not exist: $header_parent"
backup_source="$(findmnt -no SOURCE -T "$header_parent" | head -n1)"
[[ -b $backup_source ]] || die "Header backup destination must be on a mounted block-device filesystem."
root_parent="$(lsblk -no PKNAME "$crypt_device" | head -n1)"
backup_parent="$(lsblk -no PKNAME "$backup_source" | head -n1)"
[[ -n $root_parent && -n $backup_parent && $root_parent != "$backup_parent" ]] ||
  die "Header backup destination is not demonstrably on a different physical disk."
cryptsetup luksHeaderBackup "$crypt_device" --header-backup-file "$header_backup"
chmod 0600 "$header_backup"
info "LUKS header backup created on a different physical disk: $header_backup"

# Install Plymouth from the signed official Arch repository; do not bypass pacman verification.
pacman -S --needed plymouth
command -v plymouth-set-default-theme >/dev/null 2>&1 || die "Plymouth installation did not provide plymouth-set-default-theme."
[[ -d /usr/share/plymouth/themes/bgrt ]] || die "The packaged BGRT theme is unavailable."
plymouth-set-default-theme bgrt

python3 - /etc/mkinitcpio.conf /etc/kernel/cmdline <<'PY'
import pathlib
import re
import sys

hooks_path, cmdline_path = map(pathlib.Path, sys.argv[1:])
text = hooks_path.read_text(encoding="utf-8")
matches = list(re.finditer(r"(?m)^([ \t]*HOOKS=)\(([^)]*)\)([ \t]*(?:#.*)?)$", text))
if len(matches) != 1:
    raise SystemExit("Expected exactly one simple active HOOKS=(...) assignment.")
match = matches[0]
hooks = match.group(2).split()
if "systemd" not in hooks or "sd-encrypt" not in hooks:
    raise SystemExit("systemd and sd-encrypt hooks are required.")
if hooks.count("plymouth") > 1:
    raise SystemExit("Duplicate plymouth hook detected.")
if "plymouth" not in hooks:
    hooks.insert(hooks.index("systemd") + 1, "plymouth")
if hooks.index("systemd") > hooks.index("plymouth") or hooks.index("plymouth") > hooks.index("sd-encrypt"):
    raise SystemExit("Invalid hook order: require systemd < plymouth < sd-encrypt.")
replacement = match.group(1) + "(" + " ".join(hooks) + ")" + match.group(3)
text = text[:match.start()] + replacement + text[match.end():]
hooks_path.write_text(text, encoding="utf-8")

cmdline = cmdline_path.read_text(encoding="utf-8").strip().split()
for item in ("quiet", "splash"):
    if item not in cmdline:
        cmdline.append(item)
cmdline_path.write_text(" ".join(cmdline) + "\n", encoding="utf-8")
PY

info "Rebuilding all configured mkinitcpio presets and the UKI."
if ! mkinitcpio -P; then
  warn "UKI rebuild failed. Original config backups are retained at $backup_dir."
  warn "Do not reboot until the configuration is repaired or restored."
  exit 1
fi
[[ -s /efi/EFI/Linux/arch-linux.efi ]] || die "The expected UKI is missing after mkinitcpio."

printf '\nTPM2 enrollment adds a new LUKS unlock method. It does NOT remove or replace the existing passphrase keyslot.\n'
printf 'Enter the current LUKS passphrase when systemd-cryptenroll asks for it.\n'
printf 'Enroll TPM2 with PCR 7 and no additional PIN? [y/N] '
IFS= read -r answer </dev/tty
[[ $answer =~ ^[Yy]([Ee][Ss])?$ ]] || {
  warn "Plymouth was configured, but TPM2 enrollment was skipped."
  info "Config backup: $backup_dir"
  exit 0
}

systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 "$crypt_device"

if ! cryptsetup luksDump --dump-json-metadata "$crypt_device" |
  python3 -c 'import json,sys; d=json.load(sys.stdin); sys.exit(0 if any(t.get("type") == "systemd-tpm2" for t in d.get("tokens", {}).values()) else 1)'; then
  die "TPM2 token was not found in LUKS metadata after enrollment. Keep the passphrase; do not reboot until investigated."
fi

info "Plymouth BGRT is configured and the UKI was rebuilt."
info "TPM2 token is present in LUKS2 metadata; the original passphrase remains available."
info "Config backup: $backup_dir"
info "LUKS header backup: $header_backup"
warn "Physical reboot testing is still required. Keep the external header backup and the LUKS passphrase."
warn "If TPM2 unlock fails, enter the existing passphrase through the Plymouth prompt; press Esc to reveal boot messages."
