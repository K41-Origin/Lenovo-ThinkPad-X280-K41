#!/usr/bin/env bash
# Install/rollback the K41 horizontal Caelestia workspace dock.
set -Eeuo pipefail
umask 077

SCRIPT_NAME=${0##*/}
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
info() { printf 'INFO: %s\n' "$*"; }

usage() {
    cat <<'EOF'
Usage:
  bash k41-install-caelestia-dock.sh [--install]
  bash k41-install-caelestia-dock.sh --check
  bash k41-install-caelestia-dock.sh --rollback BACKUP_DIRECTORY

Install backs up every target before changing it. No sudo, package changes,
service restart, Quickshell reload, or automatic rollback is performed.
EOF
}

mode=${1:---install}
case "$mode" in
    --install) ;;
    --check) ;;
    --rollback)
        [[ $# -eq 2 ]] || { usage >&2; exit 2; }
        rollback_dir=$2
        ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
esac

[[ $EUID -ne 0 ]] || die 'Run as the regular desktop user; do not use sudo.'
for cmd in git python3 install cp tee date; do
    command -v "$cmd" >/dev/null 2>&1 || die "Required command not found: $cmd"
done

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(git -C "$script_dir" rev-parse --show-toplevel 2>/dev/null)" ||
    die 'Cannot locate the project Git repository.'
source_root="${K41_CAELSTIA_SOURCE:-$HOME/.config/quickshell/caelestia}"
config_file="${XDG_CONFIG_HOME:-$HOME/.config}/caelestia/shell.json"
dock_source="$repo_root/stages/stage-5-desktop-customization/workstreams/04-taskbar-panel/config/quickshell/caelestia/modules/k41dock/K41Dock.qml"
dock_target="$source_root/modules/k41dock/K41Dock.qml"
shell_file="$source_root/shell.qml"

[[ -f $shell_file ]] || die "Caelestia source entry point not found: $shell_file"
[[ -f $config_file ]] || die "Runtime Caelestia config not found: $config_file"

if [[ $mode == --check ]]; then
    [[ -f $dock_source ]] || die "Dock QML source missing from repository: $dock_source"
    python3 - "$shell_file" "$config_file" "$dock_source" <<'PY'
import json, pathlib, sys
shell, config, dock = map(pathlib.Path, sys.argv[1:])
text = shell.read_text(encoding="utf-8")
if text.count("ShellRoot {") != 1:
    raise SystemExit("FAIL: expected exactly one ShellRoot { declaration")
if "K41Dock.K41Dock {" in text:
    raise SystemExit("FAIL: K41 dock is already wired into shell.qml")
if "import \"modules/k41dock\" as K41Dock" in text:
    raise SystemExit("FAIL: K41 dock import already exists")
data = json.loads(config.read_text(encoding="utf-8"))
if not isinstance(data.get("bar"), dict) or not isinstance(data["bar"].get("entries"), list):
    raise SystemExit("FAIL: shell.json does not have the expected bar.entries structure")
json.loads(dock.read_text(encoding="utf-8")) if dock.suffix == ".json" else None
print("PASS: source layout, runtime JSON, and deployment preconditions")
PY
    exit 0
fi

backup_base="${XDG_STATE_HOME:-$HOME/.local/state}/k41/backups/caelestia-dock"
timestamp="$(date -u +'%Y%m%dT%H%M%SZ')"
if [[ $mode == --install ]]; then
    mkdir -p -- "$backup_base"
    chmod 700 "$backup_base"
    backup_dir="$backup_base/$timestamp"
    suffix=0
    while ! mkdir -- "$backup_dir" 2>/dev/null; do
        suffix=$((suffix + 1))
        backup_dir="$backup_base/$timestamp-$suffix"
    done
    chmod 700 "$backup_dir"
    mkdir -p -- "$backup_dir/files"
    : >"$backup_dir/manifest.tsv"
    log_file="$backup_dir/implementation.log"
else
    [[ -d $rollback_dir && -f $rollback_dir/manifest.tsv ]] ||
        die 'Backup directory or manifest not found.'
    backup_dir="$(cd -- "$rollback_dir" && pwd -P)"
    log_file="$backup_dir/rollback.log"
fi
exec > >(tee -a "$log_file") 2>&1

backup_one() {
    local target=$1 rel=$2 stored="$backup_dir/files/$2"
    if [[ -e $target || -L $target ]]; then
        mkdir -p -- "$(dirname -- "$stored")"
        cp -a -- "$target" "$stored"
        printf 'PRESENT\t%s\n' "$rel" >>"$backup_dir/manifest.tsv"
        info "BACKUP_CREATED $rel"
    else
        printf 'ABSENT\t%s\n' "$rel" >>"$backup_dir/manifest.tsv"
        info "BACKUP_RECORDED_ABSENT $rel"
    fi
}

atomic_install() {
    local source=$1 target=$2 mode_bits=$3 tmp
    mkdir -p -- "$(dirname -- "$target")"
    tmp="$(mktemp "$(dirname -- "$target")/.k41-dock.XXXXXX")"
    install -m "$mode_bits" -- "$source" "$tmp"
    mv -f -- "$tmp" "$target"
}

if [[ $mode == --rollback ]]; then
    info "ROLLBACK_START backup=$backup_dir"
    while IFS=$'\t' read -r state rel; do
        [[ -n $state && -n $rel ]] || continue
        case "$rel" in
            source/shell.qml) target=$shell_file ;;
            source/modules/k41dock/K41Dock.qml) target=$dock_target ;;
            config/shell.json) target=$config_file ;;
            *) die "Refusing unknown manifest path: $rel" ;;
        esac
        case "$state" in
            PRESENT)
                stored="$backup_dir/files/$rel"
                [[ -f $stored ]] || die "Backup payload missing: $rel"
                mkdir -p -- "$(dirname -- "$target")"
                cp -a -- "$stored" "$target.restore"
                mv -f -- "$target.restore" "$target"
                info "RESTORED $rel"
                ;;
            ABSENT)
                rm -f -- "$target"
                info "REMOVED_NEW_FILE $rel"
                ;;
            *) die "Invalid manifest state: $state" ;;
        esac
    done <"$backup_dir/manifest.tsv"
    rmdir -- "$(dirname -- "$dock_target")" 2>/dev/null || true
    info 'ROLLBACK_COMPLETED; Quickshell was not reloaded.'
    exit 0
fi

[[ -f $dock_source ]] || die "Dock QML source missing from repository: $dock_source"
[[ -f $shell_file ]] || die 'Caelestia shell.qml disappeared during preflight.'
[[ -f $config_file ]] || die 'Caelestia shell.json disappeared during preflight.'

# Validate every input before creating backups or changing runtime files.
python3 - "$shell_file" "$config_file" "$dock_source" <<'PY'
import json, pathlib, sys
shell, config, dock = map(pathlib.Path, sys.argv[1:])
text = shell.read_text(encoding="utf-8")
if text.count("ShellRoot {") != 1:
    raise SystemExit("Preflight failed: expected exactly one ShellRoot { declaration")
if "K41Dock.K41Dock {" in text or 'import "modules/k41dock" as K41Dock' in text:
    raise SystemExit("Preflight failed: K41 dock already appears in shell.qml")
data = json.loads(config.read_text(encoding="utf-8"))
bar = data.get("bar")
if not isinstance(bar, dict) or not isinstance(bar.get("entries"), list):
    raise SystemExit("Preflight failed: shell.json bar.entries is missing or has an unexpected type")
if not all(isinstance(item, dict) and "enabled" in item for item in bar["entries"]):
    raise SystemExit("Preflight failed: bar.entries contains an unsupported entry")
qml = dock.read_text(encoding="utf-8")
if "PanelWindow" not in qml or "Hypr.focusWorkspace" not in qml:
    raise SystemExit("Preflight failed: dock QML does not match the expected implementation")
print("PASS: deployment preflight")
PY

# Back up all mutation targets, including absent paths, before the first write.
backup_one "$shell_file" source/shell.qml
backup_one "$dock_target" source/modules/k41dock/K41Dock.qml
backup_one "$config_file" config/shell.json
printf 'BACKUP_DIRECTORY=%s\n' "$backup_dir" | tee "$backup_dir/backup-location.txt"
info 'BACKUP_PHASE_COMPLETED'

# Stage the QML payload in the target tree.
atomic_install "$dock_source" "$dock_target" 0644
info 'INSTALLED modules/k41dock/K41Dock.qml'

# Preserve the user's current shell.qml and append only the import + component.
python3 - "$shell_file" <<'PY'
import os, pathlib, sys, tempfile
path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
if text.count("ShellRoot {") != 1:
    raise SystemExit("Refusing shell.qml patch: ShellRoot structure changed")
if "K41Dock.K41Dock {" in text or 'import "modules/k41dock" as K41Dock' in text:
    raise SystemExit("Refusing duplicate K41 dock injection")
marker = "ShellRoot {"
text = text.replace(marker, 'import "modules/k41dock" as K41Dock\n\n' + marker, 1)
end = text.rstrip()
if not end.endswith("}"):
    raise SystemExit("Refusing shell.qml patch: final ShellRoot brace not found")
end = end[:-1].rstrip() + "\n\n    // K41 horizontal workspace dock (managed by the project installer).\n    K41Dock.K41Dock {}\n}\n"
fd, temp_name = tempfile.mkstemp(prefix=".k41-shell.", dir=str(path.parent))
try:
    with os.fdopen(fd, "w", encoding="utf-8") as handle:
        handle.write(end)
        handle.flush()
        os.fsync(handle.fileno())
    os.chmod(temp_name, path.stat().st_mode & 0o777)
    os.replace(temp_name, path)
except Exception:
    try: os.unlink(temp_name)
    except FileNotFoundError: pass
    raise
PY
info 'PATCHED shell.qml without replacing its existing content'

# Disable the stock vertical bar entries; all unrelated JSON settings remain intact.
python3 - "$config_file" <<'PY'
import json, os, pathlib, sys, tempfile
path = pathlib.Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
bar = data["bar"]
bar["persistent"] = False
bar["showOnHover"] = False
for entry in bar["entries"]:
    entry["enabled"] = False
fd, temp_name = tempfile.mkstemp(prefix=".k41-shell-json.", dir=str(path.parent))
try:
    with os.fdopen(fd, "w", encoding="utf-8") as handle:
        json.dump(data, handle, indent=2, ensure_ascii=False)
        handle.write("\n")
        handle.flush()
        os.fsync(handle.fileno())
    os.chmod(temp_name, path.stat().st_mode & 0o777)
    os.replace(temp_name, path)
except Exception:
    try: os.unlink(temp_name)
    except FileNotFoundError: pass
    raise
PY
info 'UPDATED runtime shell.json: stock bar entries disabled'

# Post-write integrity checks. Any failure leaves the backup intact for rollback.
python3 - "$shell_file" "$config_file" "$dock_target" <<'PY'
import json, pathlib, sys
shell, config, dock = map(pathlib.Path, sys.argv[1:])
text = shell.read_text(encoding="utf-8")
if text.count('import "modules/k41dock" as K41Dock') != 1 or text.count("K41Dock.K41Dock {}") != 1:
    raise SystemExit("FAIL: shell.qml integration markers are not unique")
data = json.loads(config.read_text(encoding="utf-8"))
if data["bar"]["persistent"] or data["bar"]["showOnHover"] or any(x["enabled"] for x in data["bar"]["entries"]):
    raise SystemExit("FAIL: stock bar configuration was not fully disabled")
qml = dock.read_text(encoding="utf-8")
if "PanelWindow" not in qml or "Hypr.focusWorkspace" not in qml:
    raise SystemExit("FAIL: deployed dock QML integrity check failed")
print("PASS: shell.qml markers, runtime JSON, and deployed QML integrity")
PY

info "IMPLEMENTATION_FILES_CHANGED=source/shell.qml,source/modules/k41dock/K41Dock.qml,config/shell.json"
info "BACKUP_DIRECTORY=$backup_dir"
info 'IMPLEMENTED; Quickshell was not reloaded or restarted.'
info 'Review the backup and implementation.log before reloading the shell.'
