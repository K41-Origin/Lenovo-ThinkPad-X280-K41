#!/usr/bin/env bash
# Read-only inventory for Workstream 01. No configuration, boot, TPM, or LUKS writes.
set -Eeuo pipefail
umask 077

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
if REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)"; then
  :
else
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd -P)"
fi
STAMP="$(date -u +'%Y%m%dT%H%M%SZ')"
OUT_ROOT="$REPO_ROOT/reports/stage-5-desktop-customization/01-boot-experience/audits"
OUT="$OUT_ROOT/$STAMP"
mkdir -p -- "$OUT"
chmod 0700 "$OUT"
REPORT="$OUT/report.txt"
: >"$REPORT"
chmod 0600 "$REPORT"

section() { printf '\n\n===== %s =====\n' "$*" >>"$REPORT"; }
note() { printf '%s\n' "$*" >>"$REPORT"; }
run() {
  local title=$1; shift
  section "$title"
  if command -v "$1" >/dev/null 2>&1; then
    "$@" >>"$REPORT" 2>&1 || {
      local rc=$?
      printf '[command exit: %s]\n' "$rc" >>"$REPORT"
    }
  else
    printf '[unavailable: %s]\n' "$1" >>"$REPORT"
  fi
}
read_file() {
  local title=$1 file=$2
  section "$title"
  if [[ -r $file && -f $file ]]; then
    sed -E \
      -e 's/(rd\.luks\.key|cryptkey|password|passphrase|token|credential)(=[^[:space:]]*)?/\1=<REDACTED>/Ig' \
      -e 's/(UUID=)[[:xdigit:]-]+/\1<UUID-REDACTED>/Ig' \
      "$file" >>"$REPORT"
  else
    printf '[not readable or absent: %s]\n' "$file" >>"$REPORT"
  fi
}
redact_journal() {
  grep -Ei 'plymouth|systemd-boot|systemd-crypt|cryptsetup|mkinitcpio|initramfs|dracut|luks|tpm|secure boot|efi|kernel command|k41|hyprland|quickshell|caelestia|agetty' |
    tail -n 500 |
    sed -E \
      -e "s#${HOME//\//\\/}#<HOME>#g" \
      -e "s#${USER}#<USER>#g" \
      -e 's/[0-9]{1,3}(\.[0-9]{1,3}){3}/<IP-REDACTED>/g' \
      -e 's/(rd\.luks\.key|cryptkey|password|passphrase|token|credential)(=[^[:space:]]*)?/\1=<REDACTED>/Ig'
}

{
  printf 'K41 Workstream 01 — Boot Experience Audit\n'
  printf 'Generated UTC: %s\n' "$STAMP"
  printf 'Mode: READ-ONLY; no system changes\n'
  printf 'Repository: %s\n' "$REPO_ROOT"
  printf 'Host: %s\n' "$(hostname 2>/dev/null || printf unknown)"
  printf 'Kernel: %s\n' "$(uname -sr 2>/dev/null || printf unknown)"
  printf 'Architecture: %s\n' "$(uname -m 2>/dev/null || printf unknown)"
  printf 'User context: %s\n' "$(if (( EUID == 0 )); then printf root; else printf non-root; fi)"
  printf 'Collection output: %s\n' "$OUT"
} >>"$REPORT"

section "SAFETY / COLLECTION SCOPE"
note "This collector does not invoke pacman, mkinitcpio, bootctl install/update, efibootmgr writes, systemctl enable/disable/start/stop, cryptsetup mutation, systemd-cryptenroll enrollment, mount, or reboot."
note "LUKS passphrases, key material, recovery keys, and full token metadata are not intentionally collected."
note "Review the report before sharing; firmware identifiers, disk labels, UUIDs, journal text, and local paths may still be sensitive."

run "FIRMWARE MODE" bash -c '[[ -d /sys/firmware/efi ]] && echo UEFI || echo Legacy/unknown; [[ -r /sys/firmware/efi/fw_platform_size ]] && cat /sys/firmware/efi/fw_platform_size; [[ -r /sys/firmware/efi/efivars/SecureBoot-* ]] && echo SecureBoot-variable-present || true'
run "BOOTCTL STATUS" bootctl status --no-pager
run "BOOTCTL ENTRIES" bootctl list --no-pager
run "EFI BOOT ENTRIES (READ ONLY)" efibootmgr -v
run "BLOCK DEVICES / FILESYSTEMS" lsblk -e7 -o NAME,PATH,TYPE,SIZE,FSTYPE,FSVER,LABEL,UUID,PARTUUID,MOUNTPOINTS
run "MOUNT TABLE (BOOT-RELATED)" findmnt -rn -o TARGET,SOURCE,FSTYPE,OPTIONS / /boot /efi /boot/efi
run "ROOT SOURCE" findmnt -no SOURCE,FSTYPE,OPTIONS /
run "CRYPT DEVICE STATUS (NO KEYS)" bash -c 'if command -v cryptsetup >/dev/null 2>&1; then cryptsetup status cryptroot 2>&1; else echo cryptsetup-unavailable; fi'
run "LUKS METADATA SUMMARY (NO KEY MATERIAL)" bash -c '
  command -v cryptsetup >/dev/null 2>&1 || { echo cryptsetup-unavailable; exit 0; }
  while IFS= read -r dev; do
    [[ -b $dev ]] || continue
    if cryptsetup isLuks "$dev" 2>/dev/null; then
      printf "DEVICE=%s\n" "$dev"
      cryptsetup luksDump "$dev" 2>/dev/null | awk "/^Version:|^Cipher name:|^Cipher mode:|^PBKDF:/ {print}" || true
      cryptsetup luksDump --dump-json-metadata "$dev" 2>/dev/null | python3 -c "
import json,sys
try:
 d=json.load(sys.stdin)
 print('TOKEN_TYPES=' + ','.join(sorted({v.get('type','unknown') for v in d.get('tokens',{}).values()})))
 print('KEYSLOT_COUNT=' + str(len(d.get('keyslots',{}))))
except Exception: print('METADATA_PARSE=unavailable')
" || true
    fi
  done < <(lsblk -rpno PATH,TYPE | awk '$2=="part" {print $1}')
'
read_file "KERNEL COMMAND LINE (SENSITIVE FIELDS REDACTED)" /etc/kernel/cmdline
read_file "MKINITCPIO HOOKS CONFIGURATION" /etc/mkinitcpio.conf
section "MKINITCPIO PRESETS"
if compgen -G '/etc/mkinitcpio.d/*.preset' >/dev/null; then
  for file in /etc/mkinitcpio.d/*.preset; do
    printf '\n--- %s ---\n' "$file" >>"$REPORT"
    grep -nE '^(ALL_|PRESETS=|default_|fallback_|uki_|initrd_|image=|options=)' "$file" >>"$REPORT" || true
  done
else
  note "[no mkinitcpio preset files found]"
fi
run "INITRAMFS TOOL VERSION" mkinitcpio --version
run "INITRAMFS CONTENTS — PLYMOUTH / CRYPT / TPM MATCHES" bash -c '
  command -v lsinitcpio >/dev/null 2>&1 || { echo lsinitcpio-unavailable; exit 0; }
  for image in /boot/initramfs-*.img /efi/EFI/Linux/*.efi /boot/EFI/Linux/*.efi; do
    [[ -s $image ]] || continue
    printf "\n--- %s ---\n" "$image"
    lsinitcpio -a "$image" 2>&1 | grep -Ei "plymouth|crypt|encrypt|tpm|systemd" | head -n 160 || true
  done
'
run "KERNEL / PACKAGE VERSIONS" bash -c '
  uname -a
  for pkg in linux linux-lts mkinitcpio systemd plymouth cryptsetup tpm2-tools; do
    pacman -Q "$pkg" 2>/dev/null || true
  done
'
run "PLYMOUTH THEME / PACKAGE" bash -c '
  plymouth --version 2>&1 || true
  command -v plymouth-set-default-theme >/dev/null 2>&1 && plymouth-set-default-theme 2>&1 || true
  pacman -Q plymouth 2>/dev/null || true
  find /usr/share/plymouth/themes -maxdepth 3 -type f \( -name "*.plymouth" -o -name "*.script" \) -print 2>/dev/null | sort
'
run "PLYMOUTH / CRYPT / TPM SYSTEMD UNITS" systemctl list-unit-files "plymouth*" "systemd-cryptsetup*" "getty@tty1.service" "k41-*" --no-pager
section "RELEVANT UNIT STATE"
for unit in plymouth-start.service plymouth-quit.service plymouth-quit-wait.service systemd-cryptsetup@cryptroot.service systemd-boot-update.service getty@tty1.service k41-plymouth-release.service; do
  printf '\n--- %s ---\n' "$unit" >>"$REPORT"
  systemctl status "$unit" --no-pager 2>&1 | head -n 80 >>"$REPORT" || true
done
run "TPM DEVICE PRESENCE" bash -c 'ls -l /dev/tpm* 2>&1 || true; command -v systemd-cryptenroll >/dev/null 2>&1 && systemd-cryptenroll --tpm2-device=list 2>&1 || true'
run "SECURE BOOT STATE" bootctl status --no-pager
run "BOOT-RELATED PROCESSES" pgrep -a -f 'plymouth|systemd-cryptsetup|cryptsetup|Hyprland|start-hyprland|quickshell|qs|caelestia|agetty' 
run "TTY1 GETTY OVERRIDES" bash -c 'find /etc/systemd/system/getty@tty1.service.d -maxdepth 1 -type f -name "*.conf" -print -exec sed -n "1,180p" {} \; 2>/dev/null || true'
run "K41 BOOT-RELATED FILE INVENTORY" bash -c '
  for root in /etc/plymouth /etc/mkinitcpio.conf /etc/kernel/cmdline /etc/mkinitcpio.d /etc/systemd/system/plymouth-quit.service.d /etc/systemd/system/k41-plymouth-release.service /usr/local/libexec/k41-plymouth-quit-after-lock "$HOME/.config/hypr" "$HOME/.config/quickshell"; do
    [[ -e $root ]] || continue
    if [[ -d $root ]]; then find "$root" -maxdepth 4 -type f -print 2>/dev/null
    else printf "%s\n" "$root"; fi
  done
'
section "REPOSITORY WORKSTREAM 01 INVENTORY"
if [[ -d "$REPO_ROOT/stages/stage-5-desktop-customization/workstreams/01-boot-experience" ]]; then
  find "$REPO_ROOT/stages/stage-5-desktop-customization/workstreams/01-boot-experience" -type f -printf '%P\n' | sort >>"$REPORT"
else
  note "[workstream source directory not found in current checkout]"
fi
section "CURRENT AND PREVIOUS BOOT JOURNAL (FILTERED)"
if command -v journalctl >/dev/null 2>&1; then
  journalctl -b --no-pager -o short-monotonic 2>&1 | redact_journal >>"$REPORT" || true
  journalctl -b -1 --no-pager -o short-monotonic 2>&1 | redact_journal >>"$REPORT" || true
else
  note "[journalctl unavailable]"
fi

cat >"$OUT/README.txt" <<EOF
K41 Workstream 01 boot audit
============================
Report: report.txt
Mode: read-only.

The collector does not change boot configuration, initramfs/UKI, systemd
units, Plymouth theme, LUKS metadata, TPM enrollment, firmware settings,
or user configuration.

Review report.txt before sharing or pushing. It may still contain device
names, UUIDs, labels, firmware details, local paths, and journal information.
Never add passphrases, recovery keys, LUKS key material, or credentials.

Generated locally under reports/stage-5-desktop-customization/01-boot-experience/audits/.
EOF
chmod 0600 "$OUT/README.txt"
printf 'Audit report: %s\n' "$REPORT"
printf 'Read-only collection complete. Review/redact the report before sharing.\n'
