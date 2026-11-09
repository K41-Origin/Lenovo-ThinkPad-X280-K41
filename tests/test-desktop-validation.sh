#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
SCRIPT="$ROOT/scripts/k41-desktop-validation.sh"
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$*"; }

[[ -f $SCRIPT ]] || fail 'canonical desktop validator missing'
bash -n "$SCRIPT" || fail 'desktop validator syntax invalid'
for token in 'HYPRLAND_INSTANCE_SIGNATURE' 'WAYLAND_DISPLAY' 'umask 077' 'checks.tsv' 'validation.log' 'hyprctl configerrors' "grep -q '[^[:space:]]' \"\$tmp/hypr-config-errors\"" 'hyprctl monitors' 'caelestia shell -s' 'qs -c caelestia log' 'wpctl status' 'Sinks:' 'Sources:' 'permission denied' 'nmcli -t' 'rfkill list' '/sys/class/thermal/thermal_zone*' 'energy_full_design' 'journalctl --user' 'systemctl --failed' 'systemctl --user --failed' 'free -b' 'Kernel panic' 'Kernel driver in use: i915' '/sys/class/backlight/*' 'K41_REPORT_DIR=' 'caelestia_running' 'PASS_WITH_WARNINGS' 'fail_count' 'Actionable runtime/QML error signature' 'recognized informational platform/driver messages detected' 'diagnostics.tsv' 'diagnostics.log' 'CPU vulnerability mitigations' 'PCI devices and bound drivers' 'Regulatory database package ownership' 'Bluetooth service properties' 'Thermal hardware monitor inventory' 'ThinkPad ACPI interface' 'Relevant installed package versions'; do
  grep -Fq -- "$token" "$SCRIPT" || fail "validator missing expected health check: $token"
done
if grep -Eq '(^|[[:space:]])sudo[[:space:]]|pacman -S|systemctl (enable|disable|start|stop)|mkfs\.|cryptsetup luksFormat|wipefs|parted' "$SCRIPT"; then
  fail 'desktop validator must not install packages, mutate services, or perform storage operations'
fi
grep -Fq 'cannot prove that the panel' "$SCRIPT" || fail 'validator must state the limits of log-based acceptance'
grep -Fq 'chmod 0700 "$run_dir"' "$SCRIPT" || fail 'report directory must be private'
grep -Fq 'chmod 0600 "$log" "$checks"' "$SCRIPT" || fail 'report files must be private'
diag_line="$(grep -n '^diagnostics="$run_dir/diagnostics.tsv"pass 'desktop validator passes syntax and safety-contract checks'
 "$SCRIPT" | cut -d: -f1)"
chmod_line="$(grep -n '^chmod 0600 "$run_dir"/\\*.txt "$log" "$checks" "$diagnostics" "$diagnostics_log"pass 'desktop validator passes syntax and safety-contract checks'
 "$SCRIPT" | cut -d: -f1)"
[[ -n $diag_line && -n $chmod_line ]] || fail 'diagnostic report initialization/permission block missing'
(( diag_line < chmod_line )) || fail 'diagnostic permissions are applied before initialization'
pass 'desktop validator passes syntax and safety-contract checks'
