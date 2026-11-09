#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
bash -n "$ROOT/scripts/k41-install-animated-boot-splash.sh"
bash -n "$ROOT/scripts/k41-lock-caelestia-after-start.sh"
grep -Fq 'WlrLayershell.layer: WlrLayer.Top' "$ROOT/config/quickshell/k41-boot-splash/shell.qml"
grep -Fq 'Timer {' "$ROOT/config/quickshell/k41-boot-splash/shell.qml"
grep -Fq 'K41 ANIMATED BOOT SPLASH START' "$ROOT/scripts/k41-install-animated-boot-splash.sh"
grep -Fq 'dismiss_splash' "$ROOT/scripts/k41-lock-caelestia-after-start.sh"
! grep -Eq 'luksErase|wipe-slot|mkinitcpio|systemd-cryptenroll' "$ROOT/scripts/k41-install-animated-boot-splash.sh"
printf 'PASS: animated handoff splash static invariants\n'
