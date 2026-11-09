#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
SCRIPT="$ROOT/scripts/k41-configure-boot-experience.sh"

[[ -f $SCRIPT ]]
bash -n "$SCRIPT"
bash -n "$ROOT/scripts/k41-lock-caelestia-after-start.sh"
bash -n "$ROOT/scripts/k41-plymouth-quit-after-lock.sh"
grep -Fq 'systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7' "$SCRIPT"
grep -Fq 'cryptsetup luksHeaderBackup' "$SCRIPT"
grep -Fq 'plymouth-set-default-theme bgrt' "$SCRIPT"
grep -Fq 'quiet' "$SCRIPT"
grep -Fq 'splash' "$SCRIPT"
grep -Fq 'k41-plymouth-deactivate.service' "$SCRIPT"
grep -Fq 'k41-lock-handoff.conf' "$SCRIPT"
grep -Fq 'boot-lock-ready' "$SCRIPT"
grep -Fq 'mark_ready' "$ROOT/scripts/k41-lock-caelestia-after-start.sh"
grep -Fq 'systemctl stop getty@tty1.service' "$ROOT/scripts/k41-plymouth-quit-after-lock.sh"
! grep -Eq 'cryptsetup[[:space:]]+luksErase|--wipe-slot=all|wipefs[[:space:]]' "$SCRIPT"

printf 'PASS: boot-experience script syntax and safety invariants\n'
