#!/usr/bin/env bash
set -Eeuo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
content="$root/config/quickshell/caelestia/modules/lock/Content.qml"
center="$root/config/quickshell/caelestia/modules/lock/Center.qml"
installer="$root/scripts/k41-apply-lockscreen-design.sh"

for file in "$content" "$center" "$installer"; do
    [[ -s $file ]] || { printf 'FAIL: missing/empty %s\n' "$file" >&2; exit 1; }
done

bash -n "$installer"
grep -Fq 'Center {' "$content"
grep -Fq 'Clock {' "$center"
grep -Fq 'PasswordInput {' "$center"
grep -Fq 'StateMessage {' "$center"
! grep -Eq 'WeatherInfo|Fetch \{|Media \{|Resources \{|NotifDock|ProfilePic' "$content" "$center"
grep -Fq '/etc/xdg/quickshell/caelestia/modules/lock/Content.qml' "$installer"
grep -Fq -- '--rollback' "$installer"
printf 'PASS: lock-screen override structure and installer syntax checks.\n'
printf 'NOTE: qmllint, Quickshell load, lock/unlock, and visual behavior require the target X280.\n'
