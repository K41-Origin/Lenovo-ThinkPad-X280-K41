#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
SCRIPT="$ROOT/scripts/k41-desktop-validation.sh"
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$*"; }

[[ -f $SCRIPT ]] || fail 'canonical desktop validator missing'
bash -n "$SCRIPT" || fail 'desktop validator syntax invalid'
for token in 'HYPRLAND_INSTANCE_SIGNATURE' 'WAYLAND_DISPLAY' 'umask 077' 'checks.tsv' 'validation.log' 'hyprctl configerrors' "grep -q '[^[:space:]]' \"\$tmp/hypr-config-errors\"" 'hyprctl monitors' 'caelestia shell -s' 'qs -c caelestia log' 'wpctl status' 'Sinks:' 'Sources:' 'nmcli -t' 'rfkill list' '/sys/class/thermal/thermal_zone*' 'energy_full_design' 'journalctl --user' 'systemctl --failed' 'systemctl --user --failed' 'free -b' 'Kernel driver in use: i915' '/sys/class/backlight/*' 'K41_REPORT_DIR=' 'caelestia_running' 'PASS_WITH_WARNINGS' 'fail_count' 'k41_classify_caelestia_log' 'k41_classify_journal' 'scheme_file=' 'stale scheme startup and optional .face warnings are excluded only when their conditions are met' 'recognized informational platform/driver messages detected' 'diagnostics.tsv' 'diagnostics.log' 'CPU vulnerability mitigations' 'PCI devices and bound drivers' 'Regulatory database package ownership' 'Bluetooth service properties' 'Thermal hardware monitor inventory' 'ThinkPad ACPI interface' 'Relevant installed package versions'; do
  grep -Fq -- "$token" "$SCRIPT" || fail "validator missing expected health check: $token"
done
if grep -Eq '(^|[[:space:]])sudo[[:space:]]|pacman -S|systemctl (enable|disable|start|stop)|mkfs\.|cryptsetup luksFormat|wipefs|parted' "$SCRIPT"; then
  fail 'desktop validator must remain read-only'
fi
grep -Fq 'cannot prove that the panel' "$SCRIPT" || fail 'validator must state log-validation limits'
grep -Fq 'chmod 0700 "$run_dir"' "$SCRIPT" || fail 'report directory must be private'
grep -Fq 'chmod 0600 "$log" "$checks"' "$SCRIPT" || fail 'base report files must be private'
diag_line="$(grep -nF 'diagnostics="$run_dir/diagnostics.tsv"' "$SCRIPT" | cut -d: -f1)"
chmod_line="$(grep -nF 'chmod 0600 "$run_dir"/*.txt "$log" "$checks" "$diagnostics" "$diagnostics_log"' "$SCRIPT" | cut -d: -f1)"
[[ -n $diag_line && -n $chmod_line ]] || fail 'diagnostic report initialization/permission block missing'
(( diag_line < chmod_line )) || fail 'diagnostic permissions are applied before initialization'
pass 'desktop validator syntax, read-only contract, and diagnostic initialization order'

# Regression fixtures for the Caelestia runtime classifier.
source "$ROOT/scripts/lib/k41-log-classifiers.sh"
fixture_dir="$(mktemp -d)"
trap 'rm -rf -- "$fixture_dir"' EXIT
log_file="$fixture_dir/runtime.log"
scheme_file="$fixture_dir/scheme.json"
printf '%s\n' '{}' >"$scheme_file"

printf 'QML FileView: Read of %s failed: File does not exist.\n' "$scheme_file" >"$log_file"
findings="$(k41_classify_caelestia_log "$log_file" "$scheme_file")"
[[ -z $findings ]] || fail "resolved stale scheme warning was classified: $findings"
printf '%s\n' 'QML FileView: Read of /tmp/unrelated/scheme.json failed: File does not exist.' >"$log_file"
findings="$(k41_classify_caelestia_log "$log_file" "$scheme_file")"
[[ $findings == runtime-error ]] || fail "unrelated missing scheme path was incorrectly ignored: $findings"
rm -f -- "$scheme_file"
findings="$(k41_classify_caelestia_log "$log_file" "$scheme_file")"
[[ $findings == scheme-missing ]] || fail "missing scheme was not classified precisely: $findings"

: >"$scheme_file"
printf '%s\n' 'Source file does not exist: /home/test/.face' >"$log_file"
findings="$(k41_classify_caelestia_log "$log_file" "$scheme_file")"
[[ -z $findings ]] || fail "optional .face warning was classified: $findings"

printf '%s\n' 'Source file does not exist: /opt/caelestia/qml/Required.qml' >"$log_file"
findings="$(k41_classify_caelestia_log "$log_file" "$scheme_file")"
[[ $findings == missing-resource ]] || fail "non-optional missing resource was not classified: $findings"

printf '%s\n' 'QML Error: TypeError: cannot read property' >"$log_file"
findings="$(k41_classify_caelestia_log "$log_file" "$scheme_file")"
[[ $findings == runtime-error ]] || fail "real QML runtime error was not classified: $findings"

printf '%s\n' '{}' >"$scheme_file"
printf 'QML FileView: Read of %s failed: File does not exist.\n' "$scheme_file" >"$log_file"
printf '%s\n' 'QML Error: TypeError: invalid object' >>"$log_file"
findings="$(k41_classify_caelestia_log "$log_file" "$scheme_file")"
[[ $findings == runtime-error ]] || fail "real QML error was hidden by stale scheme warning: $findings"

printf '%s\n' 'org.bluez: D-Bus ObjectManager warning' >"$log_file"
findings="$(k41_classify_caelestia_log "$log_file" "$scheme_file" 1 1)"
[[ -z $findings ]] || fail "active Bluetooth service warning was classified: $findings"
findings="$(k41_classify_caelestia_log "$log_file" "$scheme_file" 0 1)"
[[ $findings == bluez-service-inactive ]] || fail "inactive Bluetooth service was not classified: $findings"

printf '%s\n' 'RTKit: realtime scheduling unavailable' >"$log_file"
findings="$(k41_classify_caelestia_log "$log_file" "$scheme_file" 1 1)"
[[ -z $findings ]] || fail "installed RTKit package warning was classified: $findings"
findings="$(k41_classify_caelestia_log "$log_file" "$scheme_file" 1 0)"
[[ $findings == rtkit-package-missing ]] || fail "missing RTKit package was not classified: $findings"


: >"$log_file"
classification="$(k41_classify_journal "$log_file" 0 0)"
[[ $classification == no-error-entries ]] || fail "empty successful journal query was not treated as clean: $classification"
classification="$(k41_classify_journal "$log_file" 1 0)"
[[ $classification == query-failed ]] || fail "failed empty journal query was not distinguished: $classification"

printf '%s\n' 'kernel: faux_driver regulatory: Direct firmware load for regulatory.db failed with error -2' >"$log_file"
classification="$(k41_classify_journal "$log_file" 0 1)"
[[ $classification == no-configured-signature ]] || fail "resolved regulatory database warning remained actionable: $classification"
classification="$(k41_classify_journal "$log_file" 0 0)"
[[ $classification == actionable ]] || fail "missing regulatory database warning was not actionable: $classification"

printf '%s\n' 'kernel: virt/tdx: TDX not supported by the host platform' 'app[123]: error: unrelated application failure' >"$log_file"
classification="$(k41_classify_journal "$log_file" 0 0)"
[[ $classification == unclassified-error ]] || fail "informational journal line masked an unrelated error: $classification"

printf '%s\n' 'kernel: Kernel panic - not syncing' >"$log_file"
classification="$(k41_classify_journal "$log_file" 0 0)"
[[ $classification == critical ]] || fail "critical kernel signature was not prioritized: $classification"

pass 'Journal classifier regression fixtures (empty queries, resolved firmware, mixed informational/error, and critical signatures)'
pass 'Caelestia log classifier regression fixtures (stale scheme, optional avatar, missing resource, real QML errors, BlueZ, and RTKit)'

