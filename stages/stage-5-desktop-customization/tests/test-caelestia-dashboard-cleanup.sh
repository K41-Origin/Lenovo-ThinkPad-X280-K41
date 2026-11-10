#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $EUID -eq 0 ]]; then
  printf 'FAIL: Dashboard removal pre-audit must run as a regular user.\n' >&2
  exit 1
fi

root="$(cd -- "$(dirname -- "\${BASH_SOURCE[0]}")/../../.." && pwd -P)"
script="$root/stages/stage-5-desktop-customization/scripts/k41-cleanup-caelestia.sh"
[[ -f $script ]]

if bash "$script" --apply > /dev/null 2>&1; then
  printf 'FAIL: --apply unexpectedly allowed an unreviewed deletion.\n' >&2
  exit 1
fi
if bash "$script" --rollback > /dev/null 2>&1; then
  printf 'FAIL: obsolete rollback mode unexpectedly succeeded.\n' >&2
  exit 1
fi

config="\${XDG_CONFIG_HOME:-$HOME/.config}/caelestia/shell.json"
before=""
if [[ -f $config ]]; then
  before="$(sha256sum "$config" | awk '{print $1}')"
fi

output="$(bash "$script" --audit)"
grep -q 'Mode: READ-ONLY' <<<"$output"
grep -q 'Dashboard removal pre-audit completed' <<<"$output"
report_rel="$(sed -n 's/^REPORT_DIR=//p' <<<"$output" | tail -n 1)"
[[ -n $report_rel ]]
report="$root/$report_rel"
[[ -f $report/summary.txt && -f $report/run.log ]]
[[ -f $report/config-snapshot.json ]]
[[ -f $report/dashboard-config-inventory.json ]]
[[ -f $report/dashboard-source-references.txt ]]
[[ -f $report/dashboard-keybinds.json ]]
grep -q 'Mode: read-only; no configuration or system state changed.' "$report/summary.txt"

after=""
if [[ -f $config ]]; then
  after="$(sha256sum "$config" | awk '{print $1}')"
fi
[[ $before == "$after" ]]

case "$report" in
  "$root/reports/stage-5-desktop-customization/caelestia-audit/"*)
    rm -rf -- "$report"
    ;;
  *)
    printf 'FAIL: refusing to remove unexpected test report path: %s\n' "$report" >&2
    exit 1
    ;;
esac

printf 'PASS: Dashboard cleanup pre-audit creates inventory, preserves config, and blocks deletion pending review.\n'
