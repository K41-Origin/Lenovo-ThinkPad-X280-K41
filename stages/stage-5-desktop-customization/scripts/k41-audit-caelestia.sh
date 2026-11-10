#!/usr/bin/env bash
# Read-only Caelestia/Quickshell audit; creates a privacy-conscious push-ready report.
set -Eeuo pipefail
umask 077

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
info() { printf 'INFO: %s\n' "$*"; }

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(git -C "$script_dir" rev-parse --show-toplevel)"
report_root="$repo_root/reports/stage-5-desktop-customization/caelestia-audit"
timestamp="$(date -u +'%Y%m%dT%H%M%SZ')"
mkdir -p -- "$report_root"
report_dir="$report_root/$timestamp"
suffix=0
while ! mkdir -- "$report_dir" 2>/dev/null; do
    suffix=$((suffix + 1))
    report_dir="$report_root/$timestamp-$suffix"
done
log_file="$report_dir/run.log"
summary_file="$report_dir/summary.txt"
snapshot_file="$report_dir/config-snapshot.json"
monitor_file="$report_dir/monitor-runtime.json"
source_file="$report_dir/source-inventory.txt"
exec > >(tee -a "$log_file") 2>&1

status="COMPLETED"
on_exit() {
    local rc=$1
    if (( rc != 0 )); then status="FAILED (exit $rc)"; fi
    {
        printf 'K41 Caelestia Audit\n'
        printf 'Timestamp UTC: %s\n' "$timestamp"
        printf 'Status: %s\n' "$status"
        printf 'Report: reports/stage-5-desktop-customization/caelestia-audit/%s/\n' "$(basename -- "$report_dir")"
        printf 'Files: run.log, summary.txt'
        [[ -f $snapshot_file ]] && printf ', config-snapshot.json'
        printf '\n'
        printf 'Mode: read-only; no configuration or system state changed.\n'
    } >"$summary_file"
    info "Report: reports/stage-5-desktop-customization/caelestia-audit/$(basename -- "$report_dir")/"
}
trap 'on_exit $?' EXIT

[[ $EUID -ne 0 ]] || die 'Run as the regular desktop user; do not use sudo.'
command -v python3 >/dev/null 2>&1 || die 'python3 is required.'
command -v tee >/dev/null 2>&1 || die 'tee is required.'
config_root="${XDG_CONFIG_HOME:-$HOME/.config}"
state_root="${XDG_STATE_HOME:-$HOME/.local/state}"
info "K41 Caelestia audit started (UTC $timestamp)"
info "This audit is read-only. It does not reload or restart the shell."

printf '\n## Runtime and package versions\n'
for cmd in caelestia qs quickshell hyprctl pacman fc-match; do
    if command -v "$cmd" >/dev/null 2>&1; then
        printf '%s: %s\n' "$cmd" "$(command -v "$cmd")"
    else
        printf '%s: NOT_FOUND\n' "$cmd"
    fi
done
if command -v caelestia >/dev/null 2>&1; then
    printf '\n[caelestia version]\n'
    caelestia -v 2>&1 || true
fi
if command -v pacman >/dev/null 2>&1; then
    printf '\n[pacman package versions]\n'
    pacman -Q caelestia-shell caelestia-cli quickshell-git quickshell 2>&1 || true
fi

printf '\n## Font resolution\n'
if command -v fc-match >/dev/null 2>&1; then
    for font in 'Rubik' 'CaskaydiaCove Nerd Font' 'CaskaydiaCove NF' 'Material Symbols Rounded' 'Noto Sans'; do
        printf '%s => ' "$font"
        fc-match -f '%{family} | %{style}\n' "$font" 2>&1 | head -n 1
    done
fi

printf '\n## Caelestia CLI scheme interface\n'
if command -v caelestia >/dev/null 2>&1; then
    printf '[scheme list]\n'
    timeout 8s caelestia scheme list 2>&1 || true
    printf '[scheme get]\n'
    timeout 8s caelestia scheme get 2>&1 || true
    printf '[scheme set help]\n'
    timeout 8s caelestia scheme set -h 2>&1 || true
fi

printf '\n## Relevant configuration files\n'
for file in \
    "$config_root/caelestia/shell.json" \
    "$config_root/caelestia/shell-tokens.json" \
    "$state_root/caelestia/scheme.json" \
    "$state_root/caelestia/wallpaper/path.txt"; do
    if [[ -f $file ]]; then
        printf 'PRESENT %s (%s bytes)\n' "${file#"$HOME"/}" "$(stat -c '%s' "$file" 2>/dev/null || printf '?')"
    else
        printf 'ABSENT  %s\n' "${file#"$HOME"/}"
    fi
done

# Export only relevant shell.json sections. Personal paths and weather location
# are redacted; unrelated configuration sections are deliberately omitted.
python3 - "$config_root/caelestia/shell.json" "$config_root/caelestia/shell-tokens.json" "$state_root/caelestia/scheme.json" "$snapshot_file" "$HOME" <<'PY'
import json
import pathlib
import sys

shell_path, tokens_path, scheme_path, output_path, home = map(pathlib.Path, sys.argv[1:])
snapshot = {"privacy": "Personal paths and weather location are redacted; unrelated shell.json sections omitted."}

def load(path, label):
    if not path.is_file():
        snapshot[label] = {"status": "absent"}
        return None
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        snapshot[label] = {"status": "invalid-json", "error": type(exc).__name__}
        return None
    snapshot[label] = {"status": "valid-json"}
    return value

def scrub(value, key=""):
    if isinstance(value, dict):
        out = {}
        for k, v in value.items():
            if k.lower() in {"weatherlocation", "wallpaperdir", "lyricsdir", "sessiongif", "mediagif", "nonotifspic", "locknonotifspic"}:
                out[k] = "<redacted>"
            else:
                out[k] = scrub(v, k)
        return out
    if isinstance(value, list):
        return [scrub(item, key) for item in value]
    if isinstance(value, str):
        return value.replace(str(home), "~")
    return value

shell = load(shell_path, "shell_json")
if isinstance(shell, dict):
    selected = ("enabled", "appearance", "background", "bar", "border", "dashboard",
                "launcher", "lock", "notifs", "osd", "services", "sidebar", "utilities")
    snapshot["shell_json"]["top_level_keys"] = sorted(shell.keys())
    snapshot["shell_json"]["selected_settings"] = {
        key: scrub(shell[key], key) for key in selected if key in shell
    }

tokens = load(tokens_path, "shell_tokens_json")
if isinstance(tokens, dict):
    snapshot["shell_tokens_json"]["top_level_keys"] = sorted(tokens.keys())
    snapshot["shell_tokens_json"]["content_omitted"] = True

scheme = load(scheme_path, "scheme_state")
if isinstance(scheme, dict):
    safe = {}
    for key in ("name", "mode", "variant", "flavour", "contrast"):
        if key in scheme:
            safe[key] = scrub(scheme[key], key)
    colors = scheme.get("colours", scheme.get("colors"))
    if isinstance(colors, dict):
        safe["colors"] = scrub(colors)
    snapshot["scheme_state"]["selected_fields"] = safe

output_path.write_text(json.dumps(snapshot, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
PY

printf '\n## Running Caelestia/Quickshell processes\n'
if command -v pgrep >/dev/null 2>&1; then
    pgrep -a -u "$UID" -f '(^|/)(qs|quickshell)( |$).*caelestia|caelestia.*shell' 2>/dev/null \
        | sed "s|$HOME|~|g" || printf 'No matching process found (or process details unavailable).\n'
else
    printf 'pgrep unavailable; skipped.\n'
fi

printf '\n## Configuration validation\n'
python3 - "$config_root/caelestia/shell.json" "$config_root/caelestia/shell-tokens.json" <<'PY'
import json
import pathlib
import sys
for raw in sys.argv[1:]:
    path = pathlib.Path(raw)
    if not path.exists():
        print(f"SKIP {path.name}: absent")
        continue
    try:
        json.loads(path.read_text(encoding="utf-8"))
        print(f"PASS {path.name}: valid JSON")
    except Exception as exc:
        print(f"FAIL {path.name}: {type(exc).__name__}: {exc}")
PY


printf '\n## Monitor and Hyprland runtime\n'
if command -v hyprctl >/dev/null 2>&1; then
    if timeout 8s hyprctl -j monitors >"$report_dir/monitors.raw.json" 2>/dev/null; then
        python3 - "$report_dir/monitors.raw.json" "$monitor_file" <<'PY'
import json, pathlib, sys
src, dst = map(pathlib.Path, sys.argv[1:])
try:
    raw = json.loads(src.read_text(encoding="utf-8"))
    fields = ("name", "width", "height", "refreshRate", "scale", "transform",
              "focused", "disabled", "dpmsStatus", "availableModes")
    monitors = [{k: m[k] for k in fields if k in m} for m in raw if isinstance(m, dict)]
    dst.write_text(json.dumps({"status": "ok", "monitors": monitors}, indent=2) + "\n")
    print(f"PASS monitor inventory: {len(monitors)} monitor(s)")
except Exception as exc:
    dst.write_text(json.dumps({"status": "invalid-response", "error": type(exc).__name__}) + "\n")
    print(f"FAIL monitor inventory: {type(exc).__name__}")
PY
        rm -f -- "$report_dir/monitors.raw.json"
    else
        printf '{"status":"unavailable"}\n' >"$monitor_file"
        printf 'WARN hyprctl monitor query unavailable (timeout or inactive session).\n'
    fi
    printf '[Hyprland config errors]\n'
    config_errors="$(timeout 8s hyprctl configerrors 2>&1 || true)"
    config_errors="$(printf '%s' "$config_errors" | sed "s|$HOME|~|g")"
    if [[ -z $config_errors ]]; then
        printf 'No output returned.\n'
    else
        printf '%s\n' "$config_errors" | head -n 30
    fi
else
    printf 'hyprctl unavailable; skipped.\n'
fi

printf '\n## Caelestia Quickshell source inventory\n'
: >"$source_file"
for candidate in \
    "$config_root/quickshell/caelestia" \
    "$config_root/Quickshell/caelestia" \
    "$HOME/.config/quickshell/caelestia" \
    /usr/share/caelestia \
    /usr/lib/caelestia; do
    [[ -d $candidate ]] || continue
    {
        printf 'SOURCE_ROOT %s\n' "${candidate#"$HOME"/}"
        for relative in shell.qml modules/bar/Bar.qml modules/bar/BarWrapper.qml \
            modules/bar/components/workspaces/Workspaces.qml; do
            if [[ -f $candidate/$relative ]]; then
                printf '  PRESENT %s\n' "$relative"
            else
                printf '  ABSENT  %s\n' "$relative"
            fi
        done
        if command -v git >/dev/null 2>&1 && git -C "$candidate" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
            printf '  GIT_COMMIT %s\n' "$(git -C "$candidate" rev-parse --short HEAD 2>/dev/null || printf unknown)"
            printf '  GIT_DIRTY %s\n' "$(if [[ -n $(git -C "$candidate" status --porcelain 2>/dev/null) ]]; then printf yes; else printf no; fi)"
        fi
    } | tee -a "$source_file"
done
if [[ ! -s $source_file ]]; then
    printf 'No common Caelestia source directory found.\n' | tee -a "$source_file"
fi

printf '\n## Workspace runtime inventory\n'
if command -v hyprctl >/dev/null 2>&1; then
    for query in activeworkspace workspaces; do
        printf '[%s]\n' "$query"
        timeout 8s hyprctl -j "$query" 2>/dev/null | python3 -c '
import json,sys
try:
    data=json.load(sys.stdin)
    if isinstance(data,dict):
        keys=("id","name","monitor","windows","hasfullscreen")
        print(json.dumps({k:data[k] for k in keys if k in data}, ensure_ascii=False))
    elif isinstance(data,list):
        print(json.dumps([{k:x[k] for k in ("id","name","monitor","windows","hasfullscreen") if k in x} for x in data if isinstance(x,dict)], ensure_ascii=False))
    else: print("Unexpected JSON type")
except Exception: print("Unavailable or invalid response")
' || printf 'Unavailable.\n'
    done
fi

info 'Audit complete. No configuration, package, service, wallpaper, or shell state was changed.'
info 'Review config-snapshot.json before pushing; personal paths and location fields are redacted.'
