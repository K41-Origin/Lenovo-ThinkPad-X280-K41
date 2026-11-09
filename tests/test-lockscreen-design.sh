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
grep -Fq 'SUDO_USER' "$installer"
grep -Fq 'runuser --user' "$installer"
grep -Fq 'K41_SUDO_REEXEC=1' "$installer"
grep -Fq 'Refusing to perform user-file operations as root' "$installer"
grep -Fq 'install -d -o' "$installer"
grep -Fq 'chown "$target_uid:' "$installer"
grep -Fq 'Managed lock directory is not owned' "$installer"
grep -Fq 'A parent directory in the config path is not traversable' "$installer"
grep -Fq 'reports/lockscreen-apply' "$installer"
grep -Fq 'exec > >(tee -a "$log_file") 2>&1' "$installer"
grep -Fq 'EXECUTION SUMMARY' "$installer"
grep -Fq 'Report   :' "$installer"
grep -Fq '/proc/sys/kernel/hostname' "$installer"
! grep -Fq 'tee hostname' "$installer"
grep -Fq 'finish_log "$rc"' "$installer"
grep -Fq 'Shell restart was not attempted from the sanitized installer process' "$installer"
grep -Fq 'caelestia shell -r -d' "$installer"
grep -Fq "printf '  caelestia shell -r -d\\n'" "$installer"
! grep -Fq 'timeout 15s caelestia shell -r -d' "$installer"
printf 'PASS: lock-screen override structure, installer syntax, and in-repository report logging checks.\n'
printf 'NOTE: qmllint, Quickshell load, lock/unlock, and visual behavior require the target X280.\n'
