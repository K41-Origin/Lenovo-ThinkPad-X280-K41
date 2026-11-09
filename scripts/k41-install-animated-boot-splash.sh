#!/usr/bin/env bash
# Install the animated Quickshell handoff overlay without changing disk or LUKS state.
set -Eeuo pipefail
umask 077

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
(( EUID == 0 )) || die "Run with sudo from the desktop account."
[[ -n ${SUDO_USER:-} && $SUDO_USER != root ]] || die "Run sudo from the regular desktop account."
USER_NAME=$SUDO_USER
entry=$(getent passwd "$USER_NAME") || die "Cannot resolve $USER_NAME."
IFS=: read -r _ _ uid gid _ home shell <<<"$entry"
[[ -d $home && -f $home/.config/hypr/hyprland.lua ]] || die "Expected $home/.config/hypr/hyprland.lua; refusing to guess the active Hyprland config."
command -v qs >/dev/null 2>&1 || die "Quickshell (qs) is not installed."
command -v python3 >/dev/null 2>&1 || die "python3 is required."

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
repo_root=$(cd -- "$script_dir/.." && pwd -P)
source_qml="$repo_root/config/quickshell/k41-boot-splash/shell.qml"
source_helper="$repo_root/scripts/k41-lock-caelestia-after-start.sh"
[[ -s $source_qml ]] || die "Missing K41 Quickshell configuration: $source_qml"
target_dir="$home/.config/quickshell/k41-boot-splash"
install -d -m 0755 -o "$uid" -g "$gid" "$target_dir"
install -m 0644 -o "$uid" -g "$gid" "$source_qml" "$target_dir/shell.qml"
local_bin="$home/.local/bin"
install -d -m 0755 -o "$uid" -g "$gid" "$local_bin"
install -m 0755 -o "$uid" -g "$gid" "$source_helper" "$local_bin/k41-lock-caelestia-after-start"

lua="$home/.config/hypr/hyprland.lua"
marker="-- K41 ANIMATED BOOT SPLASH START"
if grep -Fq "$marker" "$lua"; then
    printf 'K41 animated splash hook already exists; no duplicate inserted.\n'
    exit 0
fi

python3 - "$lua" <<'PY'
import os, pathlib, stat, sys, tempfile
p = pathlib.Path(sys.argv[1])
text = p.read_text(encoding="utf-8")
marker = "-- K41 ANIMATED BOOT SPLASH START"
hook = 'hl.on("hyprland.start", function()'
if marker in text:
    raise SystemExit("K41 animated splash hook already exists.")
if text.count(hook) < 1:
    raise SystemExit("No existing Hyprland-start callback found; refusing unsafe insertion.")
# Insert before the existing callback body so the overlay is requested before Caelestia startup.
insertion = hook + '\n    hl.exec_cmd("sh -c \'mkdir -p \\"$HOME/.cache/k41\\"; qs -c k41-boot-splash >/dev/null 2>&1 & echo $! > \\"$HOME/.cache/k41/boot-splash.pid\\"\'")\n    ' + marker + '\n'
text = text.replace(hook, insertion, 1)
fd, tmp = tempfile.mkstemp(prefix=".k41-boot-splash-", dir=p.parent)
try:
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(text)
    os.chmod(tmp, stat.S_IMODE(p.stat().st_mode))
    os.replace(tmp, p)
except BaseException:
    try: os.unlink(tmp)
    except FileNotFoundError: pass
    raise
PY
chown "$uid:$gid" "$lua"
printf 'Installed animated K41 handoff splash for %s.\n' "$USER_NAME"
printf 'The overlay is started by the existing Hyprland-start hook and is removed after lock verification.\n'
printf 'No LUKS, TPM, UKI, mkinitcpio, or bootloader settings were changed.\n'
