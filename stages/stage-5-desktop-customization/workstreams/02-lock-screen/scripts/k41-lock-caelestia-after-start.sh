#!/usr/bin/env bash
# Start and verify the Caelestia session lock before publishing the Plymouth handoff marker.
# Hyprlock fallback uses a repository-managed config passed explicitly with --config.
set -Eeuo pipefail
umask 077

die() {
    printf 'K41 lock startup: ERROR: %s\n' "$*" >&2
    exit 1
}
log() {
    printf '[%s] %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$*"
}

(( EUID != 0 )) || die 'Run as the regular desktop user, never with sudo.'
[[ -n ${HOME:-} && $HOME == /* && -d $HOME ]] || die 'HOME is missing or invalid.'

for command_name in caelestia date chmod mkdir mktemp mv sleep stat timeout grep kill; do
    command -v "$command_name" >/dev/null 2>&1 || die "Required command is unavailable: $command_name"
done

state_root="$HOME/.local/state"
k41_state="$state_root/k41"
log_root="$k41_state/lockscreen"
for path in "$HOME/.local" "$state_root" "$k41_state" "$log_root"; do
    [[ ! -L $path ]] || die "Refusing symlinked state path: $path"
    [[ ! -e $path || -d $path ]] || die "State path is not a directory: $path"
    if [[ -e $path ]]; then
        [[ $(stat -c %u -- "$path") == "$EUID" ]] || die "State path is not owned by the desktop user: $path"
    fi
done
mkdir -p -- "$log_root"
[[ -d $log_root && ! -L $log_root && $(stat -c %u -- "$log_root") == "$EUID" ]] ||
    die 'Cannot establish a user-owned lock startup log directory.'

stamp="$(date -u +'%Y%m%dT%H%M%SZ')"
log_file="$log_root/startup-$stamp-${BASHPID}.log"
[[ ! -e $log_file && ! -L $log_file ]] || die "Refusing to overwrite existing log: $log_file"
( set -o noclobber; : >"$log_file" ) 2>/dev/null || die "Cannot create startup log: $log_file"
chmod 0600 "$log_file"
exec >>"$log_file" 2>&1

log "Lock startup helper started."
log "Readiness budget: ${K41_LOCK_READY_TIMEOUT:-30}s; verification attempts: ${K41_LOCK_VERIFY_RETRIES:-10}."

ready_timeout=${K41_LOCK_READY_TIMEOUT:-30}
interval=${K41_LOCK_INTERVAL:-1}
verify_attempts=${K41_LOCK_VERIFY_RETRIES:-10}
command_timeout=1

[[ $ready_timeout =~ ^[1-9][0-9]*$ ]] || die 'K41_LOCK_READY_TIMEOUT must be a positive integer.'
(( ready_timeout <= 30 )) || die 'K41_LOCK_READY_TIMEOUT must not exceed 30 seconds.'
[[ $interval =~ ^[01]$ ]] || die 'K41_LOCK_INTERVAL must be 0 or 1 second.'
[[ $verify_attempts =~ ^[1-9][0-9]*$ ]] || die 'K41_LOCK_VERIFY_RETRIES must be a positive integer.'
(( verify_attempts <= 10 )) || die 'K41_LOCK_VERIFY_RETRIES must not exceed 10 attempts.'

marker_dir="$HOME/.cache/k41"
for path in "$HOME/.cache" "$marker_dir"; do
    [[ ! -L $path ]] || die "Refusing symlinked marker path: $path"
    [[ ! -e $path || -d $path ]] || die "Marker path is not a directory: $path"
    if [[ -e $path ]]; then
        [[ $(stat -c %u -- "$path") == "$EUID" ]] || die "Marker path is not owned by the desktop user: $path"
    fi
done
mkdir -p -- "$marker_dir"
[[ -d $marker_dir && ! -L $marker_dir && $(stat -c %u -- "$marker_dir") == "$EUID" ]] ||
    die 'Cannot establish a user-owned readiness marker directory.'

marker="$marker_dir/boot-lock-ready"
if [[ -e $marker || -L $marker ]]; then
    [[ -f $marker && ! -L $marker && $(stat -c %u -- "$marker") == "$EUID" ]] ||
        die 'Existing readiness marker is not a regular user-owned file.'
fi

mark_ready() {
    local temporary
    temporary="$(mktemp "$marker_dir/.boot-lock-ready.XXXXXX")" ||
        die 'Cannot create temporary readiness marker.'
    chmod 0600 "$temporary"
    mv -f -- "$temporary" "$marker"
    log 'Readiness marker published.'
}

last_ipc_output=''
lock_ipc_ready() {
    local listing
    if ! listing="$(timeout --signal=TERM --kill-after=1 "${command_timeout}s" caelestia shell -s 2>&1)"; then
        last_ipc_output=$listing
        return 1
    fi
    if grep -Eq 'target[[:space:]]+lock([[:space:]]|$)' <<<"$listing" &&
       grep -Eq 'function[[:space:]]+isLocked\(\):[[:space:]]*bool' <<<"$listing"; then
        return 0
    fi
    last_ipc_output=$listing
    return 1
}

is_locked() {
    local state
    state="$(timeout --signal=TERM --kill-after=1 "${command_timeout}s" caelestia shell lock isLocked 2>&1)" ||
        return 1
    [[ $state =~ ^[[:space:]]*true[[:space:]]*$ ]]
}

# Discovery and verification are separate bounded phases. No nested retry multiplication.
deadline=$((SECONDS + ready_timeout))
ipc_ready=0
while (( SECONDS < deadline )); do
    if lock_ipc_ready; then
        ipc_ready=1
        log 'Caelestia lock IPC is ready.'
        break
    fi
    sleep "$interval"
done

if (( ipc_ready == 1 )); then
    if timeout --signal=TERM --kill-after=1 "${command_timeout}s" caelestia shell lock lock; then
        log 'Caelestia lock request accepted.'
        for ((attempt = 1; attempt <= verify_attempts; attempt++)); do
            if is_locked; then
                log "Caelestia lock state verified on attempt $attempt."
                mark_ready
                exit 0
            fi
            log "Caelestia lock state not yet verified ($attempt/$verify_attempts)."
            sleep "$interval"
        done
        log 'Caelestia lock did not reach verified state within the bounded verification window.'
    else
        log 'Caelestia lock IPC rejected or timed out on the lock request.'
    fi
else
    log "Caelestia lock IPC did not become ready within ${ready_timeout}s."
    if [[ -n $last_ipc_output ]]; then
        log "Last Caelestia IPC response: ${last_ipc_output:0:1200}"
    else
        log 'Caelestia IPC returned no diagnostic output.'
    fi
fi

# The fallback must use a known, managed config; never depend on an implicit search path.
if ! command -v hyprlock >/dev/null 2>&1; then
    die 'Caelestia lock was not verified and Hyprlock fallback is unavailable.'
fi
hyprlock_config="$HOME/.config/k41/hyprlock-fallback.conf"
[[ -f $hyprlock_config && ! -L $hyprlock_config && -s $hyprlock_config ]] ||
    die "Managed Hyprlock fallback config is missing or unsafe: $hyprlock_config"
[[ $(stat -c %u -- "$hyprlock_config") == "$EUID" ]] ||
    die 'Managed Hyprlock fallback config is not owned by the desktop user.'

log "Starting Hyprlock fallback with explicit config: $hyprlock_config"
hyprlock --config "$hyprlock_config" &
lock_pid=$!
sleep 1
if ! jobs -pr | grep -Fxq "$lock_pid"; then
    set +e
    wait "$lock_pid"
    fallback_status=$?
    set -e
    die "Hyprlock exited before readiness could be established (exit=$fallback_status)."
fi

mark_ready
log "Hyprlock fallback is running (pid=$lock_pid); waiting for unlock/exit."
set +e
wait "$lock_pid"
fallback_status=$?
set -e
log "Hyprlock fallback exited (exit=$fallback_status)."
exit "$fallback_status"
