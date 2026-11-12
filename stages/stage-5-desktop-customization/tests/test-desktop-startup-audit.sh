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
    'read-only' \
    'publish_report()' \
    'git -C "$publish_dir" push origin HEAD:main' \
    'git clone --quiet --no-tags --single-branch --branch main "$remote_url" "$publish_dir"' \
    'isolated clone' \
    'local checkout Git metadata was not used for publication' \
    'IMPLEMENTATION SOURCE REVISION AND INSTALLED CONFIG COMPARISON' \
    'Installed Hyprlock fallback config byte comparison' \
    'INSTALLED LOCK HELPER CONTENT AND SOURCE COMPARISON' \
    'Installed helper byte comparison' \
    'INSTALLED K41 LOCK VISUAL SOURCE COMPARISON' \
    'k41-boot-splash' \
    'coredumpctl list --no-pager' \
    'START-HYPRLAND LAUNCHER — NON-EXECUTING INSPECTION' \
    'Launcher execution: NOT PERFORMED' \
    'K41 LAUNCHER SOURCE: REPOSITORY' \
    'K41 LAUNCHER SOURCE: INSTALLED' \
    'HYPRLAND STARTUP LOG AND ROTATED PREVIOUS LOG' \
    '.local/state/caelestia' \
    'chmod 0644' \
    'LOCK LIFECYCLE: LOGIN SESSION STATE' \
    'LOCK LIFECYCLE: HELPER INVOCATIONS AND PHASE TRANSITIONS' \
    'LOCK LIFECYCLE: CURRENT CAELESTIA IPC STATE (READ-ONLY)' \
    'CAELESTIA LOCK isLocked QUERY' \
    'LOCK LIFECYCLE: LOCKER AND COMPOSITOR PROCESS STATE' \
    'HYPRLAND LOCK-RELATED BINDINGS' \
    'LOCK LIFECYCLE: AUTHENTICATION AND UNLOCK JOURNAL EVENTS' \
    'LOCK LIFECYCLE: DEPLOYMENT AND VISUAL SOURCE PROVENANCE' \
    'startup-*.log' \
    'deployment-logs' \
    'LOCK LIFECYCLE: NORMALIZED EVIDENCE TIMELINE' \
    'LOCKSCREEN QML SOURCE: REPOSITORY AND INSTALLED RUNTIME' \
    'LOCKSCREEN DEPLOYMENT STATE AND FILE HASHES' \
    'LOCK_STATE_RETRY' \
    'LOCK_REQUEST_REJECTED' \
    'HELPER_TERMINAL_ERROR' \
    'HYPRLOCK_FALLBACK_RUNNING' \
    'HYPRLOCK_CONFIG_ERROR' \
    'HYPRLOCK_UNLOCK_CONFIRMED' \
    'HYPRLOCK_AUTH_FAILURE' \
    'HYPRLOCK_AUTH_SUCCESS' \
    'NOT_INSTRUMENTED' \
    'lifecycle-timeline.tsv' \
    'NOT_OBSERVED' \
    'AUTH_SUCCESS' \
    'AUTH_FAILURE' \
    'UNLOCK_EVENT' \
    'HYPRLAND_SESSION_START' \
    'HYPRLAND_SESSION_STOP' \
    'LOCK_SURFACE_VISIBLE' \
    'DESKTOP_RESTORED_AFTER_UNLOCK' \
    'subprocess.run(' \
    'LOCK_SURFACE_VISIBLE and DESKTOP_RESTORED_AFTER_UNLOCK are NOT_INSTRUMENTED'; do
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
grep -Fq '<SSID-REDACTED>' "$script"
! grep -Eq 'git[[:space:]].*push.*--force' "$script"

# A read-only audit must never execute start-hyprland: it launches a session,
# and --version is not a safe/version-only invocation for this command.
version_loop="$(sed -n '/^for bin in /,/^done$/p' "$script")"
[[ -n $version_loop ]] || { printf 'FAIL: executable version loop missing.\n' >&2; exit 1; }
if grep -Eq 'for bin in .*start-hyprland|^[[:space:]]*start-hyprland[|)]|timeout[^|]*start-hyprland.*--version' <<<"$version_loop"; then
    printf 'FAIL: audit attempts to execute the start-hyprland session launcher.\n' >&2
    exit 1
fi
grep -Fq 'Launcher execution: NOT PERFORMED' "$script"

for token in \
    'IMPLEMENTATION INPUTS: ACTIVE SESSION AND PROCESS CONTEXT' \
    'IMPLEMENTATION PROBE: CAELESTIA SHELL EXPORTS' \
    'IMPLEMENTATION PROBE: CAELESTIA LOCK STATE' \
    'IMPLEMENTATION PROBE: USER SESSION ENVIRONMENT' \
    'IMPLEMENTATION CONFIG CONTENT: .config/caelestia/shell.json' \
    'IMPLEMENTATION CONFIG CONTENT: .config/quickshell/caelestia/shell.qml' \
    'IMPLEMENTATION CONFIG CONTENT: .config/k41/hyprlock-fallback.conf' \
    'IMPLEMENTATION INPUTS: REPOSITORY LOCKSCREEN TREE'; do
    grep -Fq -- "$token" "$script" || {
        printf 'FAIL: implementation evidence coverage missing: %s\n' "$token" >&2
        exit 1
    }
done


# Automatic publication must use an independent clone, never a linked worktree
# or fetch against the user's active checkout. This keeps local refs, index,
# FETCH_HEAD, branch, and worktree metadata isolated from report publication.
! grep -Fq 'git -C "$repo_root" fetch' "$script" || {
    printf 'FAIL: audit publication fetches into the user's local checkout.\n' >&2
    exit 1
}
! grep -Fq 'git -C "$repo_root" worktree' "$script" || {
    printf 'FAIL: audit publication mutates local checkout worktree metadata.\n' >&2
    exit 1
}
! grep -Fq 'git -C "$repo_root" worktree add' "$script" || {
    printf 'FAIL: audit publication uses a linked worktree.\n' >&2
    exit 1
}
grep -Fq 'git clone --quiet --no-tags --single-branch --branch main "$remote_url" "$publish_dir"' "$script"
grep -Fq 'rm -rf -- "$publish_tmp"' "$script"


# Local diagnostics must never occupy the same path as the published report.
# Otherwise a later git pull would refuse to overwrite the untracked local file.
grep -Fq 'report_root="$HOME/.local/state/k41/lockscreen/startup-audits"' "$script"
grep -Fq 'relative_dir="reports/stage-5-desktop-customization/02-lock-screen/startup-audits/${run_dir##*/}"' "$script"
! grep -Fq 'report_root="$repo_root/reports' "$script" || {
    printf 'FAIL: audit stores local reports inside the Git checkout.\\n' >&2
    exit 1
}

printf 'PASS: desktop startup audit syntax, tty/session coverage, privacy guard, and read-only contract.\n'
