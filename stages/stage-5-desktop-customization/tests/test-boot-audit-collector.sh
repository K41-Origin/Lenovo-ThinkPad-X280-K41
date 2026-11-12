#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(git -C "$(dirname -- "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
SCRIPT="$ROOT/stages/stage-5-desktop-customization/workstreams/01-boot-experience/scripts/k41-audit-boot-experience.sh"

[[ -s $SCRIPT ]]
bash -n "$SCRIPT"
grep -Fq 'Mode: READ-ONLY' "$SCRIPT"
grep -Fq 'BOOTCTL STATUS' "$SCRIPT"
grep -Fq 'LUKS METADATA SUMMARY' "$SCRIPT"
grep -Fq 'KERNEL COMMAND LINE' "$SCRIPT"
grep -Fq 'FILESYSTEM TABLE' "$SCRIPT"
grep -Fq 'CRYPTTAB (KEYFILE PATHS REDACTED)' "$SCRIPT"
grep -Fq 'MKINITCPIO HOOKS CONFIGURATION' "$SCRIPT"
grep -Fq 'BOOTLOADER / KERNEL INSTALL FILES' "$SCRIPT"
grep -Fq 'INITRAMFS CONTENTS' "$SCRIPT"
grep -Fq 'PLYMOUTH THEME / PACKAGE' "$SCRIPT"
grep -Fq 'TPM DEVICE PRESENCE' "$SCRIPT"
grep -Fq 'CURRENT AND PREVIOUS BOOT JOURNAL' "$SCRIPT"
grep -Fq 'PLYMOUTH CONFIGURATION AND K41 SOURCE/DEPLOYED ASSETS' "$SCRIPT"
grep -Fq 'UKI BUILD ARTIFACT AND EMBEDDED CONTENT EVIDENCE' "$SCRIPT"
grep -Fq 'RUNNING KERNEL COMMAND LINE' "$SCRIPT"
grep -Fq 'Theme source/deployed checksum comparison' "$SCRIPT"
grep -Fq 'UKI embedded initramfs: Plymouth/theme/crypto entries' "$SCRIPT"
grep -Fq 'collect_plymouth_journal' "$SCRIPT"
grep -Fq 'chmod 0700 "$OUT"' "$SCRIPT"
grep -Fq 'chmod 0600 "$REPORT"' "$SCRIPT"
grep -Fq 'SUDO_UID' "$SCRIPT"
grep -Fq 'chown -R "$AUDIT_UID:$AUDIT_GID" "$OUT_ROOT"' "$SCRIPT"
grep -Fq 'chown "$AUDIT_UID:$AUDIT_GID" "$REPORT"' "$SCRIPT"
grep -Fq 'chown "$AUDIT_UID:$AUDIT_GID" "$OUT/README.txt"' "$SCRIPT"
grep -Fq 'chmod u+rwx "$dir"' "$SCRIPT"

# Reject executable mutation commands; read-only status/list/discovery are allowed.
! grep -Eq '^[[:space:]]*(systemctl[[:space:]]+(enable|disable|start|stop|restart)|mkinitcpio[[:space:]]+-P|bootctl[[:space:]]+(install|update)|efibootmgr[[:space:]]+-[acCo]|systemd-cryptenroll[[:space:]].*--tpm2-device=auto|cryptsetup[[:space:]]+(luksAddKey|luksRemoveKey|luksErase|luksFormat))' "$SCRIPT"

printf 'PASS: Workstream 01 audit collector static safety contract\n'

# Execute the collector on the disposable GitHub Actions host. This validates
# report creation and permissions; it is not a substitute for an X280 audit.
output="$(bash "$SCRIPT")"
report="$(printf '%s\n' "$output" | sed -n 's/^Audit report: //p')"
[[ -n $report && -s $report ]]
report_dir="$(dirname -- "$report")"
[[ -s "$report_dir/README.txt" ]]
[[ "$(stat -c '%a' "$report")" == 600 ]]
[[ "$(stat -c '%a' "$report_dir")" == 700 ]]
grep -Fq 'Mode: READ-ONLY' "$report"
grep -Fq '===== FIRMWARE MODE =====' "$report"
grep -Fq '===== LUKS METADATA SUMMARY (NO KEY MATERIAL) =====' "$report"
grep -Fq '===== PLYMOUTH THEME / PACKAGE =====' "$report"
grep -Fq '===== CURRENT AND PREVIOUS BOOT JOURNAL (FILTERED) =====' "$report"
grep -Fq '===== PLYMOUTH CONFIGURATION AND K41 SOURCE/DEPLOYED ASSETS =====' "$report"
grep -Fq '===== UKI BUILD ARTIFACT AND EMBEDDED CONTENT EVIDENCE =====' "$report"
grep -Fq '===== RUNNING KERNEL COMMAND LINE (SENSITIVE FIELDS REDACTED) =====' "$report"

printf 'PASS: Workstream 01 audit collector runtime smoke test; report created with restrictive permissions\n'
