#!/usr/bin/env bash
# Launch upstream start-hyprland without printing its startup output on tty1.
# stdin and the controlling TTY remain attached; stdout/stderr are retained privately.
set -Eeuo pipefail
umask 077

die() { printf 'K41 Hyprland launcher: %s\n' "$*" >&2; exit 1; }

launcher="$(command -v start-hyprland || true)"
[[ -n $launcher && -x $launcher ]] || die 'start-hyprland is not available in PATH.'
[[ $launcher != "$HOME/.local/bin/k41-start-hyprland" ]] || die 'Refusing recursive launcher resolution.'

state_dir="$HOME/.local/state/k41"
log_file="$state_dir/hyprland-startup.log"
install -d -m 0700 "$state_dir"
[[ ! -L $state_dir && -d $state_dir ]] || die 'The K41 state directory must be a real directory, not a symlink.'
[[ ! -L $log_file ]] || die 'Refusing to write through a symlink log file.'

if [[ -e $log_file ]]; then
    [[ -f $log_file ]] || die 'The startup log path is not a regular file.'
    if [[ $(stat -c %s -- "$log_file") -ge 1048576 ]]; then
        mv -f -- "$log_file" "$log_file.1"
    fi
fi

exec "$launcher" >>"$log_file" 2>&1
