#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
SCRIPT="$ROOT/scripts/k41-diagnose-boot-visuals.sh"

[[ -s "$SCRIPT" ]]
bash -n "$SCRIPT"
grep -Fq 'read-only' "$SCRIPT"
grep -Fq 'journalctl -b -1' "$SCRIPT"
grep -Fq 'hyprctl getoption misc:disable_splash_rendering' "$SCRIPT"
grep -Fq 'hyprctl getoption misc:disable_hyprland_logo' "$SCRIPT"
! grep -Eq 'systemctl (enable|disable|start|stop|restart)|systemd-cryptenroll|cryptsetup luks|mkinitcpio -P|pacman -S' "$SCRIPT"

printf 'PASS: boot visual diagnostic collector syntax and read-only invariants\n'
