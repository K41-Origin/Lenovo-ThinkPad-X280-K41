#!/usr/bin/env bash
# Safely migrate an existing K41 tty1 autologin profile to the output-capturing launcher.
set -Eeuo pipefail
umask 077

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
info() { printf 'INFO: %s\n' "$*"; }

(( EUID == 0 )) || die 'Run with sudo from the regular desktop account.'
[[ -n ${SUDO_USER:-} && $SUDO_USER != root ]] || die 'SUDO_USER is missing; invoke with sudo from the desktop account.'
user_name=$SUDO_USER
entry=$(getent passwd "$user_name") || die "Cannot resolve account: $user_name."
IFS=: read -r _ _ uid gid _ home shell <<<"$entry"
[[ $shell == */bash && -d $home ]] || die 'The desktop account must use Bash and have a valid home directory.'

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source_launcher="$script_dir/k41-start-hyprland.sh"
profile="$home/.bash_profile"
local_bin="$home/.local/bin"
target_launcher="$local_bin/k41-start-hyprland"
[[ -r $source_launcher ]] || die 'K41 Hyprland launcher source is missing.'
[[ -f $profile && ! -L $profile && -w $(dirname -- "$profile") ]] || die 'A regular, safely writable .bash_profile is required.'
[[ ! -L $local_bin && ! -L $target_launcher ]] || die 'Symlink paths are not supported.'

python3 - "$profile" <<'PY'
import pathlib, re, sys
p = pathlib.Path(sys.argv[1])
text = p.read_text(encoding="utf-8")
start, end = "# K41 HYPRLAND AUTOLOGIN START", "# K41 HYPRLAND AUTOLOGIN END"
if text.count(start) != 1 or text.count(end) != 1:
    raise SystemExit("Expected exactly one managed K41 autologin block.")
a = text.index(start)
b = text.index(end, a) + len(end)
block = text[a:b]
old = re.findall(r"(?m)^([ \t]*)start-hyprland[ \t]*$", block)
new = re.findall(r'(?m)^([ \t]*)"\$HOME/\.local/bin/k41-start-hyprland"[ \t]*$', block)
if len(new) == 1 and not old:
    raise SystemExit("K41 launcher is already configured.")
if len(old) != 1 or new:
    raise SystemExit("Expected exactly one plain start-hyprland command in the managed block.")
PY

backup_root="/var/lib/k41/hyprland-launcher/backups"
install -d -m 0700 "$backup_root"
stamp="$(date -u +'%Y%m%dT%H%M%SZ')"
backup="$backup_root/$stamp"
n=0
while ! mkdir -m 0700 -- "$backup" 2>/dev/null; do
    n=$((n + 1))
    backup="$backup_root/$stamp-$n"
done
cp -a "$profile" "$backup/bash_profile"
if [[ -e $target_launcher ]]; then
    [[ -f $target_launcher ]] || die 'Existing launcher target is not a regular file.'
    cp -a "$target_launcher" "$backup/k41-start-hyprland"
    printf 'present\n' >"$backup/launcher-state"
else
    printf 'absent\n' >"$backup/launcher-state"
fi
chown -R root:root "$backup"
chmod 0700 "$backup"

printf 'Install the K41 launcher for %s and update the managed TTY1 login block? [y/N] ' "$user_name"
IFS= read -r answer </dev/tty
[[ $answer =~ ^[Yy]([Ee][Ss])?$ ]] || die 'Cancelled; no system configuration was changed.'

install -d -m 0755 -o "$uid" -g "$gid" "$local_bin"
install -m 0755 -o "$uid" -g "$gid" "$source_launcher" "$target_launcher"
python3 - "$profile" <<'PY'
import os, pathlib, re, stat, sys, tempfile
p = pathlib.Path(sys.argv[1])
text = p.read_text(encoding="utf-8")
start, end = "# K41 HYPRLAND AUTOLOGIN START", "# K41 HYPRLAND AUTOLOGIN END"
a = text.index(start)
b = text.index(end, a) + len(end)
block = text[a:b]
updated, count = re.subn(r"(?m)^([ \t]*)start-hyprland[ \t]*$", r'\1"$HOME/.local/bin/k41-start-hyprland"', block)
if count != 1:
    raise SystemExit("Managed K41 launch command changed during migration.")
fd, temporary = tempfile.mkstemp(prefix=".k41-profile-", dir=p.parent)
try:
    with os.fdopen(fd, "w", encoding="utf-8") as stream:
        stream.write(text[:a] + updated + text[b:])
    os.chmod(temporary, stat.S_IMODE(p.stat().st_mode))
    os.replace(temporary, p)
except BaseException:
    try: os.unlink(temporary)
    except FileNotFoundError: pass
    raise
PY
chown "$uid:$gid" "$profile"

info 'K41 launcher installed. start-hyprland stdout/stderr will be written to ~/.local/state/k41/hyprland-startup.log.'
info "Backup retained at: $backup"
info 'No reboot is required to apply the profile change; it takes effect on the next tty1 login.'
