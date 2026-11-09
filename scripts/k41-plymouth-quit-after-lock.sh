#!/usr/bin/env bash
# Keep Plymouth visible until the user session reports a verified lock state.
set -Eeuo pipefail

marker=${1:?Usage: k41-plymouth-quit-after-lock MARKER_PATH}
[[ $marker == /* && $marker != */ ]] || exit 2
[[ ! -L $marker ]] || exit 2

timeout_seconds=${K41_PLYMOUTH_LOCK_TIMEOUT:-75}
[[ $timeout_seconds =~ ^[1-9][0-9]*$ ]] || exit 2

for ((second = 0; second < timeout_seconds; second++)); do
    if [[ -f $marker && ! -L $marker ]]; then
        /usr/bin/plymouth quit --retain-splash
        exit $?
    fi
    sleep 1
done

/usr/bin/logger -t k41-boot "Lock screen did not become ready within ${timeout_seconds}s; stopping tty1 autologin and releasing Plymouth."
# Fail closed: do not leave the tty1 autologin shell exposed if lock startup failed.
/usr/bin/systemctl stop getty@tty1.service || true
/usr/bin/plymouth quit || true
exit 0
