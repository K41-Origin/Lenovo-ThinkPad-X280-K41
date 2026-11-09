#!/usr/bin/env bash
set -Eeuo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
content="$root/config/quickshell/caelestia/modules/lock/Content.qml"
center="$root/config/quickshell/caelestia/modules/lock/Center.qml"
installer="$root/scripts/k41-apply-lockscreen-design.sh"
reporter="$root/scripts/k41-report-lockscreen-session.sh"

for file in "$content" "$center" "$installer" "$reporter"; do
    [[ -s $file ]] || { printf 'FAIL: missing/empty %s\n' "$file" >&2; exit 1; }
done

bash -n "$installer"
bash -n "$reporter"
grep -Fq 'Center {' "$content"
grep -Fq 'Clock {' "$center"
grep -Fq 'PasswordInput {' "$center"
grep -Fq 'StateMessage {' "$center"
! grep -Eq 'WeatherInfo|Fetch \{|Media \{|Resources \{|NotifDock|ProfilePic' "$content" "$center"

# The deployment must provide the complete upstream shell root locally.
grep -Fq 'UPSTREAM_REPO="https://github.com/caelestia-dots/shell.git"' "$installer"
grep -Fq 'UPSTREAM_REVISION="d999d4878ee4cec134168e60d913714566a8cfa6"' "$installer"
grep -Fq 'git -C "$staging" fetch --quiet --depth 1 origin "$UPSTREAM_REVISION"' "$installer"
grep -Fq 'shell.qml modules/lock/Lock.qml modules/lock/LockSurface.qml' "$installer"
grep -Fq 'cp -- "$source_root/Content.qml" "$staging/modules/lock/Content.qml"' "$installer"
grep -Fq 'cp -- "$source_root/Center.qml" "$staging/modules/lock/Center.qml"' "$installer"
grep -Fq 'EXPECTED_PACKAGE_VERSION="2.5.0-1"' "$installer"
grep -Fq 'Complete upstream QML source tree installed under the user config directory' "$installer"
grep -Fq 'Refusing destructive rollback' "$installer"
grep -Fq 'sudo bash scripts/k41-apply-lockscreen-design.sh --rollback' "$installer"
! grep -Fq '/etc/xdg/quickshell/caelestia/modules/lock/Content.qml' "$installer"

# Preserve sudo privilege drop and avoid restarting from a sanitized process.
grep -Fq 'SUDO_USER' "$installer"
grep -Fq 'runuser --user' "$installer"
grep -Fq 'K41_SUDO_REEXEC=1' "$installer"
grep -Fq 'Refusing to replace any other local content' "$installer" || grep -Fq 'Unexpected pre-existing user file' "$installer"
! grep -Fq 'caelestia shell -r -d' "$installer" || grep -Fq 'Restart from the active Hyprland terminal' "$installer"

grep -Fq 'Do not run with sudo' "$reporter"
grep -Fq 'WAYLAND_DISPLAY' "$reporter"
grep -Fq 'caelestia shell -r -d' "$reporter"
grep -Fq 'PIPESTATUS[0]' "$reporter"
printf 'PASS: lock-screen layout structure, installer/reporter Bash syntax, pinned-source deployment and rollback guards.\n'
printf 'NOTE: installer execution, QML loading, lock/unlock and visual behavior require the target X280.\n'
