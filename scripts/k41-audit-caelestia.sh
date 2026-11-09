#!/usr/bin/env bash
# Read-only Caelestia/Quickshell audit; creates a privacy-conscious push-ready report.
set -Eeuo pipefail
umask 077

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
info() { printf 'INFO: %s\n' "$*"; }

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd -- "$script_dir/.." && pwd -P)"
report_root="$repo_root/reports/caelestia-audit"
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
exec > >(tee -a "$log_file") 2>&1

status="COMPLETED"
on_exit() {
    local rc=$1
    if (( rc != 0 )); then status="FAILED (exit $rc)"; fi
    {
        printf 'K41 Caelestia Audit\n'
        printf 'Timestamp UTC: %s\n' "$timestamp"
        printf 'Status: %s\n' "$status"
        printf 'Report: reports/caelestia-audit/%s/\n' "$(basename -- "$report_dir")"
        printf 'Files: run.log, summary.txt'
        [[ -f $snapshot_file ]] && printf ', config-snapshot.json'
        printf '\n'
        printf 'Mode: read-only; no configuration or system state changed.\n'
    } >"$summary_file"
    info "Report: reports/caelestia-audit/$(basename -- "$report_dir")/"
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

info 'Audit complete. No configuration, package, service, wallpaper, or shell state was changed.'
info 'Review config-snapshot.json before pushing; personal paths and location fields are redacted.'
