#!/usr/bin/env bash
# Wait for the Caelestia IPC lock target, then lock the fresh desktop session.
set -Eeuo pipefail

die() { printf 'K41 Caelestia lock: %s\n' "$*" >&2; exit 1; }
command -v caelestia >/dev/null 2>&1 || die 'caelestia CLI is unavailable.'
command -v sleep >/dev/null 2>&1 || die 'sleep is unavailable.'
command -v grep >/dev/null 2>&1 || die 'grep is unavailable.'

attempts=${K41_LOCK_RETRIES:-45}
interval=${K41_LOCK_INTERVAL:-1}
[[ $attempts =~ ^[1-9][0-9]*$ ]] || die 'K41_LOCK_RETRIES must be a positive integer.'
[[ $interval =~ ^[0-9]+([.][0-9]+)?$ ]] || die 'K41_LOCK_INTERVAL must be numeric.'

for ((i = 1; i <= attempts; i++)); do
    if caelestia shell -s 2>/dev/null | grep -Eq 'target[[:space:]]+lock([[:space:]]|$)'; then
        if caelestia shell lock lock; then
            printf 'K41 Caelestia lock: session locked successfully.\n'
            exit 0
        fi
    fi
    sleep "$interval"
done

printf "K41 Caelestia lock: WARNING: IPC did not become ready after %s attempts; starting hyprlock fallback.\\n" "$attempts" >&2
if command -v hyprlock >/dev/null 2>&1; then
    exec hyprlock
fi
die "Caelestia lock IPC did not become ready and hyprlock fallback is unavailable."
