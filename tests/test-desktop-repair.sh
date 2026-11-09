#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
VALIDATOR="$ROOT/scripts/k41-desktop-validation.sh"
REPAIR="$ROOT/scripts/k41-desktop-repair.sh"
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$*"; }

[[ -f $VALIDATOR ]] || fail 'desktop validator missing'
[[ -f $REPAIR ]] || fail 'desktop repair script missing'
bash -n "$VALIDATOR" || fail 'desktop validator syntax invalid'
bash -n "$REPAIR" || fail 'desktop repair syntax invalid'
for token in 'HYPRLAND_INSTANCE_SIGNATURE' 'WAYLAND_DISPLAY' 'umask 077' 'checks.tsv' 'validation.log' 'hyprctl configerrors' "grep -q '[^[:space:]]'" 'hyprctl monitors' 'caelestia shell -s' 'qs -c caelestia log' 'wpctl status' 'Sinks:' 'Sources:' 'permission denied' 'nmcli -t' 'rfkill list' '/sys/class/thermal/thermal_zone*' 'energy_full_design' 'journalctl --user' 'systemctl --failed' 'systemctl --user --failed' 'free -b' 'Kernel panic' 'Kernel driver in use: i915' '/sys/class/backlight/*' 'K41_REPORT_DIR=' 'caelestia_running' 'PASS_WITH_WARNINGS' 'fail_count' 'Actionable runtime/QML error signature' 'recognized informational platform/driver messages detected'; do
  grep -Fq -- "$token" "$VALIDATOR" || fail "validator missing expected health check/classification: $token"
done
if grep -Eq '(^|[[:space:]])sudo[[:space:]]|pacman -S|systemctl (enable|disable|start|stop)|mkfs\.|cryptsetup luksFormat|wipefs|parted' "$VALIDATOR"; then
  fail 'desktop validator must remain read-only'
fi
grep -Fq 'cannot prove that the panel' "$VALIDATOR" || fail 'validator must state log-validation limits'
grep -Fq 'chmod 0700 "$run_dir"' "$VALIDATOR" || fail 'validator report directory must be private'
grep -Fq 'chmod 0600 "$log" "$checks"' "$VALIDATOR" || fail 'validator report files must be private'
pass 'desktop validator syntax and safety contract'

for token in '--apply' 'systemctl cat bluetooth.service' 'sudo systemctl enable --now bluetooth.service' 'pacman -Q bluez' '/usr/lib/firmware/regulatory.db' '/etc/pam.d/other' 'No package installation' 'HCI feature errors'; do
  grep -Fq -- "$token" "$REPAIR" || fail "repair script missing expected guarded audit/remediation: $token"
done
if grep -Eq 'pacman -S|mkfs\.|cryptsetup luksFormat|wipefs|parted|systemctl (disable|stop)' "$REPAIR"; then
  fail 'repair script contains an unsupported package/storage/service-destructive operation'
fi
grep -Fq 'sudo systemctl enable --now bluetooth.service' "$REPAIR" || fail 'Bluetooth service action must be explicit and scoped'
grep -Fq 'if [[ -t 0 ]] && read -r -p' "$REPAIR" || fail 'repair action must require interactive approval'
grep -Fq 'chmod 0700 "$report_dir"' "$REPAIR" || fail 'repair report directory must be private'
grep -Fq 'chmod 0600 "$report"' "$REPAIR" || fail 'repair report must be private'
pass 'desktop repair syntax, approval gate, and safety contract'
