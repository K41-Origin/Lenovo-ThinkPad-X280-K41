#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT

# The entry point must be callable from outside the repository directory.
help_output="$(cd / && "$repo_root/installer" --help 2>&1)" || fail '--help returned failure'
[[ "$help_output" == *'read-only environment diagnostics only'* ]] || fail 'help does not document diagnostic-only behavior'
[[ "$help_output" == *'Installation is not implemented'* ]] || fail 'help fails to disclose that installation is disabled'
pass 'entry point resolves modules relative to itself and documents its limits'

# Unsupported arguments must fail without entering any workflow.
if "$repo_root/installer" --install >"$tmp/invalid.out" 2>"$tmp/invalid.err"; then
  fail 'unsupported argument returned success'
fi
grep -q '^Usage:' "$tmp/invalid.err" || fail 'unsupported argument did not print usage'
pass 'unsupported arguments fail closed'

# Preflight must never claim installation success, regardless of host boot mode.
set +e
"$repo_root/installer" --preflight >"$tmp/preflight.out" 2>"$tmp/preflight.err"
preflight_status=$?
set -e
[[ "$preflight_status" -ne 0 ]] || fail 'preflight returned success while installation is unimplemented'
grep -Eq 'installation remains disabled|No installation stage exists or was invoked' "$tmp/preflight.err" || fail 'preflight did not disclose that installation remains disabled'
pass 'preflight cannot return success or claim installation approval'

# Static safety boundary: the entry point may source only common/preflight.
if grep -Eq 'lib/(storage|base-system|bootloader|user-setup|desktop|hardware|packages|security|validation|report)\.sh|(^|[[:space:]])(mkfs|parted|sgdisk|fdisk|cryptsetup|pacman|systemctl)([[:space:]]|$)|sudo[[:space:]]' "$repo_root/installer"; then
  fail 'entry point contains an installation module or system-changing command path'
fi
grep -q 'lib/common.sh' "$repo_root/installer" || fail 'common module is not sourced'
grep -q 'lib/preflight.sh' "$repo_root/installer" || fail 'preflight module is not sourced'
pass 'entry point has no storage/install module or privileged/system-changing command path'

printf '%s\n' 'All installer-entry tests passed.'
