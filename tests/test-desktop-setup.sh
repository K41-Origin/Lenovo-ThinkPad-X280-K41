#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
SCRIPT="$ROOT/stages/stage-3-desktop-install/scripts/setup-desktop-x280.sh"
RESOLVER="$ROOT/stages/stage-3-desktop-install/lib/aur-dependency-resolver.sh"
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$*"; }

[[ -f $SCRIPT ]] || fail 'desktop setup script missing'
[[ -f $RESOLVER ]] || fail 'AUR dependency resolver missing'
[[ -f $ROOT/scripts/k41-desktop-validation.sh ]] || fail 'canonical desktop validation entry point missing'
bash -n "$ROOT/scripts/k41-desktop-validation.sh" || fail 'canonical desktop validation entry point syntax invalid'
for token in 'HYPRLAND_INSTANCE_SIGNATURE' 'K41_REPORT_DIR=' 'diagnostics.tsv' 'diagnostics.log' 'validation.log' 'umask 077' '[[ -f "$ROOT/scripts/test-desktop-x280.sh" ]]' '[[ -f "$ROOT/scripts/test-caelestia-x280.sh" ]]'; do
  grep -Fq -- "$token" "$ROOT/scripts/k41-desktop-validation.sh" || fail "canonical desktop validator missing contract: $token"
done
if grep -Eq '(^|[[:space:]])sudo[[:space:]]|systemctl (enable|disable|start|stop)' "$ROOT/scripts/k41-desktop-validation.sh"; then
  fail 'desktop functional validator must not use sudo or mutate system services'
fi
pass 'canonical desktop validation entry point passes syntax and safety-contract checks'
[[ -f $ROOT/scripts/test-desktop-x280.sh ]] || fail 'desktop diagnostic collector missing'
bash -n "$ROOT/scripts/test-desktop-x280.sh" || fail 'desktop diagnostic collector syntax invalid'
grep -Fq 'K41_REPORT_DIR' "$ROOT/scripts/test-desktop-x280.sh" || fail 'desktop collector does not support consolidated report output'
grep -Fq 'coverage-limitations.md' "$ROOT/scripts/test-desktop-x280.sh" || fail 'desktop collector must document automated coverage limits'
if grep -Fq 'manual-checklist.md' "$ROOT/scripts/test-desktop-x280.sh"; then
  fail 'Stage 4 must not request manual hardware/visual acceptance'
fi
pass 'desktop diagnostic collector passes syntax, report, and automated Stage 4 scope checks'
[[ -f $ROOT/scripts/test-caelestia-x280.sh ]] || fail 'Caelestia diagnostic collector missing'
bash -n "$ROOT/scripts/test-caelestia-x280.sh" || fail 'Caelestia diagnostic collector syntax invalid'
grep -Fq 'K41_REPORT_DIR' "$ROOT/scripts/test-caelestia-x280.sh" || fail 'Caelestia collector does not support consolidated report output'
grep -Fq 'coverage-limitations.md' "$ROOT/scripts/test-caelestia-x280.sh" || fail 'Caelestia collector must document automated coverage limits'
if grep -Fq 'manual-checklist.md' "$ROOT/scripts/test-caelestia-x280.sh"; then
  fail 'Caelestia collector must not request manual visual acceptance'
fi
pass 'Caelestia diagnostic collector passes syntax and automated coverage contract'
[[ -f $ROOT/scripts/fix-caelestia-cache-permissions-x280.sh ]] || fail 'Caelestia cache repair script missing'
bash -n "$ROOT/scripts/fix-caelestia-cache-permissions-x280.sh" || fail 'Caelestia cache repair script syntax invalid'
for token in '--apply' 'EUID == 0' '! -L $cache' 'owner != 0:0' 'sudo chown --no-dereference' 'new_owner'; do
  grep -Fq -- "$token" "$ROOT/scripts/fix-caelestia-cache-permissions-x280.sh" || fail "missing cache repair safety guard: $token"
done
if grep -Eq 'chown .*-[Rr]|chmod .*-[Rr]' "$ROOT/scripts/fix-caelestia-cache-permissions-x280.sh"; then
  fail 'cache repair must not perform recursive ownership or permission changes'
fi
pass 'Caelestia cache repair script passes syntax and safety-contract checks'
[[ -f $ROOT/scripts/test-caelestia-permissions-x280.sh ]] || fail 'Caelestia permissions diagnostic collector missing'
bash -n "$ROOT/scripts/test-caelestia-permissions-x280.sh" || fail 'Caelestia permissions diagnostic collector syntax invalid'
grep -Fq 'return 0' "$ROOT/scripts/test-caelestia-permissions-x280.sh" || fail 'permissions collector must continue after optional command failures'
pass 'Caelestia permissions diagnostic collector passes syntax and continuation guard'
bash -n "$SCRIPT" || fail 'desktop setup script syntax invalid'
bash -n "$RESOLVER" || fail 'AUR dependency resolver syntax invalid'
pass 'desktop setup script and resolver pass bash -n'

DESKTOP_ENTRY="$ROOT/stages/stage-3-desktop-install/scripts/k41-install-desktop.sh"
[[ -f $DESKTOP_ENTRY ]] || fail 'canonical desktop entry point missing'
bash -n "$DESKTOP_ENTRY" || fail 'canonical desktop entry point syntax invalid'
# shellcheck disable=SC2016 # Literal contract string checked by grep.
grep -Fq 'exec bash "$ROOT/stages/stage-3-desktop-install/scripts/setup-desktop-x280.sh" "$@"' "$DESKTOP_ENTRY" ||
  fail 'canonical desktop entry point does not delegate to the existing setup implementation'
pass 'canonical desktop entry point passes syntax and delegation checks'

tokens=(
  'pacman -Syu --needed'
  'hyprland xdg-desktop-portal xdg-desktop-portal-hyprland'
  'pipewire pipewire-audio pipewire-pulse wireplumber'
  'packages+=(base-devel git ddcutil libnotify dart-sass gpu-screen-recorder fuzzel)'
  'packages+=(quickshell)'
  'resolve_and_build_aur_dependency'
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
  'aur_metadata_supports_x86_64'
  'makepkg --printsrcinfo'
  'Circular AUR dependency detected'
  'python-materialyoucolor3'
  'makepkg --syncdeps --install'
  'Approve this exact'
)
for token in "${resolver_tokens[@]}"; do
  grep -Fq -- "$token" "$RESOLVER" || fail "missing resolver contract: $token"
done

# Regression guard: recursive dependency traversal must not leave the parent's
# process-substitution stream on stdin for makepkg/pacman interactive prompts.
# shellcheck disable=SC2016
 grep -Fq 'mapfile -t dependencies < <(aur_metadata_dependencies "$aur_dir/.SRCINFO")' "$RESOLVER" ||
  fail 'resolver must materialize dependency metadata before recursive builds'
# shellcheck disable=SC2016
 grep -Fq 'for dependency in "${dependencies[@]}"; do' "$RESOLVER" ||
  fail 'resolver must iterate the materialized dependency array'
grep -Fq 'makepkg --syncdeps --install' "$RESOLVER" ||
  fail 'resolver must retain makepkg dependency installation'
grep -Fq '</dev/tty' "$RESOLVER" ||
  fail 'interactive makepkg build must read confirmations from the controlling TTY'
# shellcheck disable=SC2016
if grep -Fq 'done < <(aur_metadata_dependencies "$aur_dir/.SRCINFO")' "$RESOLVER"; then
  fail 'recursive dependency loop still leaks its process-substitution stdin'
fi

[[ $(grep -Fc '# K41 minimal ThinkPad X280 Hyprland test configuration.' "$SCRIPT") -eq 1 ]] ||
  fail 'desktop script contains duplicated Hyprland configuration blocks'
[[ $(grep -Fc 'AUR package review: %s' "$RESOLVER") -eq 1 ]] ||
  fail 'resolver contains duplicated AUR review blocks'
grep -Fq "printf '%s\\n' '- Log: setup.log'" "$SCRIPT" ||
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
arch = x86_64
depends = libcava>=1.0
makedepends_x86_64 = cmake
depends_aarch64 = ignored-arm-only-dependency
pkgname = fixture-demo
provides = legacy-demo
SRCINFO
# shellcheck source=../stages/stage-3-desktop-install/lib/aur-dependency-resolver.sh
source "$RESOLVER"
[[ $(aur_dependency_name 'libcava>=1.0') == libcava ]] || fail 'versioned dependency normalization failed'
aur_metadata_matches "$fixture_dir/.SRCINFO" fixture-demo || fail 'pkgname metadata matching failed'
aur_metadata_matches "$fixture_dir/.SRCINFO" legacy-demo || fail 'provides metadata matching failed'
aur_metadata_supports_x86_64 "$fixture_dir/.SRCINFO" || fail 'x86_64 metadata support check failed'
[[ $(aur_metadata_dependencies "$fixture_dir/.SRCINFO" | paste -sd ' ' -) == 'cmake libcava>=1.0' ]] ||
  fail 'depends/makedepends extraction failed'
printf 'arch = aarch64\n' >"$fixture_dir/arm-only.SRCINFO"
if aur_metadata_supports_x86_64 "$fixture_dir/arm-only.SRCINFO"; then
  fail 'non-x86_64 AUR package was accepted'
fi

pass 'AUR metadata parsing, provider matching, and dependency normalization pass fixtures'
pass 'desktop setup logging, recursive resolution, reviewed unprivileged builds, overwrite protection, and manual session start are present'
printf '%s\n' 'Desktop setup tests passed.'
