#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(git -C "$(dirname -- "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
WS="$ROOT/stages/stage-5-desktop-customization/workstreams/01-boot-experience"
CONFIGURE="$WS/scripts/k41-configure-boot-experience.sh"
INSTALLER="$WS/scripts/k41-install-plymouth-theme.sh"
LOCK_HELPER="$WS/scripts/k41-lock-caelestia-after-start.sh"

bash -n "$CONFIGURE"
bash -n "$INSTALLER"
bash -n "$LOCK_HELPER"

# Workstream 01 boot visuals must be Plymouth-only.
! grep -Eiq 'quickshell|\.qml|qs[[:space:]]+-c|animated-boot-splash' "$CONFIGURE" "$INSTALLER"
grep -Fq 'plymouth-set-default-theme -R k41' "$INSTALLER"
grep -Fq 'Plymouth.SetRefreshFunction(refresh_callback)' "$WS/themes/plymouth/k41/k41.script"
grep -Fq 'ModuleName=script' "$WS/themes/plymouth/k41/k41.plymouth"

# The theme installer must not manage the separate desktop lock/session lifecycle.
! grep -Eiq 'caelestia|hyprland|hyprlock|boot-lock-ready|k41-plymouth-release.service|getty@tty1|autologin' "$INSTALLER"

printf 'PASS: Plymouth-only boot renderer contract\n'
