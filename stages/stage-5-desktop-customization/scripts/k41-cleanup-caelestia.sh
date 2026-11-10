#!/usr/bin/env bash
# Disable the Caelestia Dashboard using its supported configuration setting.
# This script intentionally does not delete upstream QML/source files.
set -Eeuo pipefail
umask 077

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
info() { printf 'INFO: %s\n' "$*"; }

[[ $EUID -ne 0 ]] || die 'Run as the regular desktop user; do not use sudo.'
[[ $# -eq 0 ]] || die 'This script takes no arguments.'

config_root="${XDG_CONFIG_HOME:-$HOME/.config}"
caelestia_config="$config_root/caelestia"
global_config="$caelestia_config/shell.json"

command -v python3 >/dev/null 2>&1 || die 'python3 is required.'
[[ -d $caelestia_config && ! -L $caelestia_config ]] \
    || die "Caelestia config directory missing or symlinked: $caelestia_config"
[[ -f $global_config && ! -L $global_config ]] \
    || die "Global shell.json missing or symlinked: $global_config"

# The audit report identified a global dashboard.enabled=true setting and
# per-monitor configuration files. Validate every candidate before writing.
python3 - "$global_config" "$caelestia_config/monitors" <<'PY'
import datetime
import json
import os
import pathlib
import shutil
import stat
import sys
import tempfile

global_path = pathlib.Path(sys.argv[1])
monitor_root = pathlib.Path(sys.argv[2])
paths = [global_path]

if monitor_root.exists():
    if monitor_root.is_symlink() or not monitor_root.is_dir():
        raise SystemExit(f"Refusing unsafe monitor config path: {monitor_root}")
    for path in sorted(monitor_root.glob("*/shell.json")):
        if path.is_symlink() or not path.is_file():
            raise SystemExit(f"Refusing non-regular monitor config: {path}")
        paths.append(path)

records = []
for path in paths:
    if path.is_symlink() or not path.is_file():
        raise SystemExit(f"Refusing non-regular config file: {path}")
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        raise SystemExit(f"Invalid JSON in {path}: {type(exc).__name__}: {exc}")
    if not isinstance(data, dict):
        raise SystemExit(f"Expected a JSON object in {path}")
    if path == global_path and not isinstance(data.get("dashboard"), dict):
        raise SystemExit(f"Expected global dashboard object in {path}")
    section = data.get("dashboard")
    if section is not None and not isinstance(section, dict):
        raise SystemExit(f"Invalid dashboard section type in {path}")
    if isinstance(section, dict):
        section["enabled"] = False
        changed = True
    else:
        changed = False
    records.append((path, data, stat.S_IMODE(path.stat().st_mode), changed))

# Prepare all backups and replacement files before replacing any live config.
stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
prepared = []
try:
    for path, data, mode, changed in records:
        if not changed:
            print(f"INHERIT {path}: no dashboard override; global setting applies")
            continue
        backup = path.with_name(path.name + f".k41-dashboard-backup-{stamp}")
        suffix = 0
        while backup.exists():
            suffix += 1
            backup = path.with_name(path.name + f".k41-dashboard-backup-{stamp}-{suffix}")
        shutil.copy2(path, backup)
        fd, temporary = tempfile.mkstemp(prefix=".k41-dashboard-", dir=path.parent)
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            json.dump(data, stream, indent=2, ensure_ascii=False)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.chmod(temporary, mode)
        prepared.append((path, pathlib.Path(temporary), backup))
    replaced = []
    try:
        for path, temporary, backup in prepared:
            os.replace(temporary, path)
            replaced.append((path, backup))
    except BaseException:
        for path, backup in reversed(replaced):
            shutil.copy2(backup, path)
        raise
finally:
    for _, temporary, _ in prepared:
        try:
            temporary.unlink()
        except FileNotFoundError:
            pass

for path, _, backup in prepared:
    print(f"DISABLED {path}")
    print(f"BACKUP   {backup}")
PY

info 'Dashboard disabled in Caelestia configuration.'
info 'No Caelestia/Quickshell source files, Nexus pages, or package-owned files were deleted.'
info 'Nexus may still display its Dashboard settings entry; source-level removal is a separate change.'
