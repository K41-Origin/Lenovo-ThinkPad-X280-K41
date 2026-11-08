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
  'hyprland quickshell xdg-desktop-portal'
  'pipewire pipewire-audio pipewire-pulse wireplumber'
  'makepkg --syncdeps --install'
  'Do you approve this exact AUR recipe'
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
