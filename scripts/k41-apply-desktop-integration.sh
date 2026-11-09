#!/usr/bin/env bash
# Apply K41 GTK3/GTK4, Thunar, Foot, icon and Qt theme integration.
set -Eeuo pipefail
umask 077

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
info() { printf 'INFO: %s\n' "$*"; }

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd -- "$script_dir/.." && pwd -P)"
config_root="${XDG_CONFIG_HOME:-$HOME/.config}"
state_root="${XDG_STATE_HOME:-$HOME/.local/state}"
cli_profile="$repo_root/config/desktop-customization/caelestia-cli.json"
gtk_settings="$repo_root/config/desktop-customization/gtk-settings.ini"
gtk3_css="$repo_root/config/desktop-customization/gtk3.css"
gtk4_css="$repo_root/config/desktop-customization/gtk4.css"
thunar_css="$repo_root/config/desktop-customization/thunar.css"
foot_profile="$repo_root/config/desktop-customization/foot.ini"
cli_target="$config_root/caelestia/cli.json"
gtk3_dir="$config_root/gtk-3.0"
gtk4_dir="$config_root/gtk-4.0"
foot_dir="$config_root/foot"
backup_root="$state_root/k41/desktop-integration/backups"
timestamp="$(date -u +'%Y%m%dT%H%M%SZ')"

[[ $EUID -ne 0 ]] || die 'Run as the regular desktop user; do not use sudo.'
for cmd in python3 install cp mkdir date timeout chmod; do
    command -v "$cmd" >/dev/null 2>&1 || die "Required command not found: $cmd"
done
command -v caelestia >/dev/null 2>&1 || die 'Caelestia CLI is required.'
command -v foot >/dev/null 2>&1 || die 'Foot is not installed.'

for source in "$cli_profile" "$gtk_settings" "$gtk3_css" "$gtk4_css" "$thunar_css" "$foot_profile"; do
    [[ -r $source ]] || die "Missing profile source: $source"
done
[[ -d $config_root/caelestia ]] || die 'Caelestia configuration directory is missing.'

if [[ ${1:-} == "--rollback" ]]; then
    [[ $# -eq 2 && -d $2 ]] || die 'Usage: scripts/k41-apply-desktop-integration.sh --rollback BACKUP_DIRECTORY'
    backup_dir=$2
    for relative in "caelestia/cli.json" "gtk-3.0/settings.ini" "gtk-3.0/gtk.css" "gtk-3.0/thunar.css" "gtk-4.0/settings.ini" "gtk-4.0/gtk.css" "foot/foot.ini"; do
        source="$backup_dir/$relative"
        target="$config_root/$relative"
        if [[ -f $source ]]; then
            mkdir -p -- "$(dirname -- "$target")"
            cp -a -- "$source" "$target"
        fi
    done
    info 'Restored all configuration files that existed before application.'
    info 'If a target did not exist before application, it is left in place; remove that new file manually if a full absence rollback is required.'
    timeout 10s caelestia shell -r -d
    exit 0
fi
[[ $# -eq 0 ]] || die 'Unknown argument.'

python3 - "$cli_profile" <<'PY'
import json, pathlib, sys
value = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
if not isinstance(value, dict) or not isinstance(value.get("theme"), dict):
    raise SystemExit("Invalid Caelestia CLI profile structure")
PY

mkdir -p -- "$backup_root"
backup_dir="$backup_root/$timestamp"
suffix=0
while ! mkdir -- "$backup_dir" 2>/dev/null; do
    suffix=$((suffix + 1))
    backup_dir="$backup_root/$timestamp-$suffix"
done
chmod 0700 "$backup_dir"

backup_file() {
    local target="$1" relative="$2"
    if [[ -e $target ]]; then
        mkdir -p -- "$backup_dir/$(dirname -- "$relative")"
        cp -a -- "$target" "$backup_dir/$relative"
    fi
}
backup_file "$cli_target" "caelestia/cli.json"
backup_file "$gtk3_dir/settings.ini" "gtk-3.0/settings.ini"
backup_file "$gtk3_dir/gtk.css" "gtk-3.0/gtk.css"
backup_file "$gtk3_dir/thunar.css" "gtk-3.0/thunar.css"
backup_file "$gtk4_dir/settings.ini" "gtk-4.0/settings.ini"
backup_file "$gtk4_dir/gtk.css" "gtk-4.0/gtk.css"
backup_file "$foot_dir/foot.ini" "foot/foot.ini"

printf 'Apply K41 Graphite GTK3/GTK4, Thunar, Foot and icon theme integration? [y/N] '
IFS= read -r answer
[[ $answer =~ ^[Yy]([Ee][Ss])?$ ]] || die 'Cancelled by user.'

python3 - "$cli_profile" "$cli_target" <<'PY'
import json, os, pathlib, stat, sys, tempfile
profile_path, target_path = map(pathlib.Path, sys.argv[1:])
profile = json.loads(profile_path.read_text(encoding="utf-8"))
target = json.loads(target_path.read_text(encoding="utf-8")) if target_path.exists() else {}
if not isinstance(target, dict):
    raise SystemExit("Existing cli.json is not a JSON object; refusing to overwrite it.")
def merge(dst, src):
    for key, value in src.items():
        if isinstance(value, dict) and isinstance(dst.get(key), dict):
            merge(dst[key], value)
        else:
            dst[key] = value
merge(target, profile)
target_path.parent.mkdir(parents=True, exist_ok=True)
fd, temporary = tempfile.mkstemp(prefix=".k41-cli-", dir=target_path.parent)
try:
    with os.fdopen(fd, "w", encoding="utf-8") as stream:
        json.dump(target, stream, indent=2, ensure_ascii=False)
        stream.write("\n")
    os.chmod(temporary, stat.S_IMODE(target_path.stat().st_mode) if target_path.exists() else 0o600)
    os.replace(temporary, target_path)
except BaseException:
    try: os.unlink(temporary)
    except FileNotFoundError: pass
    raise
print("PASS: Caelestia CLI GTK/Qt/Foot/Fuzzel and Adwaita icon theme preferences merged.")
PY

timeout 15s caelestia scheme set -n caelestia -m dark -v monochrome
install -Dm0644 "$gtk_settings" "$gtk3_dir/settings.ini"
install -Dm0644 "$gtk3_css" "$gtk3_dir/gtk.css"
install -Dm0644 "$thunar_css" "$gtk3_dir/thunar.css"
install -Dm0644 "$gtk_settings" "$gtk4_dir/settings.ini"
install -Dm0644 "$gtk4_css" "$gtk4_dir/gtk.css"
install -Dm0644 "$foot_profile" "$foot_dir/foot.ini"
timeout 10s caelestia shell -r -d

printf 'K41 Desktop Integration\nTimestamp UTC: %s\nStatus: SUCCESS (commands returned successfully)\nBackup: %s\n' "$timestamp" "$backup_dir"
info 'Applied: GTK3/GTK4 dark preferences, Thunar Graphite CSS, Foot palette/font/cursor, Caelestia GTK/Qt/Fuzzel/Hypr theme generation and Adwaita icon preference.'
info 'Restart existing GTK/Foot applications to reload their settings.'
info "Rollback: bash scripts/k41-apply-desktop-integration.sh --rollback '$backup_dir'"
