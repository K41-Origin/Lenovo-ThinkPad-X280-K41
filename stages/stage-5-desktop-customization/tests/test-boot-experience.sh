#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(git -C "$(dirname -- "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
WS="$ROOT/stages/stage-5-desktop-customization/workstreams/01-boot-experience"
CONFIGURE="$WS/scripts/k41-configure-boot-experience.sh"
INSTALLER="$WS/scripts/k41-install-plymouth-theme.sh"

[[ -f $CONFIGURE && -f $INSTALLER ]]
bash -n "$CONFIGURE"
bash -n "$INSTALLER"
bash -n "$WS/scripts/k41-start-hyprland.sh"
bash -n "$WS/scripts/k41-plymouth-quit-after-lock.sh"

grep -Fq 'exec bash "$INSTALLER" "$@"' "$CONFIGURE"
grep -Fq 'plymouth-set-default-theme -R k41' "$INSTALLER"
grep -Fq 'systemd -> plymouth -> sd-encrypt' "$INSTALLER"
grep -Fq 'default_uki' "$INSTALLER"
grep -Fq 'Backup retained at' "$INSTALLER"
grep -Fq 'mountpoint -q "$EFI_MOUNT"' "$INSTALLER"
grep -Fq 'findmnt -nro FSTYPE' "$INSTALLER"

# The visual installer must not mutate unrelated boot/authentication/security state.
! grep -Eiq '(^|[;&|[:space:]])(pacman|systemctl|systemd-cryptenroll|cryptsetup|efibootmgr|bootctl)([[:space:]]|$)' "$INSTALLER"
! grep -Eiq 'getty@tty1|autologin|k41-plymouth-release.service|k41-lock-handoff.conf|boot-lock-ready|HYPRLAND_CONFIG|caelestia' "$INSTALLER"
! grep -Eiq '(^|[;&|[:space:]])(pacman|systemctl|systemd-cryptenroll|cryptsetup|efibootmgr|bootctl)([[:space:]]|$)' "$CONFIGURE"
! grep -Eiq 'quickshell|\.qml|qs[[:space:]]+-c|animated-boot-splash' "$CONFIGURE" "$INSTALLER"

# Existing host configuration is validated, never rewritten by the installer.
! grep -Eq 'HOOKS=.*(write_text|sed -i|tee)' "$INSTALLER"
! grep -Eq 'kernel/cmdline.*(write_text|sed -i|tee)' "$INSTALLER"

printf 'PASS: Plymouth installer syntax and non-invasive safety contract\n'
