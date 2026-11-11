#!/usr/bin/env bash
# Install the bounded lock helper and managed Hyprlock fallback, then remove
# duplicate Caelestia startup and obsolete non-Plymouth splash commands from
# the exact K41 block in the user's Hyprland Lua config.
set -Eeuo pipefail
umask 077

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
info() { printf 'INFO: %s\n' "$*"; }

(( EUID != 0 )) || die 'Run as the regular desktop user, never with sudo.'
[[ $# -eq 0 ]] || die 'This updater takes no arguments.'
[[ -n ${HOME:-} && $HOME == /* && -d $HOME ]] || die 'HOME is missing or invalid.'

for command_name in git stat date mkdir cp chmod install bash mktemp mv cmp sha256sum awk rm python3 grep; do
    command -v "$command_name" >/dev/null 2>&1 || die "Required command is unavailable: $command_name"
done

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(git -C "$script_dir" rev-parse --show-toplevel 2>/dev/null)" ||
    die 'Run this updater from a Git checkout.'
repo_root="$(cd -- "$repo_root" && pwd -P)"
[[ $(git -C "$repo_root" branch --show-current) == main ]] ||
    die 'Updater only runs from the main branch.'
[[ $(stat -c %u -- "$repo_root") == "$EUID" ]] ||
    die 'Repository checkout is not owned by the current user.'

source_helper="$repo_root/stages/stage-5-desktop-customization/workstreams/02-lock-screen/scripts/k41-lock-caelestia-after-start.sh"
source_config="$repo_root/stages/stage-5-desktop-customization/workstreams/02-lock-screen/config/hyprlock-fallback.conf"
bin_root="$HOME/.local/bin"
target_helper="$bin_root/k41-lock-caelestia-after-start"
config_root="$HOME/.config"
k41_config="$config_root/k41"
target_config="$k41_config/hyprlock-fallback.conf"
hypr_root="$config_root/hypr"
hypr_conf="$hypr_root/hyprland.conf"
hypr_lua="$hypr_root/hyprland.lua"
state_root="$HOME/.local/state"
lock_state="$state_root/k41/lockscreen"
backup_root="$lock_state/config-backups"

[[ -f $source_helper && ! -L $source_helper && -s $source_helper ]] ||
    die "Workstream 02 lock helper source is missing or unsafe: $source_helper"
[[ -f $source_config && ! -L $source_config && -s $source_config ]] ||
    die "Managed Hyprlock fallback config source is missing or unsafe: $source_config"
bash -n "$source_helper" || die 'Workstream 02 lock helper has invalid Bash syntax.'
grep -Fq -- '--config' "$source_helper" || die 'Lock helper does not pass an explicit Hyprlock config.'
grep -Fq 'input-field {' "$source_config" || die 'Fallback config has no password input field.'

command -v hyprlock >/dev/null 2>&1 || die 'hyprlock is not installed; install it before using this updater.'
hyprlock --help 2>&1 | grep -Fq -- '--config' ||
    die 'Installed hyprlock does not advertise --config support.'

for path in "$HOME/.local" "$bin_root" "$state_root" "$config_root" "$k41_config" "$hypr_root" "$state_root/k41" "$lock_state" "$backup_root"; do
    [[ ! -L $path ]] || die "Refusing symlinked user path: $path"
    [[ ! -e $path || -d $path ]] || die "User path is not a directory: $path"
    if [[ -e $path ]]; then
        [[ $(stat -c %u -- "$path") == "$EUID" ]] || die "User path is not owned by the current account: $path"
    fi
done
[[ -f $hypr_conf && ! -L $hypr_conf && -f $hypr_lua && ! -L $hypr_lua ]] ||
    die 'Expected regular ~/.config/hypr/hyprland.conf and hyprland.lua files.'

# Keep the single shell startup in hyprland.conf. The Lua hook only starts the
# readiness helper; launching Caelestia from both files caused duplicate shells.
conf_start_count="$(grep -Ec '^[[:space:]]*exec-once[[:space:]]*=[[:space:]]*caelestia shell -d[[:space:]]*$' "$hypr_conf" || true)"
[[ $conf_start_count == 1 ]] ||
    die "Expected exactly one 'exec-once = caelestia shell -d' in hyprland.conf; found $conf_start_count. No changes made."

mkdir -p -- "$bin_root" "$k41_config" "$backup_root"
for path in "$bin_root" "$k41_config" "$backup_root"; do
    [[ -d $path && ! -L $path && $(stat -c %u -- "$path") == "$EUID" ]] ||
        die "Cannot establish a user-owned directory: $path"
done

stamp="$(date -u +'%Y%m%dT%H%M%SZ')"
backup_one() {
    local source=$1 label=$2 destination
    [[ -f $source && ! -L $source ]] || die "Cannot back up unsafe file: $source"
    destination="$backup_root/$label-$stamp-${BASHPID}.bak"
    [[ ! -e $destination && ! -L $destination ]] || die "Backup already exists: $destination"
    cp -p -- "$source" "$destination"
    chmod 0600 "$destination"
    info "Backup created: $destination"
}

# Stage the Lua change before writing anything. Refuse ambiguous/unknown blocks.
lua_stage="$(mktemp "$hypr_root/.hyprland.lua.k41-stage.XXXXXX")"
cleanup() {
    [[ -z ${lua_stage:-} || ! -e $lua_stage ]] || rm -f -- "$lua_stage"
    [[ -z ${helper_stage:-} || ! -e $helper_stage ]] || rm -f -- "$helper_stage"
    [[ -z ${config_stage:-} || ! -e $config_stage ]] || rm -f -- "$config_stage"
}
trap cleanup EXIT

python3 - "$hypr_lua" "$lua_stage" <<'PY'
from pathlib import Path
import re
import sys

source, destination = map(Path, sys.argv[1:])
text = source.read_text()
start = "-- K41 CAELESTIA AUTOLOCK START"
end = "-- K41 CAELESTIA AUTOLOCK END"
if text.count(start) != 1 or text.count(end) != 1:
    raise SystemExit("Expected exactly one K41 Caelestia autolock block; refusing an ambiguous edit.")
before, rest = text.split(start, 1)
block, after = rest.split(end, 1)
lines = block.splitlines(keepends=True)

helper_lines = [line for line in lines if "k41-lock-caelestia-after-start" in line]
if len(helper_lines) != 1:
    raise SystemExit(f"Expected exactly one K41 lock-helper invocation in Lua block; found {len(helper_lines)}.")

splash_lines = [line for line in lines if "qs -c k41-boot-splash" in line]
if len(splash_lines) > 1:
    raise SystemExit("Multiple legacy K41 boot-splash invocations found; refusing automatic cleanup.")
caelestia_lines = [line for line in lines if "caelestia shell -d" in line]
if len(caelestia_lines) > 1:
    raise SystemExit("Multiple duplicate Caelestia startup commands found in Lua block; refusing automatic cleanup.")

cleaned = []
for line in lines:
    if "qs -c k41-boot-splash" in line:
        continue
    if "caelestia shell -d" in line:
        continue
    if line.strip() == "-- K41 ANIMATED BOOT SPLASH START":
        continue
    cleaned.append(line)

new_block = "".join(cleaned)
if "qs -c k41-boot-splash" in new_block or "caelestia shell -d" in new_block:
    raise SystemExit("Legacy startup command remains after transformation.")
if sum("k41-lock-caelestia-after-start" in line for line in cleaned) != 1:
    raise SystemExit("K41 lock-helper invocation was not preserved exactly once.")
destination.write_text(before + start + new_block + end + after)
PY

[[ -s $lua_stage ]] || die 'Staged Hyprland Lua config is empty.'
if ! cmp -s "$hypr_lua" "$lua_stage"; then
    info 'Hyprland Lua config contains the expected duplicate Caelestia/splash startup entries; a focused patch is staged.'
else
    info 'Hyprland Lua startup block is already normalized.'
fi

helper_stage="$(mktemp "$bin_root/.k41-lock-helper.XXXXXX")"
config_stage="$(mktemp "$k41_config/.hyprlock-fallback.XXXXXX")"
install -m 0755 -- "$source_helper" "$helper_stage"
install -m 0600 -- "$source_config" "$config_stage"
bash -n "$helper_stage" || die 'Staged lock helper failed Bash syntax validation.'
cmp -s "$source_helper" "$helper_stage" || die 'Staged lock helper differs from repository source.'
cmp -s "$source_config" "$config_stage" || die 'Staged fallback config differs from repository source.'

# Preserve every pre-existing target before replacing it.
if [[ -e $target_helper || -L $target_helper ]]; then
    [[ -f $target_helper && ! -L $target_helper && $(stat -c %u -- "$target_helper") == "$EUID" ]] ||
        die 'Installed helper target is not a regular user-owned file.'
    cmp -s "$source_helper" "$target_helper" || backup_one "$target_helper" 'lock-helper'
fi
if [[ -e $target_config || -L $target_config ]]; then
    [[ -f $target_config && ! -L $target_config && $(stat -c %u -- "$target_config") == "$EUID" ]] ||
        die 'Hyprlock config target is not a regular user-owned file.'
    cmp -s "$source_config" "$target_config" || backup_one "$target_config" 'hyprlock-config'
fi
if ! cmp -s "$hypr_lua" "$lua_stage"; then
    backup_one "$hypr_lua" 'hyprland-lua'
fi

mv -f -- "$helper_stage" "$target_helper"
helper_stage=""
mv -f -- "$config_stage" "$target_config"
config_stage=""
if ! cmp -s "$hypr_lua" "$lua_stage"; then
    lua_mode="$(stat -c %a -- "$hypr_lua")"
    chmod "$lua_mode" "$lua_stage"
    mv -f -- "$lua_stage" "$hypr_lua"
    lua_stage=""
fi

cmp -s "$source_helper" "$target_helper" || die 'Installed lock helper failed byte-for-byte verification.'
cmp -s "$source_config" "$target_config" || die 'Installed fallback config failed byte-for-byte verification.'
[[ -x $target_helper && -f $target_config && ! -L $target_config ]] ||
    die 'Installed helper/config failed final type or executable checks.'
grep -Fq -- '--config' "$target_helper" || die 'Installed helper does not use explicit fallback config.'
if grep -Fq 'qs -c k41-boot-splash' "$hypr_lua" ||
   grep -Fq 'caelestia shell -d' "$hypr_lua"; then
    die 'Legacy duplicate startup directive remains in Hyprland Lua config.'
fi
grep -Fq 'k41-lock-caelestia-after-start' "$hypr_lua" ||
    die 'K41 lock readiness helper invocation is missing from Hyprland Lua config.'

info 'Workstream 02 runtime preparation completed.'
info "Installed helper: $target_helper"
info "Installed fallback config: $target_config"
info "Hyprland Lua config normalized: $hypr_lua"
info "Helper SHA-256: $(sha256sum "$target_helper" | awk '{print $1}')"
info "Fallback config SHA-256: $(sha256sum "$target_config" | awk '{print $1}')"
info 'Only user-local helper/config and the exact K41 Lua startup block were changed.'
info 'No system service, package, Plymouth, getty, PAM, authentication, bootloader, initramfs, or system configuration was changed.'
