#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(git -C "$(dirname -- "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
WS="$ROOT/stages/stage-5-desktop-customization/workstreams/01-boot-experience"
CONFIGURE="$WS/scripts/k41-configure-boot-experience.sh"
LOCK_HELPER="$WS/scripts/k41-lock-caelestia-after-start.sh"

bash -n "$CONFIGURE"
bash -n "$LOCK_HELPER"

# Workstream 01 boot visuals must be Plymouth-only. Legacy QML/Quickshell
# artifacts must not be installed, started, or required by the boot path.
! grep -Eiq 'quickshell|(^|[^[:alnum:]_])qs([[:space:]]|$)|\.qml|k41-install-animated-boot-splash' "$CONFIGURE"
! grep -Eiq 'quickshell|boot-splash|boot-splash\.pid|\.qml|qs[[:space:]]+-c' "$LOCK_HELPER"
grep -Fq 'plymouth-set-default-theme k41' "$CONFIGURE"
grep -Fq 'plymouth' "$WS/themes/plymouth/k41/k41.plymouth"
grep -Fq 'Plymouth.SetRefreshFunction(refresh_callback)' "$WS/themes/plymouth/k41/k41.script"

[[ ! -e "$WS/scripts/k41-install-animated-boot-splash.sh" ]]
[[ ! -e "$WS/config/quickshell/k41-boot-splash/shell.qml" ]]

printf 'PASS: Plymouth-only boot path; no QML/Quickshell boot dependency\n'
