#!/usr/bin/env bash
# Read-only Stage 5 inventory. Run as the regular desktop user in Hyprland.
set -Eeuo pipefail
umask 077

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
info() { printf 'INFO: %s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

if (( EUID == 0 )); then
  die 'Jalankan sebagai user desktop biasa, jangan dengan sudo.'
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd -- "$script_dir/.." && pwd -P)"
report_root="$repo_root/reports/desktop-customization-audit"
timestamp="$(date -u +'%Y%m%dT%H%M%SZ')"
mkdir -p -- "$report_root"
report_dir="$report_root/$timestamp"
suffix=0
while ! mkdir -- "$report_dir" 2>/dev/null; do
  suffix=$((suffix + 1))
  report_dir="$report_root/$timestamp-$suffix"
done
chmod 0700 "$report_dir"
config_dump="$report_dir/config-snapshot"
mkdir -m 0700 -- "$config_dump"

capture() {
  local name=$1
  shift
  {
    printf 'Command:'
    printf ' %q' "$@"
    printf '\n'
    "$@" 2>&1 || printf '[exit=%s]\n' "$?"
  } >"$report_dir/$name"
  chmod 0600 "$report_dir/$name"
}

capture_shell() {
  local name=$1 command_text=$2
  {
    printf 'Command: %s\n' "$command_text"
    bash -c "$command_text" 2>&1 || printf '[exit=%s]\n' "$?"
  } >"$report_dir/$name"
  chmod 0600 "$report_dir/$name"
}

{
  printf '# K41 Desktop Customization Audit\n\n'
  printf -- '- Captured UTC: %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Repository commit: %s\n' "$(git -C "$repo_root" rev-parse HEAD 2>/dev/null || printf unknown)"
  printf -- '- User: %s\n' "$USER"
  printf -- '- Hostname: %s\n' "$(hostname 2>/dev/null || printf unknown)"
  printf -- '- Session: %s\n' "${XDG_SESSION_TYPE:-unknown}"
  printf -- '- Desktop: %s\n' "${XDG_CURRENT_DESKTOP:-unknown}"
  printf -- '- Wayland display present: %s\n' "${WAYLAND_DISPLAY:+yes}"
  printf '\nReport permissions: 0700 directory / 0600 files. Review and redact before pushing.\n'
} >"$report_dir/summary.md"
chmod 0600 "$report_dir/summary.md"

capture system.txt uname -a
capture os-release.txt cat /etc/os-release
capture hardware.txt bash -c 'printf "Model: "; cat /sys/class/dmi/id/product_name 2>/dev/null || true; printf "CPU: "; lscpu 2>/dev/null | grep -E "Model name|Architecture|CPU\(s\)" || true; printf "\nGPU: "; lspci -nnk 2>/dev/null | grep -A3 -Ei "VGA|3D|Display" || true'
capture packages.txt pacman -Q
capture processes.txt ps -eo user,pid,comm,args --sort=comm
capture fonts.txt fc-list : family style file
capture icon-themes.txt bash -c 'find "$HOME/.icons" /usr/share/icons -mindepth 1 -maxdepth 2 -type d -print 2>/dev/null | sort -u'
capture cursor-settings.txt bash -c 'gsettings get org.gnome.desktop.interface cursor-theme 2>/dev/null || true; gsettings get org.gnome.desktop.interface cursor-size 2>/dev/null || true; printf "XCURSOR_THEME=%s\nXCURSOR_SIZE=%s\n" "${XCURSOR_THEME:-}" "${XCURSOR_SIZE:-}"'
capture wallpaper-processes.txt bash -c 'pgrep -a -f "swww|hyprpaper|mpvpaper|wallpaper" || true'
capture hyprland-runtime.txt bash -c 'if command -v hyprctl >/dev/null 2>&1; then hyprctl version; hyprctl -j monitors; hyprctl -j workspaces; hyprctl -j devices; else echo "hyprctl unavailable"; fi'
capture caelestia-runtime.txt bash -c 'pgrep -a -f "caelestia|quickshell|qs" || true; if command -v caelestia >/dev/null 2>&1; then caelestia --help 2>&1 | head -n 100; fi; if command -v qs >/dev/null 2>&1; then qs --version 2>&1 || true; fi'
capture gtk-qt-settings.txt bash -c 'printf "GTK_THEME=%s\nQT_STYLE_OVERRIDE=%s\nQT_QPA_PLATFORMTHEME=%s\n" "${GTK_THEME:-}" "${QT_STYLE_OVERRIDE:-}" "${QT_QPA_PLATFORMTHEME:-}"; for f in "$HOME/.config/gtk-3.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini" "$HOME/.config/kdeglobals"; do if [[ -f $f ]]; then printf "\n--- %s ---\n" "$f"; sed -n "1,200p" "$f"; fi; done'

# Copy relevant user configuration text for review. No symlinks, caches, sockets,
# browser profiles, histories, key material, or files over 256 KiB are copied.
config_roots=(
  "$HOME/.config/hypr"
  "$HOME/.config/caelestia"
  "$HOME/.config/quickshell"
  "$HOME/.config/foot"
  "$HOME/.config/gtk-3.0"
  "$HOME/.config/gtk-4.0"
  "$HOME/.config/qt5ct"
  "$HOME/.config/qt6ct"
  "$HOME/.config/Kvantum"
  "$HOME/.config/fontconfig"
  "$HOME/.config/wallpaper"
  "$HOME/.local/share/caelestia"
)
{
  printf '# Configuration inventory and snapshots\n'
  for root in "${config_roots[@]}"; do
    [[ -d $root ]] || continue
    printf '\n## %s\n' "$root"
    while IFS= read -r -d '' file; do
      rel="${file#"$HOME"/}"
      base="${file##*/}"
      case "$base" in
        *secret*|*credential*|*token*|*password*|*private*|*.key|*.pem|*.p12|*.pfx|*.db|*.sqlite|*history*) continue ;;
      esac
      size="$(stat -c '%s' -- "$file" 2>/dev/null || printf 999999999)"
      if (( size > 262144 )); then
        printf '\n[SKIPPED: larger than 256 KiB] %s (%s bytes)\n' "$rel" "$size"
        continue
      fi
      destination="$config_dump/$rel"
      mkdir -p -- "$(dirname -- "$destination")"
      if cp -- "$file" "$destination"; then
        chmod 0600 "$destination"
        printf '\n--- FILE: %s (%s bytes) ---\n' "$rel" "$size"
        cat -- "$file"
        printf '\n--- END FILE ---\n'
      fi
    done < <(find "$root" -type f -not -xtype l -print0 2>/dev/null | sort -z)
  done
} >"$report_dir/config-files.txt"
chmod 0600 "$report_dir/config-files.txt"

# Capture symlink targets separately without following them.
{
  for root in "${config_roots[@]}"; do
    [[ -d $root ]] || continue
    find "$root" -type l -printf '%p -> %l\n' 2>/dev/null
  done
} >"$report_dir/config-symlinks.txt"
chmod 0600 "$report_dir/config-symlinks.txt"

{
  printf '# Wallpaper and theme asset candidates\n'
  for root in "$HOME/Wallpapers" "$HOME/Pictures" "$HOME/.local/share/backgrounds" /usr/share/backgrounds; do
    [[ -d $root ]] || continue
    find "$root" -maxdepth 3 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.svg' \) -printf '%p (%s bytes)\n' 2>/dev/null
  done
} >"$report_dir/assets.txt"
chmod 0600 "$report_dir/assets.txt"

info "Audit selesai: $report_dir"
info 'Audit bersifat read-only; tidak mengubah konfigurasi, paket, service, atau sesi.'
info 'Periksa seluruh report untuk data privat sebelum melakukan push.'
