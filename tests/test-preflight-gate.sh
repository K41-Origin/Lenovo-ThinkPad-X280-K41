#!/usr/bin/env bash
set -Eeuo pipefail
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
tmp="$(mktemp -d)"
mkdir -p "$tmp/repo/lib"
cp "$repo_root/installer" "$tmp/repo/installer"
cp "$repo_root/lib/common.sh" "$tmp/repo/lib/common.sh"
cat >"$tmp/repo/lib/preflight.sh" <<'MOCK'
mock_record() { printf '%s\n' "$1" >>"$K41_TEST_CALL_LOG"; }
preflight::check_root() { mock_record root; }
preflight::check_target_inventory() { mock_record inventory; return "${K41_MOCK_INVENTORY_STATUS:-0}"; }
preflight::detect_boot_mode() { mock_record boot; return "${K41_MOCK_BOOT_STATUS:-0}"; }
preflight::check_commands() { mock_record commands; }
preflight::report_network_links() { mock_record network; }
MOCK
expected=$'root\ninventory\nboot\ncommands\nnetwork'
for scenario in success inventory-fail boot-fail; do
  : >"$tmp/calls"
  status=0
  case "$scenario" in
    inventory-fail) env K41_TEST_CALL_LOG="$tmp/calls" K41_MOCK_INVENTORY_STATUS=1 bash "$tmp/repo/installer" --preflight >/dev/null 2>&1 || status=$? ;;
    boot-fail) env K41_TEST_CALL_LOG="$tmp/calls" K41_MOCK_BOOT_STATUS=2 bash "$tmp/repo/installer" --preflight >/dev/null 2>&1 || status=$? ;;
    *) env K41_TEST_CALL_LOG="$tmp/calls" bash "$tmp/repo/installer" --preflight >/dev/null 2>&1 || status=$? ;;
  esac
  [[ "$status" -eq 2 ]]
  [[ "$(cat "$tmp/calls")" == "$expected" ]]
  printf 'PASS: %s\n' "$scenario"
done
printf '%s\n' 'All preflight-gate tests passed.'
