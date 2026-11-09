#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
bash -n "$ROOT/scripts/k41-install-plymouth-theme.sh"
grep -Fq 'ModuleName=script' "$ROOT/themes/plymouth/k41/k41.plymouth"
grep -Fq 'ScriptFile=/usr/share/plymouth/themes/k41/k41.script' "$ROOT/themes/plymouth/k41/k41.plymouth"
grep -Fq 'Window.SetBackgroundTopColor (0.0, 0.0, 0.0)' "$ROOT/themes/plymouth/k41/k41.script"
grep -Fq 'Plymouth.SetRefreshFunction(refresh_callback)' "$ROOT/themes/plymouth/k41/k41.script"
grep -Fq 'Plymouth.SetDisplayPasswordFunction(display_password_callback)' "$ROOT/themes/plymouth/k41/k41.script"
grep -Fq 'Plymouth.SetDisplayNormalFunction(display_normal_callback)' "$ROOT/themes/plymouth/k41/k41.script"
grep -Fq 'mkinitcpio -P' "$ROOT/scripts/k41-install-plymouth-theme.sh"
! grep -Eq 'systemd-cryptenroll|luksAddKey|luksRemoveKey|luksErase|wipe-slot' "$ROOT/scripts/k41-install-plymouth-theme.sh"
printf 'PASS: K41 Plymouth theme static invariants\n'
