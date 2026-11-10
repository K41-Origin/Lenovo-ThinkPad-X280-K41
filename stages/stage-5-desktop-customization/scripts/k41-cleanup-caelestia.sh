#!/usr/bin/env bash
# Disable the Caelestia dashboard without deleting upstream source files.
# Default mode is read-only. Use --apply to modify user configuration.
set -Eeuo pipefail
umask 077

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

[[ $EUID -ne 0 ]] || die 'Run as the regular desktop user; do not use sudo.'
[[ -n ${HOME:-} && -d $HOME ]] || die 'HOME must point to an existing directory.'
command -v python3 >/dev/null 2>&1 || die 'python3 is required.'

mode="dry-run"
rollback_dir=""
case ${1:-} in
    "") ;;
    --dry-run) [[ $# -eq 1 ]] || die 'Usage: k41-cleanup-caelestia.sh [--dry-run|--apply|--rollback BACKUP_DIR]' ;;
    --apply) [[ $# -eq 1 ]] || die 'Usage: k41-cleanup-caelestia.sh [--dry-run|--apply|--rollback BACKUP_DIR]'; mode="apply" ;;
    --rollback)
        [[ $# -eq 2 ]] || die 'Usage: k41-cleanup-caelestia.sh --rollback BACKUP_DIR'
        mode="rollback"
        rollback_dir=$2
        ;;
    *) die 'Usage: k41-cleanup-caelestia.sh [--dry-run|--apply|--rollback BACKUP_DIR]' ;;
esac

exec python3 - "$mode" "$rollback_dir" "$HOME" <<'PY'
import datetime
import hashlib
import json
import os
import pathlib
import shutil
import stat
import sys
import tempfile

mode, rollback_arg, home_arg = sys.argv[1:]
home = pathlib.Path(home_arg).resolve(strict=True)
config_root = pathlib.Path(os.environ.get("XDG_CONFIG_HOME", home / ".config"))
state_root = pathlib.Path(os.environ.get("XDG_STATE_HOME", home / ".local/state"))
caelestia_root = config_root / "caelestia"
global_config = caelestia_root / "shell.json"
backup_root = state_root / "k41" / "caelestia-cleanup" / "backups"
uid = os.getuid()

def fail(message):
    raise SystemExit(f"ERROR: {message}")

def reject_symlink_components(path):
    path = pathlib.Path(os.path.abspath(path))
    current = pathlib.Path(path.anchor)
    for part in path.parts[1:]:
        current = current / part
        if current.is_symlink():
            fail(f"Symlink path component is not allowed: {current}")

def require_owned_regular_file(path):
    reject_symlink_components(path)
    if not path.exists() or not path.is_file():
        fail(f"Expected an existing regular file: {path}")
    info = path.stat()
    if info.st_uid != uid:
        fail(f"File is not owned by the current user: {path}")
    return info

def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()

def atomic_restore(source, target):
    target.parent.mkdir(parents=True, exist_ok=True)
    reject_symlink_components(target.parent)
    fd, temporary = tempfile.mkstemp(prefix=".k41-dashboard-", dir=target.parent)
    try:
        with os.fdopen(fd, "wb") as out, source.open("rb") as inp:
            shutil.copyfileobj(inp, out)
        shutil.copystat(source, temporary)
        os.replace(temporary, target)
    except BaseException:
        try:
            os.unlink(temporary)
        except FileNotFoundError:
            pass
        raise

def load_config(path):
    require_owned_regular_file(path)
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        fail(f"Invalid JSON in {path}: {type(exc).__name__}: {exc}")
    if not isinstance(value, dict):
        fail(f"Expected a JSON object in {path}")
    section = value.get("dashboard")
    if section is not None and not isinstance(section, dict):
        fail(f"dashboard section is not a JSON object in {path}")
    return value

def print_state(path, data):
    section = data.get("dashboard")
    enabled = section.get("enabled", "<default>") if isinstance(section, dict) else "<section absent>"
    print(f"{path}: dashboard.enabled={enabled}")

if mode == "rollback":
    reject_symlink_components(backup_root)
    backup_path = pathlib.Path(rollback_arg)
    reject_symlink_components(backup_path)
    try:
        resolved_backup = backup_path.resolve(strict=True)
        resolved_root = backup_root.resolve(strict=True)
        resolved_backup.relative_to(resolved_root)
    except Exception:
        fail("Rollback backup must be an existing directory inside the managed backup root.")
    if not resolved_backup.is_dir() or resolved_backup.stat().st_uid != uid:
        fail("Rollback backup directory must be a directory owned by the current user.")
    manifest_path = resolved_backup / "manifest.json"
    require_owned_regular_file(manifest_path)
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except Exception as exc:
        fail(f"Invalid backup manifest: {type(exc).__name__}")
    entries = manifest.get("files")
    if not isinstance(entries, list) or not entries:
        fail("Backup manifest contains no restorable files.")
    restored = []
    for entry in entries:
        rel = pathlib.PurePosixPath(entry.get("relative_path", ""))
        if rel.is_absolute() or ".." in rel.parts:
            fail("Unsafe path in backup manifest.")
        source = resolved_backup / "files" / pathlib.Path(*rel.parts)
        target = config_root / pathlib.Path(*rel.parts)
        require_owned_regular_file(source)
        if sha256(source) != entry.get("sha256"):
            fail(f"Backup checksum mismatch: {source}")
        require_owned_regular_file(target)
        restored.append((source, target))
    print(f"Rollback will restore {len(restored)} configuration file(s):")
    for _, target in restored:
        print(f"  {target}")
    answer = input("Restore the exact pre-cleanup configuration? [y/N] ").strip().lower()
    if answer not in ("y", "yes"):
        fail("Rollback cancelled.")
    for source, target in restored:
        atomic_restore(source, target)
    print("Rollback completed. Restart Caelestia manually to reload the restored configuration.")
    raise SystemExit(0)

reject_symlink_components(config_root)
reject_symlink_components(caelestia_root)
if not caelestia_root.is_dir():
    fail(f"Caelestia configuration directory is missing: {caelestia_root}")

global_data = load_config(global_config)
targets = [(global_config, global_data, True)]
monitor_root = caelestia_root / "monitors"
if monitor_root.exists():
    reject_symlink_components(monitor_root)
    if not monitor_root.is_dir():
        fail(f"Monitor configuration path is not a directory: {monitor_root}")
    for path in sorted(monitor_root.glob("*/shell.json")):
        data = load_config(path)
        if "dashboard" in data:
            targets.append((path, data, False))

changes = []
print("Caelestia dashboard cleanup — configuration-only")
print("No QML source, upstream checkout, package, keybind, or service will be deleted or modified.")
for path, data, is_global in targets:
    print_state(path, data)
    section = data.get("dashboard")
    if section is None:
        section = {}
        data["dashboard"] = section
    current = section.get("enabled", "<default>")
    if current is not False:
        section["enabled"] = False
        changes.append((path, data))
    elif is_global:
        print("  already disabled")

if not changes:
    print("No changes required; dashboard is already disabled in all relevant config files.")
    raise SystemExit(0)

print("Planned changes:")
for path, data in changes:
    print(f"  Set dashboard.enabled=false in {path}")

if mode == "dry-run":
    print("DRY RUN ONLY. No files were changed.")
    print("Run with --apply after reviewing the latest audit report.")
    raise SystemExit(0)

answer = input("Create a private backup and disable the dashboard now? [y/N] ").strip().lower()
if answer not in ("y", "yes"):
    fail("Apply cancelled.")

reject_symlink_components(state_root)
backup_parent = backup_root
for directory in (state_root / "k41", state_root / "k41" / "caelestia-cleanup", backup_root):
    reject_symlink_components(directory)
    directory.mkdir(mode=0o700, parents=True, exist_ok=True)
    if directory.is_symlink() or directory.stat().st_uid != uid:
        fail(f"Unsafe backup directory ownership/type: {directory}")
    os.chmod(directory, 0o700)

stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
backup_dir = backup_parent / stamp
suffix = 0
while True:
    candidate = backup_dir if suffix == 0 else backup_parent / f"{stamp}-{suffix}"
    try:
        candidate.mkdir(mode=0o700)
        backup_dir = candidate
        break
    except FileExistsError:
        suffix += 1
os.chmod(backup_dir, 0o700)

entries = []
for path, _ in changes:
    relative = path.relative_to(config_root)
    destination = backup_dir / "files" / relative
    destination.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    shutil.copy2(path, destination)
    entries.append({
        "relative_path": relative.as_posix(),
        "sha256": sha256(destination),
    })
manifest = {
    "created_utc": stamp,
    "purpose": "Restore Caelestia dashboard configuration before K41 cleanup.",
    "files": entries,
}
(backup_dir / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
os.chmod(backup_dir / "manifest.json", 0o600)

written = []
try:
    for path, data in changes:
        info = require_owned_regular_file(path)
        fd, temporary = tempfile.mkstemp(prefix=".k41-dashboard-", dir=path.parent)
        try:
            with os.fdopen(fd, "w", encoding="utf-8") as stream:
                json.dump(data, stream, indent=2, ensure_ascii=False)
                stream.write("\n")
            os.chmod(temporary, stat.S_IMODE(info.st_mode))
            os.replace(temporary, path)
        except BaseException:
            try:
                os.unlink(temporary)
            except FileNotFoundError:
                pass
            raise
        written.append(path)
        verified = load_config(path)
        if verified.get("dashboard", {}).get("enabled") is not False:
            fail(f"Post-write verification failed: {path}")
except BaseException:
    for path in reversed(written):
        relative = path.relative_to(config_root)
        source = backup_dir / "files" / relative
        atomic_restore(source, path)
    raise

print("Dashboard disabled and JSON read-back verification passed.")
print(f"Backup: {backup_dir}")
print("Caelestia was not restarted. Restart manually after reviewing the result.")
PY
