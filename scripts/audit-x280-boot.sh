#!/usr/bin/env bash
# Read-only boot, UKI, LUKS, TPM2 and Plymouth audit for the installed X280.
set -Eeuo pipefail
umask 077

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"

if (( EUID != 0 )); then
  printf 'ERROR: jalankan dengan sudo: sudo bash scripts/audit-x280-boot.sh\n' >&2
  exit 1
fi

timestamp="$(date -u +'%Y%m%dT%H%M%SZ')"
report_root="$ROOT/reports/boot-audit"
mkdir -p -- "$report_root"
report_dir="$report_root/$timestamp"
suffix=0
while ! mkdir -- "$report_dir" 2>/dev/null; do
  suffix=$((suffix + 1))
  report_dir="$report_root/$timestamp-$suffix"
done
chmod 0700 "$report_dir"
report="$report_dir/boot-audit.txt"
: >"$report"
chmod 0600 "$report"

redact() {
  sed -E \
    -e 's/(pass(word|phrase)?|token|secret|private[_ -]?key)([=:][[:space:]]*|[[:space:]]+)[^[:space:]]+/\1\3[REDACTED]/Ig' \
    -e 's/(serial([[:space:]_-]*number)?[=:[:space:]]*)[^[:space:]]+/\1[REDACTED]/Ig' \
    -e 's/([[:space:]]|^)([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}([[:space:]]|$)/\1[MAC-REDACTED]\3/g' \
    -e 's#(/home/)[^/[:space:]]+#\1[USER-REDACTED]#g' \
    -e 's/[[:xdigit:]]{8}-([[:xdigit:]]{4}-){3}[[:xdigit:]]{12}/[UUID-REDACTED]/Ig' \
    -e 's/(rd\.luks\.name=)[^[:space:]]+/\1[REDACTED]/g' \
    -e 's/(PARTUUID=)[^[:space:]]+/\1[REDACTED]/g'
}

section() { printf '\n\n===== %s =====\n' "$1" >>"$report"; }
capture() {
  local title="$1"; shift
  section "$title"
  if command -v "$1" >/dev/null 2>&1; then
    "$@" 2>&1 | redact >>"$report" || {
      local rc=$?
      printf '[command exit: %s]\n' "$rc" >>"$report"
    }
  else
    printf 'SKIP: command tidak tersedia: %s\n' "$1" >>"$report"
  fi
}
capture_file() {
  local title="$1" path="$2"
  section "$title"
  if [[ -r $path ]]; then redact <"$path" >>"$report"; else printf 'UNAVAILABLE: %s\n' "$path" >>"$report"; fi
}

{
  printf 'K41 ThinkPad X280 — Boot State Audit\n'
  printf 'Captured UTC: %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  printf 'Repository commit: %s\n' "$(git rev-parse HEAD 2>/dev/null || printf unknown)"
  printf 'Kernel: %s\n' "$(uname -sr)"
  printf 'This collector is read-only. No boot, encryption, TPM, package, service, or firmware settings are changed.\n'
  printf 'Review this report before pushing it. Redaction is best-effort.\n'
} >>"$report"

capture 'BOOTCTL / UEFI / SECURE BOOT' bootctl status --no-pager
capture 'EFI BOOT ENTRIES' bootctl list --no-pager
capture_file 'KERNEL COMMAND LINE CONFIGURATION (/etc/kernel/cmdline)' /etc/kernel/cmdline
capture_file 'RUNNING KERNEL COMMAND LINE (/proc/cmdline)' /proc/cmdline
capture 'MKINITCPIO CONFIGURATION — HOOKS' grep -nE '^[[:space:]]*HOOKS=' /etc/mkinitcpio.conf
capture 'MKINITCPIO PRESETS' find /etc/mkinitcpio.d -maxdepth 1 -type f -name '*.preset' -print
capture 'UKI FILES ON EFI PARTITION' find /efi/EFI/Linux /boot/EFI/Linux -maxdepth 1 -type f -name '*.efi' -printf '%p (%s bytes)\n'
capture 'EFI AND BOOT MOUNTS' bash -c 'findmnt -T /efi; findmnt -T /boot'
section 'CRYPTTAB (KEYFILE FIELD REDACTED)'
if [[ -r /etc/crypttab ]]; then
  awk 'NF && $1 !~ /^#/ { $3="[KEYFILE-REDACTED]"; print; next } { print }' /etc/crypttab | redact >>"$report"
else
  printf 'UNAVAILABLE: /etc/crypttab (file may not exist)\\n' >>"$report"
fi
capture 'ROOT MOUNT SOURCE' findmnt -no SOURCE,FSTYPE,OPTIONS /
capture 'CRYPTROOT MAPPER STATUS' cryptsetup status cryptroot
capture 'BLOCK DEVICE TOPOLOGY (UUIDS AND SERIALS OMITTED)' lsblk -e7 -o NAME,PATH,TYPE,SIZE,FSTYPE,MOUNTPOINTS,MODEL,TRAN
capture 'LUKS DEVICE IDENTIFICATION' bash -c '
  source="$(cryptsetup status cryptroot 2>/dev/null | awk -F: "/^[[:space:]]*device:/ {gsub(/^[[:space:]]+/, \"\", \$2); print \$2; exit}")"
  if [[ -n "$source" && -b "$source" ]]; then
    printf "Underlying encrypted block device: %s\n" "$source"
    cryptsetup luksDump --dump-json-metadata "$source" 2>&1
  else
    printf "Could not resolve an active cryptroot backing block device.\n"
    exit 2
  fi
'
capture 'TPM DEVICE NODES' bash -c 'for d in /dev/tpm*; do [[ -e "$d" ]] && ls -l "$d"; done; [[ -e /dev/tpm0 || -e /dev/tpmrm0 ]]'
capture 'TPM2 DEVICE DISCOVERY' systemd-cryptenroll --tpm2-device=list
capture 'CRYPTENROLL VERSION' systemd-cryptenroll --version
capture 'INSTALLED PACKAGE VERSIONS' pacman -Q systemd mkinitcpio linux plymouth tpm2-tss cryptsetup
capture 'PLYMOUTH UNIT DEFINITIONS' systemctl cat plymouth-start.service plymouth-quit.service plymouth-quit-wait.service
capture 'PLYMOUTH UNIT STATES' systemctl is-enabled plymouth-start.service plymouth-quit.service plymouth-quit-wait.service
capture 'PLYMOUTH PACKAGE FILES' pacman -Ql plymouth
capture 'RELEVANT SYSTEMD UNIT DEPENDENCIES' systemctl list-dependencies --all multi-user.target
capture 'FAILED SYSTEMD UNITS' systemctl --failed --no-pager
capture 'RECENT BOOT ERRORS' journalctl -b -p err --no-pager -o short-iso

section 'CRYPTTAB PRIVACY NOTE'
printf 'The crypttab keyfile field (third whitespace-delimited field) is redacted by this collector. Inspect manually for any unusual secret-bearing options before sharing.\n' >>"$report"

if [[ -n ${SUDO_UID:-} && ${SUDO_UID} =~ ^[0-9]+$ ]] && (( SUDO_UID >= 1000 )); then
  chown "$SUDO_UID:${SUDO_GID:-$SUDO_UID}" "$report_dir" "$report" 2>/dev/null || true
fi
chmod 0700 "$report_dir"
chmod 0600 "$report"
printf 'Boot audit selesai: %s\n' "$report_dir"
printf 'File yang perlu direview sebelum push: %s\n' "$report"
