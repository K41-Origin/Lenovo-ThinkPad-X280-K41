#!/usr/bin/env bash
# Remove the Caelestia Dashboard source module and its configuration.
# Run as the regular desktop user. No audit/apply/rollback modes are provided.
set -Eeuo pipefail
umask 077

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
info() { printf 'INFO: %s\n' "$*"; }

[[ $EUID -ne 0 ]] || die 'Run as the regular desktop user; do not use sudo.'
[[ $# -eq 0 ]] || die 'This cleanup script takes no arguments.'

config_root="${XDG_CONFIG_HOME:-$HOME/.config}"
caelestia_config="$config_root/caelestia"
source_root="$config_root/quickshell/caelestia"
dashboard_dir="$source_root/modules/dashboard"

command -v python3 >/dev/null 2>&1 || die 'python3 is required.'
command -v realpath >/dev/null 2>&1 || die 'realpath is required.'
[[ -d $caelestia_config ]] || die "Caelestia config directory not found: $caelestia_config"

# Validate the exact source target before touching any configuration.
if [[ -L $source_root || -L $dashboard_dir ]]; then
    die 'Refusing to remove a symlinked Caelestia source path.'
fi
if [[ -d $dashboard_dir ]]; then
    resolved_source="$(realpath -e -- "$source_root")"
    resolved_dashboard="$(realpath -e -- "$dashboard_dir")"
    [[ $resolved_dashboard == "$resolved_source/modules/dashboard" ]] \
        || die "Unexpected Dashboard path; refusing deletion: $resolved_dashboard"
    if git -C "$source_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        if [[ -n $(git -C "$source_root" status --porcelain --untracked-files=all) ]]; then
            die "Caelestia source checkout has local changes; refusing to delete files: $source_root"
        fi
    fi
fi

# Collect and validate every relevant JSON file before changing any of them.
mapfile -d '' config_files < <(
    find "$caelestia_config" -type f -name shell.json -print0
)
(("${#config_files[@]}" > 0)) || die "No shell.json found under $caelestia_config"

python3 - "${config_files[@]}" <<'PY'
import json
import os
import pathlib
import stat
import sys
import tempfile

records = []
for raw in sys.argv[1:]:
    path = pathlib.Path(raw)
    if path.is_symlink() or not path.is_file():
        raise SystemExit(f"Refusing non-regular config file: {path}")
    original_mode = stat.S_IMODE(path.stat().st_mode)
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        raise SystemExit(f"Invalid JSON in {path}: {type(exc).__name__}: {exc}")
    if not isinstance(data, dict):
        raise SystemExit(f"Expected a JSON object in {path}")
    records.append((path, data, original_mode))

for path, data, original_mode in records:
    if "dashboard" not in data:
        print(f"UNCHANGED {path}: Dashboard setting absent")
        continue
    del data["dashboard"]
    fd, temporary = tempfile.mkstemp(prefix=".k41-cleanup-", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            json.dump(data, stream, indent=2, ensure_ascii=False)
            stream.write("\n")
        os.chmod(temporary, original_mode)
        os.replace(temporary, path)
    except BaseException:
        try:
            os.unlink(temporary)
        except FileNotFoundError:
            pass
        raise
    print(f"UPDATED {path}: removed dashboard configuration")
PY

# Remove only the Dashboard module directory; preserve all sibling modules.
if [[ -d $dashboard_dir ]]; then
    rm -rf -- "$resolved_dashboard"
    info "Removed Dashboard source module: $resolved_dashboard"
else
    info "Dashboard source module not found: $dashboard_dir"
fi

info 'Dashboard cleanup completed. Other Caelestia modules and settings were not targeted.'
