#!/usr/bin/env bash
# Configure a Plymouth boot splash and TPM2 auto-unlock for the encrypted root.
# TPM enrollment is additive: the existing LUKS passphrase slot is retained.
set -Eeuo pipefail
umask 077
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

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

[[ -n ${SUDO_USER:-} && $SUDO_USER != root ]] || die "Run this script with sudo from the desktop account."
USER_NAME=$SUDO_USER
[[ $USER_NAME =~ ^[a-z_][a-z0-9_-]*[$]?$ ]] || die "Unsupported desktop account name."
USER_ENTRY="$(getent passwd "$USER_NAME")" || die "Cannot resolve desktop account."
IFS=: read -r _ _ USER_UID USER_GID _ USER_HOME USER_SHELL <<<"$USER_ENTRY"
[[ $USER_UID =~ ^[0-9]+$ && $USER_GID =~ ^[0-9]+$ && -d $USER_HOME ]] || die "Desktop account metadata is invalid."
GETTY_DROPIN="/etc/systemd/system/getty@tty1.service.d/k41-autologin.conf"
BASH_PROFILE="$USER_HOME/.bash_profile"
HELPER_TARGET="$USER_HOME/.local/bin/k41-lock-caelestia-after-start"
[[ -f $GETTY_DROPIN ]] && grep -Fq -- "--autologin $USER_NAME" "$GETTY_DROPIN" ||
  die "The existing K41 tty1 autologin configuration was not found; enable the approved Caelestia autologin first."
[[ -f $BASH_PROFILE ]] && grep -Fq '# K41 HYPRLAND AUTOLOGIN START' "$BASH_PROFILE" &&
  grep -Fq 'start-hyprland' "$BASH_PROFILE" || die "The K41 tty1 Hyprland login block was not found."
[[ -f $HELPER_TARGET ]] || die "The installed Caelestia lock helper was not found."
HYPRLAND_CONFIG="$USER_HOME/.config/hypr/hyprland.lua"
[[ -r $HYPRLAND_CONFIG ]] || die "Expected Hyprland config is missing: $HYPRLAND_CONFIG"
command -v qs >/dev/null 2>&1 || die "Quickshell (qs) is required for the K41 graphical handoff."
[[ -r "$SCRIPT_DIR/k41-install-animated-boot-splash.sh" ]] || die "The K41 Quickshell handoff installer is missing or unreadable."

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
mkdir -p "$backup_dir/files"
backup_file() {
  local source=$1 relative=$2
  if [[ -e $source ]]; then
    printf 'present %s\n' "$relative" >>"$backup_dir/manifest"
    mkdir -p "$backup_dir/files/$(dirname -- "$relative")"
    cp -a "$source" "$backup_dir/files/$relative"
  else
    printf 'absent %s\n' "$relative" >>"$backup_dir/manifest"
  fi
}
backup_file "$GETTY_DROPIN" "etc/systemd/system/getty@tty1.service.d/k41-autologin.conf"
backup_file "$BASH_PROFILE" "home/$USER_NAME/.bash_profile"
backup_file "$HYPRLAND_CONFIG" "home/$USER_NAME/.config/hypr/hyprland.lua"
backup_file "$HELPER_TARGET" "home/$USER_NAME/.local/bin/k41-lock-caelestia-after-start"
backup_file "/etc/systemd/system/plymouth-quit.service.d/k41-lock-handoff.conf" "etc/systemd/system/plymouth-quit.service.d/k41-lock-handoff.conf"
backup_file "/etc/systemd/system/k41-plymouth-release.service" "etc/systemd/system/k41-plymouth-release.service"
backup_file "/usr/local/libexec/k41-plymouth-quit-after-lock" "usr/local/libexec/k41-plymouth-quit-after-lock"
backup_file "/etc/plymouth/plymouthd.conf" "etc/plymouth/plymouthd.conf"
printf '%s\n' "$crypt_device" >"$backup_dir/luks-device"
chmod 0600 "$backup_dir/luks-device"

# No external LUKS-header backup destination is requested.
# The existing passphrase keyslot is preserved; config backups remain local under
# /var/lib/k41/boot-experience/backups for restoring boot configuration only.
warn "LUKS header backup is being skipped by request. Keep the existing passphrase safe; do not remove or overwrite its keyslot."

# Install the graphical K41 handoff first. Its Hyprland config is backed up above.
info "Installing the K41 Quickshell handoff and Hyprland visual suppression."
bash "$SCRIPT_DIR/k41-install-animated-boot-splash.sh"

# Install Plymouth from the signed official Arch repository; do not bypass pacman verification.
pacman -S --needed plymouth
command -v plymouth-set-default-theme >/dev/null 2>&1 || die "Plymouth installation did not provide plymouth-set-default-theme."
THEME_SOURCE="$SCRIPT_DIR/../themes/plymouth/k41"
[[ -s "$THEME_SOURCE/k41.plymouth" && -s "$THEME_SOURCE/k41.script" ]] ||
  die "The K41 Plymouth theme source files are missing."
install -d -m 0755 /usr/share/plymouth/themes/k41
install -m 0644 "$THEME_SOURCE/k41.plymouth" /usr/share/plymouth/themes/k41/k41.plymouth
install -m 0644 "$THEME_SOURCE/k41.script" /usr/share/plymouth/themes/k41/k41.script
plymouth-set-default-theme k41

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

# Install the lock-aware Plymouth handoff. The splash remains until Caelestia
# reports a verified lock state; on timeout, tty1 autologin is stopped fail-closed.
ROOT_HELPER="/usr/local/libexec/k41-plymouth-quit-after-lock"
install -D -m 0755 "$SCRIPT_DIR/k41-plymouth-quit-after-lock.sh" "$ROOT_HELPER"
install -D -m 0755 "$SCRIPT_DIR/k41-lock-caelestia-after-start.sh" "$HELPER_TARGET"
chown "$USER_UID:$USER_GID" "$HELPER_TARGET"

python3 - "$BASH_PROFILE" <<'PY'
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
start = "# K41 HYPRLAND AUTOLOGIN START"
end = "# K41 HYPRLAND AUTOLOGIN END"
if text.count(start) != 1 or text.count(end) != 1:
    raise SystemExit("Expected exactly one managed K41 login block.")
a = text.index(start)
b = text.index(end, a) + len(end)
block = text[a:b]
launch = re.search(r"(?m)^(\s*)start-hyprland\s*$", block)
if not launch:
    raise SystemExit("Managed K41 login block does not contain a plain start-hyprland command.")
marker = '    mkdir -p "$HOME/.cache/k41"\n    rm -f -- "$HOME/.cache/k41/boot-lock-ready"\n'
if "boot-lock-ready" not in block:
    block = block[:launch.start()] + marker + block[launch.start():]
path.write_text(text[:a] + block + text[b:], encoding="utf-8")
PY
chown "$USER_UID:$USER_GID" "$BASH_PROFILE"

cat >"$GETTY_DROPIN" <<EOF
[Unit]
After=
After=systemd-user-sessions.service getty-pre.target k41-plymouth-release.service

[Service]
Type=simple
ExecStart=
ExecStart=-/usr/bin/agetty --noreset --noclear --noissue --nohostname --autologin $USER_NAME - \${TERM}
TTYVTDisallocate=no
EOF
chown root:root "$GETTY_DROPIN"
chmod 0644 "$GETTY_DROPIN"

install -d -m 0755 /etc/systemd/system/plymouth-quit.service.d
cat >/etc/systemd/system/plymouth-quit.service.d/k41-lock-handoff.conf <<EOF
[Unit]
After=getty@tty1.service

[Service]
ExecStart=
ExecStart=$ROOT_HELPER "$USER_HOME/.cache/k41/boot-lock-ready"
TimeoutStartSec=85
EOF
chown root:root /etc/systemd/system/plymouth-quit.service.d/k41-lock-handoff.conf
chmod 0644 /etc/systemd/system/plymouth-quit.service.d/k41-lock-handoff.conf

cat >/etc/systemd/system/k41-plymouth-release.service <<EOF
[Unit]
Description=Retain splash frame and release Plymouth display ownership before K41 Hyprland startup
Wants=plymouth-start.service
After=plymouth-start.service
Before=getty@tty1.service

[Service]
Type=oneshot
ExecStartPre=/usr/bin/rm -f -- "$USER_HOME/.cache/k41/boot-lock-ready"
ExecStart=-/usr/bin/plymouth quit --retain-splash
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
chown root:root /etc/systemd/system/k41-plymouth-release.service
chmod 0644 /etc/systemd/system/k41-plymouth-release.service
systemctl daemon-reload
systemd-analyze verify k41-plymouth-release.service plymouth-quit.service getty@tty1.service
systemctl enable k41-plymouth-release.service

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

info "The animated K41 Plymouth theme is configured and the UKI was rebuilt."
info "TPM2 token is present in LUKS2 metadata; the original passphrase remains available."
info "Config backup: $backup_dir"
info "LUKS header backup: skipped by request; no external header backup was created."
warn "Physical reboot testing is still required. No LUKS header backup was created; keep the existing passphrase safe."
warn "If TPM2 unlock fails, enter the existing passphrase through the Plymouth prompt; press Esc to reveal boot messages."
