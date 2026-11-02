#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT

mkdir -p "$tmp/repo/lib"
cp "$repo_root/installer" "$tmp/repo/installer"
cp "$repo_root/lib/common.sh" "$tmp/repo/lib/common.sh"

cat >"$tmp/repo/lib/preflight.sh" <<'MOCK_PREFLIGHT'
mock_record() { printf '%s\n' "$1" >>"$K41_TEST_CALL_LOG"; }
preflight::check_root() { mock_record root; return "${K41_MOCK_ROOT_STATUS:-0}"; }
preflight::check_target_inventory() { mock_record inventory; return "${K41_MOCK_INVENTORY_STATUS:-0}"; }
preflight::detect_boot_mode() { mock_record boot; return "${K41_MOCK_BOOT_STATUS:-0}"; }
preflight::check_commands() { mock_record commands; return "${K41_MOCK_COMMANDS_STATUS:-0}"; }
preflight::report_network_links() { mock_record network; return "${K41_MOCK_NETWORK_STATUS:-0}"; }
MOCK_PREFLIGHT

run_case() {
  local label=$1 expected_status=$2 expected_calls=$3
  shift 3
  : >"$tmp/calls"
  set +e
  env K41_TEST_CALL_LOG="$tmp/calls" "$@" bash "$tmp/repo/installer" --preflight >"$tmp/out" 2>"$tmp/err"
  local status=$?
  set -e
  [[ "$status" -eq "$expected_status" ]] || fail "$label: expected status $expected_status, got $status"

  local calls
  calls="$(cat "$tmp/calls")"
  [[ "$calls" == "$expected_calls" ]] || fail "$label: unexpected preflight call sequence: $calls"

  if grep -Eq 'INSTALL_STAGE|storage::execute_plan|pacman|mkfs|cryptsetup|systemctl' "$tmp/calls" "$tmp/out" "$tmp/err"; then
    fail "$label: installation/destructive marker detected"
  fi
  pass "$label"
}

expected=$'root\ninventory\nboot\ncommands\nnetwork'
run_case 'resolved diagnostics still leave installation disabled' 2 "$expected" env
run_case 'inventory mismatch blocks preflight success' 2 "$expected" env K41_MOCK_INVENTORY_STATUS=1
run_case 'unresolved boot mode blocks preflight success' 2 "$expected" env K41_MOCK_BOOT_STATUS=2
run_case 'required-command failure blocks preflight success' 2 "$expected" env K41_MOCK_COMMANDS_STATUS=1
run_case 'optional network diagnostic failure does not change required gate result' 2 "$expected" env K41_MOCK_NETWORK_STATUS=2

printf '%s\n' 'All preflight-gate tests passed.'
