#!/usr/bin/env bash
# Wait for Caelestia's lock IPC, request a lock, verify it, then dismiss K41 overlay.
set -Eeuo pipefail

die() { printf 'K41 Caelestia lock: %s\n' "$*" >&2; exit 1; }
mark_ready() {
    local marker="$HOME/.cache/k41/boot-lock-ready"
    install -d -m 0700 "$(dirname -- "$marker")"
    : >"$marker"
    chmod 0600 "$marker"
}
dismiss_splash() {
    local pid_file="$HOME/.cache/k41/boot-splash.pid" pid
    if [[ -f $pid_file && ! -L $pid_file ]]; then
        IFS= read -r pid <"$pid_file" || true
        if [[ $pid =~ ^[1-9][0-9]*$ ]] && kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
        fi
        rm -f -- "$pid_file"
    fi
}
command -v caelestia >/dev/null 2>&1 || die 'caelestia CLI is unavailable.'
command -v sleep >/dev/null 2>&1 || die 'sleep is unavailable.'
command -v grep >/dev/null 2>&1 || die 'grep is unavailable.'

attempts=${K41_LOCK_RETRIES:-45}
interval=${K41_LOCK_INTERVAL:-1}
verify_attempts=${K41_LOCK_VERIFY_RETRIES:-10}
[[ $attempts =~ ^[1-9][0-9]*$ ]] || die 'K41_LOCK_RETRIES must be a positive integer.'
[[ $interval =~ ^[0-9]+([.][0-9]+)?$ ]] || die 'K41_LOCK_INTERVAL must be numeric.'
[[ $verify_attempts =~ ^[1-9][0-9]*$ ]] || die 'K41_LOCK_VERIFY_RETRIES must be a positive integer.'

lock_ipc_ready() {
    caelestia shell -s 2>/dev/null |
        grep -Eq 'target[[:space:]]+lock([[:space:]]|$)' &&
    caelestia shell -s 2>/dev/null |
        grep -Eq 'function[[:space:]]+isLocked\(\):[[:space:]]*bool'
}
is_locked() {
    local state
    state=$(caelestia shell lock isLocked 2>/dev/null) || return 1
    [[ $state =~ ^[[:space:]]*true[[:space:]]*$ ]]
}
for ((i = 1; i <= attempts; i++)); do
    if lock_ipc_ready && caelestia shell lock lock; then
        for ((v = 1; v <= verify_attempts; v++)); do
            if is_locked; then
                printf 'K41 Caelestia lock: lock state verified.\n'
                dismiss_splash
                mark_ready
                exit 0
            fi
            sleep "$interval"
        done
    fi
    sleep "$interval"
done

printf 'K41 Caelestia lock: ERROR: lock IPC did not reach a verified locked state; starting Hyprlock fallback.\n' >&2
if command -v hyprlock >/dev/null 2>&1; then
    hyprlock &
    lock_pid=$!
    sleep 1
    if kill -0 "$lock_pid" 2>/dev/null; then
        dismiss_splash
        mark_ready
        wait "$lock_pid"
        exit $?
    fi
    wait "$lock_pid" || true
fi
die 'Caelestia lock could not be verified and Hyprlock fallback is unavailable.'
