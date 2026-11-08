#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
SCRIPT="$ROOT/scripts/setup-desktop-x280.sh"
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$*"; }
[[ -f $SCRIPT ]] || fail 'desktop setup script missing'
bash -n "$SCRIPT" || fail 'desktop setup script syntax invalid'
pass 'desktop setup script passes bash -n'

tokens=(
  'pacman -Syu --needed'
  'hyprland xdg-desktop-portal xdg-desktop-portal-hyprland'
  'pipewire pipewire-audio pipewire-pulse wireplumber'
  'packages+=(base-devel git ddcutil libnotify dart-sass gpu-screen-recorder fuzzel)'
  'for package_name in quickshell-git caelestia-cli caelestia-shell; do'
  'makepkg --syncdeps --install'
  'Approve this exact $package_name recipe and dependency metadata'
  'pacman -Q quickshell-git caelestia-cli caelestia-shell'
  'exec-once = caelestia shell -d'
  'Build the AUR dependency chain explicitly'
  'refusing to overwrite it'
  'No graphical session was started'
  'org.freedesktop.impl.portal.ScreenCast=hyprland'
  'report_root='
  'tee -a'
  'trap on_setup_exit EXIT'
  'on_setup_error() {'
  'packages-before.txt'
  'packages-after.txt'
  'summary.md'
)
for token in "${tokens[@]}"; do
  grep -Fq -- "$token" "$SCRIPT" || fail "missing desktop safety/implementation contract: $token"
done
if grep -Eq 'systemctl enable.*(gdm|sddm|ly)|getty@tty1.*autologin|AutomaticLogin' "$SCRIPT"; then
  fail 'desktop setup must not enable a display manager or autologin'
fi
pass 'desktop setup logging, package snapshots, reviewed unprivileged AUR build, overwrite protection, and manual session start are present'
printf '%s\n' 'Desktop setup tests passed.'
