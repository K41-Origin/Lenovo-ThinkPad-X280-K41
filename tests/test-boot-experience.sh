#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
SCRIPT="$ROOT/scripts/k41-configure-boot-experience.sh"

[[ -f $SCRIPT ]]
bash -n "$SCRIPT"
grep -Fq 'systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7' "$SCRIPT"
grep -Fq 'cryptsetup luksHeaderBackup' "$SCRIPT"
grep -Fq 'plymouth-set-default-theme bgrt' "$SCRIPT"
grep -Fq 'quiet' "$SCRIPT"
grep -Fq 'splash' "$SCRIPT"
grep -Fq 'HOOKS=(...)' "$SCRIPT" && exit 1 || true
! grep -Eq 'cryptsetup[[:space:]]+luksErase|--wipe-slot=all|wipefs[[:space:]]' "$SCRIPT"

printf 'PASS: boot-experience script syntax and safety invariants\n'
