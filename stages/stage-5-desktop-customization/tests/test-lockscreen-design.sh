#!/usr/bin/env bash
set -Eeuo pipefail

root="$(git -C "$(dirname -- "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
module="$root/stages/stage-5-desktop-customization/workstreams/02-lock-screen/modules/lockscreen"
content="$module/Content.qml"
center="$module/Center.qml"
locksurface="$module/LockSurface.qml"
password="$module/center/PasswordInput.qml"
deployer="$root/stages/stage-5-desktop-customization/workstreams/02-lock-screen/scripts/k41-deploy-lockscreen-visual.sh"
audit="$root/stages/stage-5-desktop-customization/scripts/k41-audit-caelestia.sh"
reporter="$root/stages/stage-5-desktop-customization/workstreams/02-lock-screen/scripts/k41-report-lockscreen-session.sh"
permission_audit="$root/stages/stage-5-desktop-customization/workstreams/02-lock-screen/scripts/k41-report-lockscreen-permissions.sh"
failure_reporter="$root/stages/stage-5-desktop-customization/workstreams/02-lock-screen/scripts/k41-report-lockscreen-failure.sh"

for file in "$content" "$center" "$locksurface" "$password" "$deployer" "$audit" "$reporter" "$permission_audit" "$failure_reporter"; do
    [[ -s $file ]] || { printf 'FAIL: missing/empty %s\n' "$file" >&2; exit 1; }
done

for script in "$deployer" "$audit" "$reporter" "$permission_audit" "$failure_reporter"; do
    bash -n "$script"
done

# The deployer has one action only: deploy the visual files and reload Caelestia.
! grep -Eq -- '--(install|status|rollback)' "$deployer"
grep -Fq 'host_root="$config_root/quickshell/caelestia"' "$deployer"
grep -Fq 'lock_root="$host_root/modules/lock"' "$deployer"
grep -Fq 'caelestia shell -r -d' "$deployer"
! grep -Fq 'Pam.qml' "$deployer"
! grep -Eq '^[[:space:]]*sudo([[:space:]]|$)' "$deployer"
! grep -Fq 'hyprctl keyword' "$deployer"

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
[[ ! -e "$root/stages/stage-5-desktop-customization/workstreams/02-lock-screen/k41-dots" ]]

printf 'PASS: Floating Password Card visual layout, automatic deploy/reload contract, and read-only diagnostics guards.\n'
printf 'NOTE: real QML rendering and lock/unlock acceptance require the target X280.\n'
