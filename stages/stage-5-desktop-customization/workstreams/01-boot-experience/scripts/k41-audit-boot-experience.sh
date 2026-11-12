#!/usr/bin/env bash
# Read-only inventory for Workstream 01. No boot, TPM, LUKS, or configuration writes.
set -Eeuo pipefail
umask 077

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd -P)"
if REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)"; then
  :
else
  REPO_ROOT="$(cd -- "$SCRIPT_DIR/../../../../.." && pwd -P)"
fi

STAMP="$(date -u +'%Y%m%dT%H%M%SZ')"
OUT_ROOT="$REPO_ROOT/reports/stage-5-desktop-customization/01-boot-experience/audits"
OUT="$OUT_ROOT/$STAMP"

# When invoked through sudo, keep generated audit artifacts writable/readable
# by the repository owner rather than leaving root-owned files that block git.
AUDIT_UID="$EUID"
AUDIT_GID="$(id -g)"
if (( EUID == 0 )) && [[ ${SUDO_UID:-} =~ ^[0-9]+$ ]] &&
  [[ ${SUDO_GID:-} =~ ^[0-9]+$ ]] && (( SUDO_UID > 0 )); then
  AUDIT_UID="$SUDO_UID"
  AUDIT_GID="$SUDO_GID"
fi

mkdir -p -- "$OUT"
if (( EUID == 0 )); then
  # Repair ownership of this audit history only; do not recurse over all reports
  # or modify the repository's .git directory.
  for dir in \
    "$REPO_ROOT/reports" \
    "$REPO_ROOT/reports/stage-5-desktop-customization" \
    "$REPO_ROOT/reports/stage-5-desktop-customization/01-boot-experience" \
    "$OUT_ROOT"; do
    chown "$AUDIT_UID:$AUDIT_GID" "$dir"
    chmod u+rwx "$dir"
  done
  chown -R "$AUDIT_UID:$AUDIT_GID" "$OUT_ROOT"
fi

chmod 0700 "$OUT"
REPORT="$OUT/report.txt"
: >"$REPORT"
chmod 0600 "$REPORT"

section() { printf '\n\n===== %s =====\n' "$*" >>"$REPORT"; }
note() { printf '%s\n' "$*" >>"$REPORT"; }

run() {
  local title=$1
  shift
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
  local title=$1
  local file=$2
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

collect_firmware() {
  local field file
  for field in sys_vendor product_name product_version bios_vendor bios_version bios_date; do
    file="/sys/class/dmi/id/$field"
    [[ -r $file ]] || continue
    printf '%s=' "$field"
    tr -d '\000' <"$file"
  done
}

collect_firmware_mode() {
  [[ -d /sys/firmware/efi ]] && echo UEFI || echo Legacy/unknown
  if [[ -r /sys/firmware/efi/fw_platform_size ]]; then
    printf 'Firmware platform bits: '
    cat /sys/firmware/efi/fw_platform_size
  fi
  if [[ -d /sys/firmware/efi/efivars ]] &&
    find /sys/firmware/efi/efivars -maxdepth 1 -name 'SecureBoot-*' -print -quit | grep -q .; then
    echo SecureBoot-variable-present
  else
    echo SecureBoot-variable-unavailable
  fi
}

collect_mounts() {
  findmnt -rn -o TARGET,SOURCE,FSTYPE,OPTIONS |
    awk '$1 == "/" || $1 == "/boot" || $1 == "/efi" || $1 == "/boot/efi"'
}

collect_crypt_status() {
  if command -v cryptsetup >/dev/null 2>&1; then
    cryptsetup status cryptroot 2>&1 || true
  else
    echo cryptsetup-unavailable
  fi
}

collect_luks_metadata() {
  local dev type
  if ! command -v cryptsetup >/dev/null 2>&1; then
    echo cryptsetup-unavailable
    return 0
  fi
  while read -r dev type; do
    [[ $type == part && -b $dev ]] || continue
    if cryptsetup isLuks "$dev" 2>/dev/null; then
      printf 'DEVICE=%s\n' "$dev"
      cryptsetup luksDump "$dev" 2>/dev/null |
        grep -E '^(Version:|Cipher name:|Cipher mode:|PBKDF:|[[:space:]]+[0-9]+: (luks2|systemd-tpm2|systemd-fido2|systemd-pkcs11))' || true
    fi
  done < <(lsblk -rpno PATH,TYPE)
}

collect_crypttab() {
  if [[ -r /etc/crypttab ]]; then
    sed -E \
      -e 's/^([[:space:]]*[^#[:space:]]+[[:space:]]+[^[:space:]]+[[:space:]]+)[^[:space:]]+/\1<KEYFILE-REDACTED>/' \
      -e 's/(rd\.luks\.key|cryptkey|password|passphrase|token|credential)(=[^[:space:]]*)?/\1=<REDACTED>/Ig' \
      /etc/crypttab
  else
    echo '[/etc/crypttab not readable or absent]'
  fi
}

collect_presets() {
  local file found=0
  for file in /etc/mkinitcpio.d/*.preset; do
    [[ -r $file ]] || continue
    found=1
    printf '\n--- %s ---\n' "$file"
    grep -nE '^(ALL_|PRESETS=|default_|fallback_|uki_|initrd_|image=|options=)' "$file" || true
  done
  if (( found == 0 )); then
    echo '[no mkinitcpio preset files found]'
  fi
}

collect_bootloader_entries() {
  local file
  for file in \
    /boot/loader/entries/*.conf \
    /efi/loader/entries/*.conf \
    /boot/grub/grub.cfg \
    /efi/EFI/BOOT/grub.cfg; do
    [[ -r $file ]] || continue
    printf '\n--- %s ---\n' "$file"
    grep -nE '^[[:space:]]*(title|linux|linuxefi|initrd|initrdefi|options|search|cryptdevice|cryptkey)' "$file" |
      sed -E \
        -e 's/(rd\.luks\.key|cryptkey|password|passphrase|token|credential)(=[^[:space:]]*)?/\1=<REDACTED>/Ig' \
        -e 's/(UUID=)[[:xdigit:]-]+/\1<UUID-REDACTED>/Ig' || true
  done
}

collect_initramfs() {
  local image
  if ! command -v lsinitcpio >/dev/null 2>&1; then
    echo lsinitcpio-unavailable
    return 0
  fi
  for image in /boot/initramfs-*.img /efi/EFI/Linux/*.efi /boot/EFI/Linux/*.efi; do
    [[ -s $image ]] || continue
    printf '\n--- %s ---\n' "$image"
    lsinitcpio -a "$image" 2>&1 |
      grep -Ei 'plymouth|crypt|encrypt|tpm|systemd' |
      head -n 160 || true
  done
}

collect_versions() {
  local pkg
  uname -a
  for pkg in linux linux-lts mkinitcpio systemd plymouth cryptsetup tpm2-tools; do
    pacman -Q "$pkg" 2>/dev/null || true
  done
}

collect_plymouth() {
  plymouth --version 2>&1 || true
  if command -v plymouth-set-default-theme >/dev/null 2>&1; then
    plymouth-set-default-theme 2>&1 || true
  else
    echo plymouth-set-default-theme-unavailable
  fi
  pacman -Q plymouth 2>/dev/null || true
  find /usr/share/plymouth/themes -maxdepth 3 -type f \
    \( -name '*.plymouth' -o -name '*.script' \) -print 2>/dev/null | sort
}

collect_unit_state() {
  local unit
  for unit in \
    plymouth-start.service \
    plymouth-quit.service \
    plymouth-quit-wait.service \
    systemd-cryptsetup@cryptroot.service \
    systemd-boot-update.service \
    getty@tty1.service \
    k41-plymouth-release.service; do
    printf '\n--- %s ---\n' "$unit"
    systemctl status "$unit" --no-pager 2>&1 | head -n 80 || true
  done
}

collect_tpm() {
  ls -l /dev/tpm* 2>&1 || true
  if command -v systemd-cryptenroll >/dev/null 2>&1; then
    systemd-cryptenroll --tpm2-device=list 2>&1 || true
  else
    echo systemd-cryptenroll-unavailable
  fi
}

collect_getty_overrides() {
  local dir=/etc/systemd/system/getty@tty1.service.d
  if [[ -d $dir ]]; then
    find "$dir" -maxdepth 1 -type f -name '*.conf' \
      -print -exec sed -n '1,180p' {} \;
  else
    echo '[no tty1 getty override directory]'
  fi
}

collect_k41_files() {
  local root
  for root in \
    /etc/plymouth \
    /etc/mkinitcpio.conf \
    /etc/kernel/cmdline \
    /etc/mkinitcpio.d \
    /etc/systemd/system/plymouth-quit.service.d \
    /etc/systemd/system/k41-plymouth-release.service \
    /usr/local/libexec/k41-plymouth-quit-after-lock \
    "$HOME/.config/hypr" \
    "$HOME/.config/quickshell"; do
    [[ -e $root ]] || continue
    if [[ -d $root ]]; then
      find "$root" -maxdepth 4 -type f -print 2>/dev/null
    else
      printf '%s\n' "$root"
    fi
  done
}

collect_plymouth_assets() {
  local source_dir="$REPO_ROOT/stages/stage-5-desktop-customization/workstreams/01-boot-experience/themes/plymouth/k41"
  local installed_dir="/usr/share/plymouth/themes/k41"
  local file
  echo "--- Plymouth selected theme ---"
  if command -v plymouth-set-default-theme >/dev/null 2>&1; then
    plymouth-set-default-theme 2>&1 || true
    plymouth-set-default-theme -l 2>&1 || true
  else
    echo '[plymouth-set-default-theme unavailable]'
  fi
  echo
  echo "--- Plymouth daemon configuration ---"
  if [[ -r /etc/plymouth/plymouthd.conf ]]; then
    sed -E 's/(password|passphrase|token|credential)(=[^[:space:]]*)?/\1=<REDACTED>/Ig' /etc/plymouth/plymouthd.conf
  else
    echo '[not readable or absent]'
  fi
  for file in "$source_dir/k41.plymouth" "$source_dir/k41.script" "$installed_dir/k41.plymouth" "$installed_dir/k41.script"; do
    echo
    echo "--- $file ---"
    if [[ -f $file ]]; then
      stat -c 'type=%F mode=%a size=%s mtime=%y' "$file" 2>&1 || true
      sha256sum "$file" 2>&1 || true
      if command -v pacman >/dev/null 2>&1; then pacman -Qo "$file" 2>&1 || true; fi
      sed -n '1,260p' "$file"
    else
      echo '[missing]'
    fi
  done
  echo
  echo "--- Theme source/deployed checksum comparison ---"
  for file in k41.plymouth k41.script; do
    if [[ -f $source_dir/$file && -f $installed_dir/$file ]]; then
      if cmp -s "$source_dir/$file" "$installed_dir/$file"; then echo "$file: MATCH"; else echo "$file: DIFFERENT"; fi
    else
      echo "$file: SOURCE_OR_DEPLOYED_FILE_MISSING"
    fi
  done
}

collect_uki_evidence() {
  local preset=/etc/mkinitcpio.d/linux.preset uki_path=''
  echo "--- Relevant preset definitions ---"
  if [[ -r $preset ]]; then
    grep -nE '^(ALL_|PRESETS=|default_|fallback_|uki_|initrd_|image=|options=)' "$preset" || true
    mapfile -t paths < <(sed -nE 's/^[[:space:]]*default_uki="([^"]+)".*/\1/p' "$preset")
    if (( ${#paths[@]} == 1 )); then uki_path=${paths[0]}; fi
  else
    echo '[linux.preset missing or unreadable]'
  fi
  echo
  echo "--- UKI metadata ---"
  if [[ -n $uki_path && -f $uki_path ]]; then
    printf 'Configured default_uki=%s\n' "$uki_path"
    stat -c 'type=%F mode=%a size=%s mtime=%y' "$uki_path" 2>&1 || true
    sha256sum "$uki_path" 2>&1 || true
    if command -v file >/dev/null 2>&1; then file "$uki_path" 2>&1 || true; fi
    if command -v objdump >/dev/null 2>&1; then objdump -h "$uki_path" 2>&1 || true; fi
    if command -v ukify >/dev/null 2>&1; then ukify inspect "$uki_path" 2>&1 || true; fi
    if command -v lsinitcpio >/dev/null 2>&1; then
      echo "--- UKI embedded initramfs: Plymouth/theme/crypto entries ---"
      lsinitcpio -a "$uki_path" 2>&1 | grep -Ei 'plymouth|themes/k41|\.plymouth|\.script|crypt|encrypt|tpm|systemd' | head -n 240 || true
      echo "--- UKI embedded initramfs: theme paths ---"
      lsinitcpio -l "$uki_path" 2>&1 | grep -Ei 'plymouth|themes/k41|\.plymouth|\.script' | head -n 160 || true
    else
      echo '[lsinitcpio unavailable]'
    fi
  else
    printf 'Configured default_uki=%s; file missing, empty, or preset ambiguous\n' "${uki_path:-UNKNOWN}"
  fi
  echo
  echo "--- Boot entry references to UKI ---"
  bootctl list --no-pager 2>&1 | grep -Ei -C 3 'arch-linux|linux\.efi|uki|default' | head -n 160 || true
}

collect_plymouth_journal() {
  local boot
  for boot in 0 -1; do
    echo
    echo "--- journalctl -b $boot Plymouth/initramfs/crypt messages ---"
    journalctl -b "$boot" --no-pager -o short-monotonic 2>&1 |
      grep -Ei 'plymouth|splash|initramfs|mkinitcpio|cryptsetup|systemd-cryptsetup|sd-encrypt|firmware|simpledrm|drm|fbcon' |
      tail -n 350 || true
  done
}

redact_journal() {
  grep -Ei 'plymouth|systemd-boot|systemd-crypt|cryptsetup|mkinitcpio|initramfs|dracut|luks|tpm|secure boot|efi|kernel command|k41|hyprland|quickshell|caelestia|agetty' |
    tail -n 500 |
    sed -E \
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
  if (( EUID == 0 )); then
    printf 'User context: root\n'
  else
    printf 'User context: non-root\n'
  fi
  printf 'Collection output: %s\n' "$OUT"
} >>"$REPORT"

section "SAFETY / COLLECTION SCOPE"
note "This collector does not invoke pacman, mkinitcpio, bootctl install/update, efibootmgr writes, systemctl enable/disable/start/stop, cryptsetup mutation, systemd-cryptenroll enrollment, mount, or reboot."
note "LUKS passphrases, key material, recovery keys, and full token metadata are not intentionally collected."
note "Review the report before sharing; firmware identifiers, disk labels, UUIDs, journal text, and local paths may still be sensitive."

run "SYSTEM / FIRMWARE MODEL (SERIALS EXCLUDED)" collect_firmware
run "FIRMWARE MODE" collect_firmware_mode
run "BOOTCTL STATUS" bootctl status --no-pager
run "BOOTCTL ENTRIES" bootctl list --no-pager
run "EFI BOOT ENTRIES (READ ONLY)" efibootmgr -v
run "BLOCK DEVICES / FILESYSTEMS" lsblk -e7 -o NAME,PATH,TYPE,SIZE,FSTYPE,FSVER,LABEL,UUID,PARTUUID,MOUNTPOINTS
run "MOUNT TABLE (BOOT-RELATED)" collect_mounts
run "ROOT SOURCE" findmnt -no SOURCE,FSTYPE,OPTIONS /
run "CRYPT DEVICE STATUS (NO KEYS)" collect_crypt_status
run "LUKS METADATA SUMMARY (NO KEY MATERIAL)" collect_luks_metadata
read_file "KERNEL COMMAND LINE CONFIGURATION (SENSITIVE FIELDS REDACTED)" /etc/kernel/cmdline
read_file "RUNNING KERNEL COMMAND LINE (SENSITIVE FIELDS REDACTED)" /proc/cmdline
read_file "FILESYSTEM TABLE" /etc/fstab
run "CRYPTTAB (KEYFILE PATHS REDACTED)" collect_crypttab
read_file "MKINITCPIO HOOKS CONFIGURATION" /etc/mkinitcpio.conf
run "MKINITCPIO PRESETS" collect_presets
run "BOOTLOADER ENTRY CONTENTS (SENSITIVE FIELDS REDACTED)" collect_bootloader_entries
run "INITRAMFS TOOL VERSION" mkinitcpio --version
run "INITRAMFS CONTENTS — PLYMOUTH / CRYPT / TPM MATCHES" collect_initramfs
run "KERNEL / PACKAGE VERSIONS" collect_versions
run "PLYMOUTH THEME / PACKAGE" collect_plymouth
run "PLYMOUTH CONFIGURATION AND K41 SOURCE/DEPLOYED ASSETS" collect_plymouth_assets
run "UKI BUILD ARTIFACT AND EMBEDDED CONTENT EVIDENCE" collect_uki_evidence
run "PLYMOUTH / CRYPT / TPM SYSTEMD UNITS" systemctl list-unit-files 'plymouth*' 'systemd-cryptsetup*' 'getty@tty1.service' 'k41-*' --no-pager
run "ACTIVE CRYPTSETUP UNITS" systemctl list-units --all --no-pager 'systemd-cryptsetup*'
run "BOOTLOADER / KERNEL INSTALL FILES" bash -c '
  for root in /boot/loader /efi/loader /boot/EFI /efi/EFI /etc/kernel /etc/cmdline.d; do
    [[ -d $root ]] || continue
    printf "\n--- %s ---\n" "$root"
    find "$root" -maxdepth 4 -type f -print 2>/dev/null | sort
  done
'
run "RELEVANT UNIT STATE" collect_unit_state
run "TPM DEVICE PRESENCE" collect_tpm
run "SECURE BOOT STATE" bootctl status --no-pager
run "BOOT-RELATED PROCESSES" pgrep -a -f 'plymouth|systemd-cryptsetup|cryptsetup|Hyprland|start-hyprland|quickshell|qs|caelestia|agetty'
run "TTY1 GETTY OVERRIDES" collect_getty_overrides
run "K41 BOOT-RELATED FILE INVENTORY" collect_k41_files

section "REPOSITORY WORKSTREAM 01 INVENTORY"
workstream="$REPO_ROOT/stages/stage-5-desktop-customization/workstreams/01-boot-experience"
if [[ -d $workstream ]]; then
  find "$workstream" -type f -printf '%P\n' | sort >>"$REPORT"
else
  note "[workstream source directory not found in current checkout]"
fi

section "CURRENT AND PREVIOUS BOOT JOURNAL (FILTERED)"
if command -v journalctl >/dev/null 2>&1; then
  journalctl -b --no-pager -o short-monotonic 2>&1 | redact_journal >>"$REPORT" || true
  journalctl -b -1 --no-pager -o short-monotonic 2>&1 | redact_journal >>"$REPORT" || true
  collect_plymouth_journal >>"$REPORT" 2>&1 || true
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
