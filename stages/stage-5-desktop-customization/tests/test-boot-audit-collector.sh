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
grep -Fq 'MKINITCPIO HOOKS CONFIGURATION' "$SCRIPT"
grep -Fq 'INITRAMFS CONTENTS' "$SCRIPT"
grep -Fq 'PLYMOUTH THEME / PACKAGE' "$SCRIPT"
grep -Fq 'TPM DEVICE PRESENCE' "$SCRIPT"
grep -Fq 'CURRENT AND PREVIOUS BOOT JOURNAL' "$SCRIPT"
grep -Fq 'chmod 0700 "$OUT"' "$SCRIPT"
grep -Fq 'chmod 0600 "$REPORT"' "$SCRIPT"

# Reject executable mutation commands; read-only status/list/discovery are allowed.
! grep -Eq '^[[:space:]]*(systemctl[[:space:]]+(enable|disable|start|stop|restart)|mkinitcpio[[:space:]]+-P|bootctl[[:space:]]+(install|update)|efibootmgr[[:space:]]+-[acCo]|systemd-cryptenroll[[:space:]].*--tpm2-device=auto|cryptsetup[[:space:]]+(luksAddKey|luksRemoveKey|luksErase|luksFormat))' "$SCRIPT"

printf 'PASS: Workstream 01 audit collector static safety contract\n'
