#!/usr/bin/env bash
# Remove only obsolete legacy boot-splash directives from the marked K41
# startup block. Caelestia startup and its lock IPC remain required.
set -Eeuo pipefail
umask 077

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
info() { printf 'INFO: %s\n' "$*"; }
usage() {
    printf 'Usage: %s [--dry-run|--apply]\n' "$0"
}

mode=dry-run
case ${1:---dry-run} in
    --dry-run) [[ $# -le 1 ]] || { usage >&2; exit 2; } ;;
    --apply) [[ $# -le 1 ]] || { usage >&2; exit 2; }; mode=apply ;;
    *) usage >&2; exit 2 ;;
esac

(( EUID != 0 )) || die 'Run as the regular desktop user, never with sudo.'
[[ -n ${HOME:-} && $HOME == /* && -d $HOME ]] || die 'HOME is missing or invalid.'
for command_name in python3 mktemp stat mkdir cp chmod mv cmp diff date rm; do
    command -v "$command_name" >/dev/null 2>&1 || die "Required command is unavailable: $command_name"
done

config_root="$HOME/.config"
hypr_root="$config_root/hypr"
hypr_lua="$hypr_root/hyprland.lua"
state_root="$HOME/.local/state/k41/lockscreen"
backup_root="$state_root/config-backups"

[[ -d $config_root && ! -L $config_root && $(stat -c %u -- "$config_root") == "$EUID" ]] ||
    die 'User config directory is missing, symlinked, or not owned by this account.'
[[ -d $hypr_root && ! -L $hypr_root && $(stat -c %u -- "$hypr_root") == "$EUID" ]] ||
    die 'Hyprland config directory is missing, symlinked, or not owned by this account.'
[[ -f $hypr_lua && ! -L $hypr_lua && -s $hypr_lua ]] ||
    die 'Expected regular non-empty ~/.config/hypr/hyprland.lua; refusing to guess another active config.'
[[ $(stat -c %u -- "$hypr_lua") == "$EUID" ]] || die 'Hyprland Lua config is not owned by this account.'

stage="$(mktemp "$hypr_root/.hyprland.lua.k41-cleanup.XXXXXX")"
trap '[[ -z ${stage:-} || ! -e $stage ]] || rm -f -- "$stage"' EXIT

python3 - "$hypr_lua" "$stage" <<'PY'
from pathlib import Path
import re
import sys

source, destination = map(Path, sys.argv[1:])
text = source.read_text()
start = "-- K41 CAELESTIA AUTOLOCK START"
end = "-- K41 CAELESTIA AUTOLOCK END"

if text.count(start) != 1 or text.count(end) != 1:
    raise SystemExit("Expected exactly one bounded K41 autolock block; refusing an ambiguous edit.")
before, rest = text.split(start, 1)
block, after = rest.split(end, 1)
if end in block or start in block:
    raise SystemExit("Nested K41 markers found; refusing to edit.")

lines = block.splitlines(keepends=True)
startup = [line for line in lines if "caelestia shell -d" in line]
helper = [line for line in lines if "k41-lock-caelestia-after-start" in line]
if len(startup) != 1 or not re.fullmatch(
    r"""\s*hl\.exec_cmd\(["']caelestia shell -d["']\)\s*\n?""", startup[0]
):
    raise SystemExit("Expected exactly one canonical Caelestia shell startup command in the K41 block.")
if len(helper) != 1 or "hl.exec_cmd" not in helper[0]:
    raise SystemExit("Expected exactly one K41 lock-helper invocation; refusing to rewrite unknown logic.")
if lines.index(startup[0]) > lines.index(helper[0]):
    raise SystemExit("Caelestia startup must remain before the K41 lock helper.")

removed = []
kept = []
for line in lines:
    stripped = line.strip()
    if "qs -c k41-boot-splash" in line:
        removed.append(line)
        continue
    if stripped == "-- K41 ANIMATED BOOT SPLASH START":
        removed.append(line)
        continue
    if stripped == "-- Start Caelestia only if no existing startup entry was detected.":
        removed.append(line)
        continue
    kept.append(line)

new_block = "".join(kept)
if new_block.count("caelestia shell -d") != 1:
    raise SystemExit("Cleanup would alter required Caelestia startup; refusing.")
if new_block.count("k41-lock-caelestia-after-start") != 1:
    raise SystemExit("Cleanup would alter the K41 lock helper; refusing.")
if "qs -c k41-boot-splash" in new_block:
    raise SystemExit("Legacy boot splash directive remains after cleanup.")
destination.write_text(before + start + new_block + end + after)
print(f"REMOVED_LINES={len(removed)}")
for line in removed:
    print("REMOVED: " + line.rstrip("\n"))
PY

[[ -s $stage ]] || die 'Staged configuration is empty.'
if cmp -s "$hypr_lua" "$stage"; then
    info 'No obsolete Caelestia/K41 startup lines found; configuration is already clean.'
    exit 0
fi

info 'Proposed focused changes:'
diff -u -- "$hypr_lua" "$stage" || [[ $? -eq 1 ]] || die 'Unable to display staged diff.'

if [[ $mode == dry-run ]]; then
    info 'Dry-run only; no files were changed. Review the diff, then rerun with --apply.'
    exit 0
fi

for path in "$HOME/.local" "$HOME/.local/state" "$HOME/.local/state/k41" "$state_root" "$backup_root"; do
    [[ ! -L $path ]] || die "Refusing symlinked backup path: $path"
    [[ ! -e $path || -d $path ]] || die "Backup path is not a directory: $path"
    if [[ -e $path ]]; then
        [[ $(stat -c %u -- "$path") == "$EUID" ]] || die "Backup path is not owned by this account: $path"
    fi
done
mkdir -p -- "$backup_root"
[[ -d $backup_root && ! -L $backup_root && $(stat -c %u -- "$backup_root") == "$EUID" ]] ||
    die 'Cannot establish a private user-owned backup directory.'
chmod 0700 "$backup_root"

stamp="$(date -u +'%Y%m%dT%H%M%SZ')"
backup="$backup_root/hyprland.lua-before-caelestia-cleanup-$stamp-${BASHPID}.bak"
[[ ! -e $backup && ! -L $backup ]] || die "Backup already exists: $backup"
cp -p -- "$hypr_lua" "$backup"
chmod 0600 "$backup"
cmp -s "$hypr_lua" "$backup" || die 'Backup verification failed; original config was not changed.'

lua_mode="$(stat -c %a -- "$hypr_lua")"
chmod "$lua_mode" "$stage"
mv -f -- "$stage" "$hypr_lua"
stage=""

grep -Fq 'hl.exec_cmd("caelestia shell -d")' "$hypr_lua" ||
    die 'Post-write check failed: Caelestia startup command is missing.'
grep -Fq 'k41-lock-caelestia-after-start' "$hypr_lua" ||
    die 'Post-write check failed: K41 lock helper is missing.'
! grep -Fq 'qs -c k41-boot-splash' "$hypr_lua" ||
    die 'Post-write check failed: legacy boot splash command remains.'
cmp -s "$backup" "$hypr_lua" && die 'Post-write check failed: config unexpectedly unchanged.'

info "Cleanup applied successfully: $hypr_lua"
info "Verified backup: $backup"
info 'Caelestia shell startup and Caelestia lock IPC support were preserved.'
info 'No shell.json, Quickshell QML/module, PAM, Hyprlock, systemd, Plymouth, or authentication files were modified.'
