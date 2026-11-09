#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
SCRIPT="$ROOT/scripts/k41-desktop-validation.sh"
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$*"; }

[[ -f $SCRIPT ]] || fail 'canonical desktop validator missing'
bash -n "$SCRIPT" || fail 'desktop validator syntax invalid'
for token in 'HYPRLAND_INSTANCE_SIGNATURE' 'WAYLAND_DISPLAY' 'umask 077' 'checks.tsv' 'validation.log' 'hyprctl configerrors' 'hyprctl monitors' 'caelestia shell -s' 'qs -c caelestia log' 'wpctl status' 'nmcli -t' 'rfkill list' '/sys/class/thermal/thermal_zone*' 'energy_full_design' 'journalctl --user' 'systemctl --failed' 'systemctl --user --failed' 'free -b' 'Kernel panic' 'K41_REPORT_DIR=' 'fail_count'; do
  grep -Fq -- "$token" "$SCRIPT" || fail "validator missing expected health check: $token"
done
if grep -Eq '(^|[[:space:]])sudo[[:space:]]|pacman -S|systemctl (enable|disable|start|stop)|mkfs\.|cryptsetup luksFormat|wipefs|parted' "$SCRIPT"; then
  fail 'desktop validator must not install packages, mutate services, or perform storage operations'
fi
grep -Fq 'cannot prove that the panel' "$SCRIPT" || fail 'validator must state the limits of log-based acceptance'
grep -Fq 'chmod 0700 "$run_dir"' "$SCRIPT" || fail 'report directory must be private'
grep -Fq 'chmod 0600 "$log" "$checks"' "$SCRIPT" || fail 'report files must be private'
pass 'desktop validator passes syntax and safety-contract checks'
