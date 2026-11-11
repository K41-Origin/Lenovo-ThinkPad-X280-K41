#!/usr/bin/env bash
set -Eeuo pipefail

root="$(git -C "$(dirname -- "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
script="$root/stages/stage-5-desktop-customization/workstreams/02-lock-screen/scripts/k41-audit-desktop-startup.sh"

[[ -s $script ]] || { printf 'FAIL: desktop startup audit script missing.\n' >&2; exit 1; }
bash -n "$script"

for token in \
    'Current TTY' \
    'getty@tty1.service' \
    'getty@tty2.service' \
    'k41-plymouth-release.service' \
    'hyprland-startup.log' \
    'journalctl -b -1' \
    'journalctl --user -b' \
    'start-hyprland' \
    'HYPRLAND_INSTANCE_SIGNATURE' \
    'read-only' \\
    'publish_report()' \\
    'git push origin HEAD:main' \\
    'git worktree add --detach' \\
    'chmod 0644'; do
    grep -Fq -- "$token" "$script" || {
        printf 'FAIL: audit collector missing diagnostic coverage: %s\n' "$token" >&2
        exit 1
    }
done

# The collector must not attempt to repair or mutate the host.
if grep -Eiq 'systemctl[[:space:]]+(enable|disable|start|stop|restart|daemon-reload)|pacman[[:space:]]+(-S|--sync)|(^|[;&|[:space:]])(mkinitcpio|cryptsetup|systemd-cryptenroll|efibootmgr|bootctl)[[:space:]]' "$script"; then
    printf 'FAIL: audit collector contains a host mutation command.\n' >&2
    exit 1
fi
! grep -Eiq '(^|[;&|[:space:]])(chown|sudo)[[:space:]]' "$script" || {
    printf 'FAIL: audit collector must not change permissions/ownership or elevate.\n' >&2
    exit 1
}
grep -Fq 'umask 077' "$script"
grep -Fq 'chmod 0600 "$report"' "$script"
grep -Fq 'chmod 0700 "$run_dir"' "$script"
grep -Fq 'password|passwd|token|secret|authorization|cookie|api[_-]?key' "$script"
! grep -Eq 'git[[:space:]].*push.*--force' "$script"

printf 'PASS: desktop startup audit syntax, tty/session coverage, privacy guard, and read-only contract.\n'
