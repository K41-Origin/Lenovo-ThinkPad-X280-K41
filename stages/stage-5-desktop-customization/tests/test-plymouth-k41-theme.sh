#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(git -C "$(dirname -- "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
WS="$ROOT/stages/stage-5-desktop-customization/workstreams/01-boot-experience"
INSTALLER="$WS/scripts/k41-install-plymouth-theme.sh"
THEME="$WS/themes/plymouth/k41"

bash -n "$INSTALLER"
grep -Fq 'ModuleName=script' "$THEME/k41.plymouth"
grep -Fq 'ScriptFile=/usr/share/plymouth/themes/k41/k41.script' "$THEME/k41.plymouth"
grep -Fq 'Window.SetBackgroundTopColor (0.0, 0.0, 0.0)' "$THEME/k41.script"
grep -Fq 'Plymouth.SetRefreshFunction(refresh_callback)' "$THEME/k41.script"
grep -Fq 'Plymouth.SetDisplayPasswordFunction(display_password_callback)' "$THEME/k41.script"
grep -Fq 'Plymouth.SetDisplayNormalFunction(display_normal_callback)' "$THEME/k41.script"
grep -Fq 'plymouth-set-default-theme -R k41' "$INSTALLER"
grep -Fq 'systemd -> plymouth -> sd-encrypt' "$INSTALLER"
grep -Fq 'default_uki' "$INSTALLER"
grep -Fq 'UKI destination verified' "$INSTALLER"

# Preserve the approved K41 visual identity.
grep -Fq 'global.count = 12;' "$THEME/k41.script"
grep -Fq 'global.radius = 9;' "$THEME/k41.script"
grep -Fq 'Image.Text("K41", 0.8, 0.8, 0.8)' "$THEME/k41.script"
grep -Fq 'Image.Text("▯", 0.9, 0.9, 0.9)' "$THEME/k41.script"
grep -Fq 'global.rectangles[i].SetOpacity(opacity)' "$THEME/k41.script"
grep -Fq 'global.center_y + 10' "$THEME/k41.script"

# This installer does not enroll TPM or edit LUKS/bootloader/systemd lifecycle.
! grep -Eiq 'systemd-cryptenroll|cryptsetup|luks(Add|Remove|Erase)|wipe-slot|efibootmgr|bootctl|systemctl' "$INSTALLER"
! grep -Eiq 'k41-plymouth-release.service|plymouth-quit.service.d|getty@tty1|autologin|quickshell|\.qml' "$INSTALLER"

printf 'PASS: K41 Plymouth theme and installer invariants\n'
