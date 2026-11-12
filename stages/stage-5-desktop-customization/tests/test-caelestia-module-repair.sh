#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $EUID -eq 0 ]]; then
  printf 'FAIL: Caelestia module repair test must run as a regular user.\n' >&2
  exit 1
fi

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
script="$root/stages/stage-5-desktop-customization/scripts/k41-repair-caelestia-modules.sh"
[[ -f $script ]]

work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
home="$work/home"
config="$work/config"
source_root="$work/upstream"
bin="$work/bin"
mkdir -p "$home" "$config/quickshell/caelestia/modules" \
  "$source_root/modules/dashboard/media" "$bin"
printf 'import QtQuick\nItem {}\n' >"$source_root/modules/dashboard/Dashboard.qml"
printf 'import QtQuick\nItem {}\n' >"$source_root/modules/dashboard/media/Media.qml"
cat >"$bin/pacman" <<'PACMAN'
#!/usr/bin/env bash
[[ ${1:-} == -Qo && -f ${2:-} ]]
PACMAN
chmod +x "$bin/pacman"

run_repair() {
  PATH="$bin:$PATH" HOME="$home" XDG_CONFIG_HOME="$config" \
    K41_CAELESTIA_UPSTREAM_ROOT="$source_root" bash "$script" "$@"
}

# Default mode is dry-run and must not create the destination.
output="$(run_repair)"
grep -q 'DRY-RUN' <<<"$output"
[[ ! -e $config/quickshell/caelestia/modules/dashboard ]]

# Apply restores the upstream directory and nested QML files.
output="$(run_repair --apply)"
grep -q 'RESTORED' <<<"$output"
cmp -s "$source_root/modules/dashboard/Dashboard.qml" \
  "$config/quickshell/caelestia/modules/dashboard/Dashboard.qml"
cmp -s "$source_root/modules/dashboard/media/Media.qml" \
  "$config/quickshell/caelestia/modules/dashboard/media/Media.qml"
run_repair --check >/dev/null

# A second apply must not overwrite an existing local directory.
if run_repair --apply >/dev/null 2>&1; then
  printf 'FAIL: existing destination was overwritten or merged.\n' >&2
  exit 1
fi

# Unowned source must be rejected before any destination is created.
rm -rf -- "$config/quickshell/caelestia/modules/dashboard"
cat >"$bin/pacman" <<'PACMAN'
#!/usr/bin/env bash
exit 1
PACMAN
chmod +x "$bin/pacman"
if run_repair --apply >/dev/null 2>&1; then
  printf 'FAIL: unowned upstream source was accepted.\n' >&2
  exit 1
fi
[[ ! -e $config/quickshell/caelestia/modules/dashboard ]]

# Invalid source containing a symlink must be rejected.
ln -s /etc/passwd "$source_root/modules/dashboard/unsafe.qml"
cat >"$bin/pacman" <<'PACMAN'
#!/usr/bin/env bash
exit 0
PACMAN
chmod +x "$bin/pacman"
if run_repair --apply >/dev/null 2>&1; then
  printf 'FAIL: symlink in upstream source was accepted.\n' >&2
  exit 1
fi
[[ ! -e $config/quickshell/caelestia/modules/dashboard ]]

printf 'PASS: dry-run, atomic restore, nested files, check, overwrite refusal, package ownership, and symlink rejection.\n'
