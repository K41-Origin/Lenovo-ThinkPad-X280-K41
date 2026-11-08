#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
SCRIPT="$ROOT/scripts/setup-desktop-x280.sh"
RESOLVER="$ROOT/lib/aur-dependency-resolver.sh"
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$*"; }

[[ -f $SCRIPT ]] || fail 'desktop setup script missing'
[[ -f $RESOLVER ]] || fail 'AUR dependency resolver missing'
bash -n "$SCRIPT" || fail 'desktop setup script syntax invalid'
bash -n "$RESOLVER" || fail 'AUR dependency resolver syntax invalid'
pass 'desktop setup script and resolver pass bash -n'

tokens=(
  'pacman -Syu --needed'
  'hyprland xdg-desktop-portal xdg-desktop-portal-hyprland'
  'pipewire pipewire-audio pipewire-pulse wireplumber'
  'packages+=(base-devel git ddcutil libnotify dart-sass gpu-screen-recorder fuzzel)'
  'packages+=(quickshell)'
  'resolve_and_build_aur_dependency "$package_name"'
  'makepkg --syncdeps --install'
  'exec-once = caelestia shell -d'
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

resolver_tokens=(
  'aur_metadata_dependencies'
  'Circular AUR dependency detected'
  'python-materialyoucolor3'
  'makepkg --syncdeps --install'
  'Approve this exact'
)
for token in "${resolver_tokens[@]}"; do
  grep -Fq -- "$token" "$RESOLVER" || fail "missing resolver contract: $token"
done

[[ $(grep -Fc '# K41 minimal ThinkPad X280 Hyprland test configuration.' "$SCRIPT") -eq 1 ]] ||
  fail 'desktop script contains duplicated Hyprland configuration blocks'
[[ $(grep -Fc 'AUR package review: %s' "$RESOLVER") -eq 1 ]] ||
  fail 'resolver contains duplicated AUR review blocks'
grep -Fq "printf '%s\\\n' '- Log: setup.log'" "$SCRIPT" ||
  fail 'desktop summary log entry formatting is invalid'
grep -Fq 'command -v caelestia' "$SCRIPT" || fail 'Caelestia autostart lacks CLI validation'
if grep -Eq 'systemctl enable.*(gdm|sddm|ly)|getty@tty1.*autologin|AutomaticLogin' "$SCRIPT"; then
  fail 'desktop setup must not enable a display manager or autologin'
fi

fixture_dir=$(mktemp -d)
trap 'rm -rf "$fixture_dir"' EXIT
cat >"$fixture_dir/.SRCINFO" <<'SRCINFO'
pkgbase = fixture-demo
pkgver = 1.0
pkgrel = 1
depends = libcava>=1.0
makedepends_x86_64 = cmake
pkgname = fixture-demo
provides = legacy-demo
SRCINFO
# shellcheck source=../lib/aur-dependency-resolver.sh
source "$RESOLVER"
[[ $(aur_dependency_name 'libcava>=1.0') == libcava ]] || fail 'versioned dependency normalization failed'
aur_metadata_matches "$fixture_dir/.SRCINFO" fixture-demo || fail 'pkgname metadata matching failed'
aur_metadata_matches "$fixture_dir/.SRCINFO" legacy-demo || fail 'provides metadata matching failed'
[[ $(aur_metadata_dependencies "$fixture_dir/.SRCINFO" | paste -sd ' ' -) == 'cmake libcava>=1.0' ]] ||
  fail 'depends/makedepends extraction failed'

pass 'AUR metadata parsing, provider matching, and dependency normalization pass fixtures'
pass 'desktop setup logging, recursive resolution, reviewed unprivileged builds, overwrite protection, and manual session start are present'
printf '%s\n' 'Desktop setup tests passed.'
