#!/usr/bin/env bash
set -Eeuo pipefail

root="$(git -C "$(dirname -- "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
module="$root/stages/stage-5-desktop-customization/workstreams/02-lock-screen/k41-dots/modules/lockscreen"
content="$module/Content.qml"
center="$module/Center.qml"
surface="$module/LockSurface.qml"
password="$module/center/PasswordInput.qml"

for file in "$content" "$center" "$surface" "$password"; do
    [[ -s $file ]] || { printf 'FAIL: missing/empty visual module file: %s\n' "$file" >&2; exit 1; }
done

[[ ! -e "$module/Pam.qml" && ! -e "$module/pam" ]] || {
    printf 'FAIL: authentication implementation must not be copied into the visual module.\n' >&2
    exit 1
}

grep -Fq 'Center {' "$content"
grep -Fq 'Clock {' "$center"
grep -Fq 'PasswordInput {' "$center"
grep -Fq 'StateMessage {' "$center"
grep -Fq 'StyledRect {' "$password"
grep -Fq 'color: Colours.tPalette.m3surfaceContainer' "$password"
grep -Fq 'WlSessionLockSurface {' "$surface"
grep -Fq 'Config.lock.useWallpaper ? wallpaperBackground : screencopyBackground' "$surface"
grep -Fq 'blurEnabled: true' "$surface"

# The K41 source is an extraction of the accepted legacy visuals; the legacy
# tree remains present until the separate migration and cleanup stages.
grep -Fq 'K41 precisely centered lockscreen content.' "$root/stages/stage-5-desktop-customization/workstreams/02-lock-screen/k41-dots/modules/lock/Center.qml"
grep -Fq 'K41 floating password input override' "$root/stages/stage-5-desktop-customization/workstreams/02-lock-screen/k41-dots/modules/lock/center/PasswordInput.qml"

printf 'PASS: K41 lockscreen visual module structure and Floating Password Card visual guards.\n'
printf 'NOTE: QML runtime rendering and device acceptance are not tested by this static test.\n'
