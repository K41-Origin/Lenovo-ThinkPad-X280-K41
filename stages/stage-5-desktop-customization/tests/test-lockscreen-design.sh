#!/usr/bin/env bash
set -Eeuo pipefail

root="$(git -C "$(dirname -- "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
content="$root/stages/stage-5-desktop-customization/workstreams/02-lock-screen/k41-dots/modules/lock/Content.qml"
center="$root/stages/stage-5-desktop-customization/workstreams/02-lock-screen/k41-dots/modules/lock/Center.qml"
locksurface="$root/stages/stage-5-desktop-customization/workstreams/02-lock-screen/k41-dots/modules/lock/LockSurface.qml"
password="$root/stages/stage-5-desktop-customization/workstreams/02-lock-screen/k41-dots/modules/lock/center/PasswordInput.qml"
installer="$root/stages/stage-5-desktop-customization/workstreams/02-lock-screen/scripts/k41-apply-lockscreen-design.sh"
audit="$root/stages/stage-5-desktop-customization/scripts/k41-audit-caelestia.sh"
reporter="$root/stages/stage-5-desktop-customization/workstreams/02-lock-screen/scripts/k41-report-lockscreen-session.sh"
permission_audit="$root/stages/stage-5-desktop-customization/workstreams/02-lock-screen/scripts/k41-report-lockscreen-permissions.sh"
failure_reporter="$root/stages/stage-5-desktop-customization/workstreams/02-lock-screen/scripts/k41-report-lockscreen-failure.sh"

for file in "$content" "$center" "$locksurface" "$password" "$installer" "$audit" "$reporter" "$permission_audit" "$failure_reporter"; do
    [[ -s $file ]] || { printf 'FAIL: missing/empty %s\n' "$file" >&2; exit 1; }
done

bash -n "$installer"
bash -n "$audit"
bash -n "$reporter"
bash -n "$permission_audit"
bash -n "$failure_reporter"
grep -Fq 'Latest deployment logs (full last 500 lines each, newest 3)' "$failure_reporter"
grep -Fq 'Latest session restart logs (full last 300 lines each, newest 2)' "$failure_reporter"
grep -Fq 'Collector is read-only' "$failure_reporter"
! grep -Eq '(^|[[:space:]])(chmod|chown|rm -rf|sudo[[:space:]])' "$failure_reporter"
grep -Fq 'Jalankan sebagai user desktop biasa, tanpa sudo' "$permission_audit"
grep -Fq 'namei -l' "$permission_audit"
grep -Fq 'getfacl -cp' "$permission_audit"
grep -Fq 'stat -c' "$permission_audit"
! grep -Eq '(^|[[:space:]])(chmod|chown|install -o|umask)([[:space:]]|$)' "$permission_audit"
! grep -Fq 'git add' "$permission_audit"

grep -Fq 'WlSessionLockSurface {' "$locksurface"
grep -Fq 'StyledRect {' "$password"
grep -Fq 'Center {' "$content"
grep -Fq 'Clock {' "$center"
grep -Fq 'PasswordInput {' "$center"
grep -Fq 'StateMessage {' "$center"
! grep -Eq 'WeatherInfo|Fetch \{|Media \{|Resources \{|NotifDock|ProfilePic' "$content" "$center"

# The deployment must provide the complete upstream shell root locally.
grep -Fq 'k41-dots/modules/lock' "$installer"
grep -Fq 'K41-Dots lock-screen source and runtime comparison' "$audit"
grep -Fq 'for relative in LockSurface.qml Content.qml Center.qml center/PasswordInput.qml' "$audit"
grep -Fq 'cmp -s "$source_path" "$runtime_path"' "$audit"
grep -Fq 'UPSTREAM_REPO="https://github.com/caelestia-dots/shell.git"' "$installer"
grep -Fq 'UPSTREAM_REVISION="d999d4878ee4cec134168e60d913714566a8cfa6"' "$installer"
grep -Fq 'git -C "$staging" fetch --quiet --depth 1 origin "$UPSTREAM_REVISION"' "$installer"
grep -Fq 'shell.qml modules/lock/Lock.qml modules/lock/LockSurface.qml' "$installer"
grep -Fq 'cp -- "$source_root/Content.qml" "$staging/modules/lock/Content.qml"' "$installer"
grep -Fq 'cp -- "$source_root/Center.qml" "$staging/modules/lock/Center.qml"' "$installer"
grep -Fq 'EXPECTED_PACKAGE_VERSION="2.5.0-1"' "$installer"
grep -Fq 'Complete pinned Caelestia source tree installed under the user config directory' "$installer"
grep -Fq 'Repairing verified legacy directory ownership (non-recursive)' "$installer"
grep -Fq 'mapfile -t legacy_entries' "$installer"
grep -Fq -- "-printf '%P
'" "$installer"
grep -Fq 'chown "$target_uid:$target_gid" -- "$target_parent" "$target_config" "$target_config/modules"' "$installer"
! grep -Fq 'chown -R' "$installer"
grep -Fq 'refusing destructive rollback' "$installer"
grep -Fq 'sudo bash stages/stage-5-desktop-customization/workstreams/02-lock-screen/scripts/k41-apply-lockscreen-design.sh --rollback' "$installer"
! grep -Fq 'cp -- "$source_root/Content.qml" "/etc/xdg' "$installer"

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
grep -Fq 'Selected config path check' "$reporter"
grep -Fq 'FAIL_SYSTEM_FALLBACK' "$reporter"
printf 'PASS: lock-screen layout, installer/reporter/audit Bash syntax, pinned-source deployment and read-only permission audit guards.\n'
printf 'NOTE: installer execution, QML loading, lock/unlock and visual behavior require the target X280.\n'
