#!/usr/bin/env bash
# Read-only Stage 5 inventory. Run as the regular desktop user in Hyprland.
set -Eeuo pipefail
umask 077

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
info() { printf 'INFO: %s\n' "$*"; }

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
capture hardware.txt bash -c 'printf "Model: "; cat /sys/class/dmi/id/product_name 2>/dev/null || true; printf "CPU: "; lscpu 2>/dev/null | grep -E "Model name|Architecture|CPU\\(s\\)" || true; printf "\\nGPU: "; lspci -nnk 2>/dev/null | grep -A3 -Ei "VGA|3D|Display" || true'
capture performance-snapshot.txt bash -c 'printf "%s\\n" "--- uptime ---"; uptime; printf "\\n%s\\n" "--- memory ---"; free -h; printf "\\n%s\\n" "--- top CPU processes ---"; ps -eo pid,comm,%cpu,%mem --sort=-%cpu | head -n 16; printf "\\n%s\\n" "--- top memory processes ---"; ps -eo pid,comm,%cpu,%mem --sort=-%mem | head -n 16'
capture packages-focused.txt bash -c 'pacman -Q 2>/dev/null | grep -Ei "^(hyprland|hyprlock|hyprpaper|caelestia|quickshell|qt6|pipewire|wireplumber|mesa|intel-media-driver|vulkan-intel|foot|kitty|wofi|rofi|fuzzel|thunar|gtk|kvantum|ttf-|noto-fonts|adwaita-icon-theme)" || true'
capture processes.txt ps -eo user,pid,comm,args --sort=comm
capture fonts.txt bash -c 'fc-list : family style file | sort -fu; printf "\\n--- Font resolution ---\\n"; for family in Inter "JetBrains Mono" Rubik "CaskaydiaCove Nerd Font" "Noto Sans"; do printf "%s: " "$family"; fc-match "$family" 2>/dev/null | head -n 1; done'
capture icon-themes.txt bash -c 'find "$HOME/.icons" "$HOME/.local/share/icons" /usr/share/icons -mindepth 1 -maxdepth 2 -type d -print 2>/dev/null | sort -u'
capture cursor-settings.txt bash -c 'gsettings get org.gnome.desktop.interface cursor-theme 2>/dev/null || true; gsettings get org.gnome.desktop.interface cursor-size 2>/dev/null || true; printf "XCURSOR_THEME=%s\\nXCURSOR_SIZE=%s\\n" "${XCURSOR_THEME:-}" "${XCURSOR_SIZE:-}"'
capture wallpaper-runtime.txt bash -c '
  printf "Wallpaper-related processes (exact executable names):\\n"
  for proc in swww-daemon hyprpaper mpvpaper swaybg; do pgrep -a -x "$proc" 2>/dev/null || true; done
  printf "\\nWallpaper tool state (when installed):\\n"
  if command -v swww >/dev/null 2>&1; then swww query 2>&1 || true; fi
  if command -v hyprctl >/dev/null 2>&1; then
    printf "\\nHyprland startup/config references:\\n"
    grep -RInE "(^|[[:space:]])(exec|exec-once)[[:space:]]*=.*(wallpaper|swww|hyprpaper|mpvpaper|swaybg)|wallpaper" "$HOME/.config/hypr" "$HOME/.config/caelestia" "$HOME/.config/quickshell" 2>/dev/null | head -n 160 || true
  fi
'
capture hyprland-runtime.txt bash -c '
  if ! command -v hyprctl >/dev/null 2>&1; then echo "hyprctl unavailable"; exit 0; fi
  printf "%s\\n" "--- version ---"; hyprctl version 2>&1 || true
  printf "\\n%s\\n" "--- monitors ---"; hyprctl -j monitors 2>&1 || true
  printf "\\n%s\\n" "--- workspaces ---"; hyprctl -j workspaces 2>&1 || true
  printf "\\n%s\\n" "--- devices ---"; hyprctl -j devices 2>&1 || true
  printf "\\n%s\\n" "--- runtime option values ---"
  for option in general:gaps_in general:gaps_out general:border_size decoration:rounding decoration:active_opacity decoration:inactive_opacity decoration:blur:enabled animations:enabled; do
    printf "\\n[%s]\\n" "$option"; hyprctl getoption "$option" 2>&1 || true
  done
  printf "\\n%s\\n" "--- config errors ---"; hyprctl configerrors 2>&1 || true
  printf "\\n%s\\n" "--- Hyprland process command line ---"
  pgrep -a -x Hyprland 2>/dev/null || true
  printf "\\nHYPRLAND_INSTANCE_SIGNATURE=%s\\n" "${HYPRLAND_INSTANCE_SIGNATURE:-}"
'
capture caelestia-runtime.txt bash -c '
  printf "%s\\n" "--- relevant processes ---"
  for proc in caelestia quickshell qs; do pgrep -a -x "$proc" 2>/dev/null || true; done
  if command -v caelestia >/dev/null 2>&1; then
    printf "\\n--- caelestia version/help ---\\n"
    caelestia --version 2>&1 || true
    caelestia --help 2>&1 | head -n 100 || true
  fi
  if command -v qs >/dev/null 2>&1; then printf "\\n--- Quickshell version ---\\n"; qs --version 2>&1 || true; fi
'
capture launcher-runtime.txt bash -c 'for app in wofi rofi fuzzel; do if command -v "$app" >/dev/null 2>&1; then printf "%s: %s\\n" "$app" "$(command -v "$app")"; fi; done; printf "\\nLauncher processes:\\n"; for proc in wofi rofi fuzzel; do pgrep -a -x "$proc" 2>/dev/null || true; done'
capture gtk-qt-settings.txt bash -c 'printf "GTK_THEME=%s\\nQT_STYLE_OVERRIDE=%s\\nQT_QPA_PLATFORMTHEME=%s\\n" "${GTK_THEME:-}" "${QT_STYLE_OVERRIDE:-}" "${QT_QPA_PLATFORMTHEME:-}"; for f in "$HOME/.config/gtk-3.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini" "$HOME/.config/kdeglobals"; do if [[ -f $f ]]; then printf "\\n--- %s ---\\n" "$f"; sed -n "1,200p" "$f"; fi; done'

# Snapshot only selected configuration trees. Secrets, symlinks, caches,
# histories, databases and files larger than 256 KiB are excluded.
config_roots=(
  "$HOME/.config/hypr" "$HOME/.config/hyprlock"
  "$HOME/.config/caelestia" "$HOME/.config/quickshell"
  "$HOME/.config/foot" "$HOME/.config/kitty"
  "$HOME/.config/wofi" "$HOME/.config/rofi" "$HOME/.config/fuzzel"
  "$HOME/.config/Thunar" "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0"
  "$HOME/.config/qt5ct" "$HOME/.config/qt6ct" "$HOME/.config/Kvantum"
  "$HOME/.config/fontconfig" "$HOME/.config/wallpaper"
  "$HOME/.themes" "$HOME/.local/share/themes" "$HOME/.local/share/icons"
  "$HOME/.local/share/backgrounds" "$HOME/.local/share/caelestia"
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
        *secret*|*credential*|*token*|*password*|*private*|*.key|*.pem|*.p12|*.pfx|*.db|*.sqlite|*history*|*cookie*) continue ;;
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

{
  for root in "${config_roots[@]}"; do
    [[ -d $root ]] || continue
    find "$root" -type l -printf '%p -> %l\n' 2>/dev/null
  done
} >"$report_dir/config-symlinks.txt"
chmod 0600 "$report_dir/config-symlinks.txt"

{
  printf '# Wallpaper and theme asset candidates\n'
  for root in "$HOME/Wallpapers" "$HOME/Pictures/Wallpapers" "$HOME/Pictures" "$HOME/.local/share/backgrounds" /usr/share/backgrounds; do
    [[ -d $root ]] || continue
    find "$root" -maxdepth 3 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.svg' \) -printf '%p (%s bytes)\n' 2>/dev/null
  done
} >"$report_dir/assets.txt"
chmod 0600 "$report_dir/assets.txt"

info "Audit selesai: $report_dir"
info 'Audit bersifat read-only; tidak mengubah konfigurasi, paket, service, atau sesi.'
info 'Snapshot konfigurasi dan inventaris proses dapat memuat informasi privat; tinjau/redaksi sebelum push.'
