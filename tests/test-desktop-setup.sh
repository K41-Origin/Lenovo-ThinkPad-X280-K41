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
  'packages+=(quickshell)'
  'for package_name in quickshell-git python-materialyoucolor caelestia-cli caelestia-shell; do'
  'check_aur_dependencies() {'
  'makepkg --syncdeps --install'
  'depends = quickshell-git'
  'depends = caelestia-cli'
  'depends = python-materialyoucolor'
  'pkgname = python-materialyoucolor'
  'pkgver = 3\.'
  'Approve this exact'
  'pacman -Q quickshell-git python-materialyoucolor caelestia-cli caelestia-shell'
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
[[ $(grep -Fc '# K41 minimal ThinkPad X280 Hyprland test configuration.' "$SCRIPT") -eq 1 ]] || fail 'desktop script contains duplicated Hyprland configuration blocks'
[[ $(grep -Fc 'AUR package review: %s' "$SCRIPT") -eq 1 ]] || fail 'desktop script contains duplicated AUR build blocks'
grep -Fq "printf '%s\\n' '- Log: setup.log'" "$SCRIPT" || fail 'desktop summary log entry formatting is invalid'
grep -Fq "command -v caelestia" "$SCRIPT" || fail 'Caelestia autostart lacks CLI validation'
if grep -Eq 'systemctl enable.*(gdm|sddm|ly)|getty@tty1.*autologin|AutomaticLogin' "$SCRIPT"; then
  fail 'desktop setup must not enable a display manager or autologin'
fi
pass 'desktop setup logging, dependency preflight, reviewed unprivileged AUR builds, overwrite protection, and manual session start are present'
printf '%s\n' 'Desktop setup tests passed.'
