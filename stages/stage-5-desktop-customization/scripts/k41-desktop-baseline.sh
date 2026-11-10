#!/usr/bin/env bash
# Collect a small, read-only visual baseline for Stage 5 desktop customization.
set -Eeuo pipefail
umask 077

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
info() { printf 'INFO: %s\n' "$*"; }

(( EUID != 0 )) || die 'Jalankan sebagai user desktop biasa, jangan dengan sudo.'
[[ -t 0 ]] || die 'Script harus dijalankan dari terminal interaktif.'

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(git -C "$script_dir" rev-parse --show-toplevel)"
command -v hyprctl >/dev/null 2>&1 || die 'hyprctl tidak ditemukan. Jalankan dari sesi Hyprland.'
[[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] || die 'Sesi Hyprland tidak terdeteksi.'

report_root="$repo_root/reports/stage-5-desktop-customization/desktop-customization/baseline"
timestamp="$(date -u +'%Y%m%dT%H%M%SZ')"
mkdir -p -- "$report_root"
report_dir="$report_root/$timestamp"
suffix=0
while ! mkdir -- "$report_dir" 2>/dev/null; do
  suffix=$((suffix + 1))
  report_dir="$report_root/$timestamp-$suffix"
done
chmod 0700 "$report_dir"
mkdir -m 0700 -- "$report_dir/screenshots"

capture() {
  local output=$1
  shift
  {
    printf 'Command:'
    printf ' %q' "$@"
    printf '\n\n'
    "$@" 2>&1 || printf '\n[exit=%s]\n' "$?"
  } >"$report_dir/$output"
  chmod 0600 "$report_dir/$output"
}

{
  printf '# K41 Desktop Visual Baseline\n\n'
  printf -- '- Captured UTC: %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Repository commit: %s\n' "$(git -C "$repo_root" rev-parse HEAD 2>/dev/null || printf unknown)"
  printf -- '- Hyprland signature present: yes\n'
  printf -- '- Display: %s\n' "${WAYLAND_DISPLAY:-unknown}"
  printf -- '- Screenshot tool: %s\n' "$(command -v grim 2>/dev/null || printf unavailable)"
  printf '\nScreenshots are private evidence. Review before sharing; do not push them to a public repository.\n'
} >"$report_dir/README.md"
chmod 0600 "$report_dir/README.md"

{
  printf '%s\n' '=== Launcher executables ==='
  for app in hyprlauncher wofi rofi fuzzel; do
    if command -v "$app" >/dev/null 2>&1; then
      printf '%-14s %s\n' "$app" "$(command -v "$app")"
    else
      printf '%-14s unavailable\n' "$app"
    fi
  done
  printf '\n%s\n' '=== Launcher-related keybinds ==='
  hyprctl binds 2>&1 | grep -Ei 'launcher|wofi|rofi|fuzzel|dashboard|caelestia|lock' || true
} >"$report_dir/launcher-and-keybinds.txt"
chmod 0600 "$report_dir/launcher-and-keybinds.txt"

{
  printf '%s\n' '=== Wallpaper-related Hyprland options ==='
  hyprctl getoption misc:force_default_wallpaper 2>&1 || true
  printf '\n'
  hyprctl getoption misc:disable_hyprland_logo 2>&1 || true
  printf '\n%s\n' '=== Wallpaper-related processes ==='
  for proc in swww-daemon hyprpaper mpvpaper swaybg; do
    pgrep -a -x "$proc" 2>/dev/null || true
  done
} >"$report_dir/wallpaper-state.txt"
chmod 0600 "$report_dir/wallpaper-state.txt"

capture monitors.txt hyprctl -j monitors
capture config-errors.txt hyprctl configerrors

if command -v grim >/dev/null 2>&1; then
  take_screenshot() {
    local label=$1 instruction=$2 destination answer
    destination="$report_dir/screenshots/$label.png"
    printf '\n%s\n' "$instruction"
    read -r -p 'Tekan Enter untuk mengambil screenshot (atau ketik s untuk skip): ' answer
    if [[ $answer == s || $answer == S ]]; then
      printf 'SKIP: %s\n' "$label" >>"$report_dir/README.md"
      return 0
    fi
    if grim "$destination" 2>"$report_dir/screenshots/$label.stderr" && [[ -s $destination ]]; then
      chmod 0600 "$destination"
      chmod 0600 "$report_dir/screenshots/$label.stderr"
      rm -f -- "$report_dir/screenshots/$label.stderr"
      info "Screenshot tersimpan: screenshots/$label.png"
    else
      rm -f -- "$destination"
      printf 'GAGAL: %s — lihat screenshots/%s.stderr\n' "$label" "$label" >&2
      chmod 0600 "$report_dir/screenshots/$label.stderr" 2>/dev/null || true
    fi
  }
  take_screenshot desktop '1/3: Tutup semua menu dan dialog. Tampilkan desktop kosong seperti kondisi normal.'
  take_screenshot launcher '2/3: Buka launcher menggunakan keybind yang biasa dipakai; biarkan launcher terlihat.'
  take_screenshot dashboard '3/3: Tutup launcher, buka dashboard Caelestia, lalu biarkan dashboard terlihat.'
else
  info 'grim tidak tersedia; screenshot tidak diambil. Laporan diagnostik tetap dibuat.'
fi

cat <<'NOTE'

LOCK SCREEN:
Jangan mencoba mengambil screenshot lock screen dengan grim. Sesi terkunci
biasanya memang melindungi konten layar dari screen capture. Ambil foto layar
menggunakan ponsel bila diperlukan, lalu kirim secara privat di percakapan ini.

PRIVASI:
Jangan push folder laporan ini ke repository publik. Screenshot dapat
menampilkan nama file, notifikasi, akun, atau informasi pribadi.
NOTE

info "Baseline selesai: $report_dir"
info 'Tidak ada konfigurasi, paket, service, atau sesi yang diubah.'
