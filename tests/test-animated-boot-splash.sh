#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
bash -n "$ROOT/scripts/k41-install-animated-boot-splash.sh"
bash -n "$ROOT/scripts/k41-lock-caelestia-after-start.sh"
python3 - "$ROOT/scripts/k41-install-animated-boot-splash.sh" <<'PY'
import pathlib, sys
source = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
start = 'python3 - "$lua" <<\'PY\'\n'
if start not in source:
    raise SystemExit("Could not locate embedded Python installer block.")
embedded = source.split(start, 1)[1].split("\nPY", 1)[0]
compile(embedded, "k41-install-animated-boot-splash.py", "exec")
PY
grep -Fq 'WlrLayershell.layer: WlrLayer.Overlay' "$ROOT/config/quickshell/k41-boot-splash/shell.qml"
grep -Fq 'model: root.dotCount' "$ROOT/config/quickshell/k41-boot-splash/shell.qml"
grep -Fq 'interval: 90' "$ROOT/config/quickshell/k41-boot-splash/shell.qml"
grep -Fq 'Timer {' "$ROOT/config/quickshell/k41-boot-splash/shell.qml"
grep -Fq 'K41 ANIMATED BOOT SPLASH START' "$ROOT/scripts/k41-install-animated-boot-splash.sh"
grep -Fq 'disable_hyprland_logo = true' "$ROOT/scripts/k41-install-animated-boot-splash.sh"
grep -Fq 'disable_splash_rendering = true' "$ROOT/scripts/k41-install-animated-boot-splash.sh"
grep -Fq 'force_default_wallpaper = 0' "$ROOT/scripts/k41-install-animated-boot-splash.sh"
grep -Fq 'background_color = 0x000000' "$ROOT/scripts/k41-install-animated-boot-splash.sh"
grep -Fq 'json.dumps(command)' "$ROOT/scripts/k41-install-animated-boot-splash.sh"
grep -Fq 'dismiss_splash' "$ROOT/scripts/k41-lock-caelestia-after-start.sh"
! grep -Eq 'luksErase|wipe-slot|mkinitcpio|systemd-cryptenroll' "$ROOT/scripts/k41-install-animated-boot-splash.sh"
printf 'PASS: animated handoff splash static invariants\n'
