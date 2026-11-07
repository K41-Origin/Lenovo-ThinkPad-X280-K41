#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
SCRIPT="$ROOT/scripts/bootstrap-archiso.sh"

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

[[ -f $SCRIPT ]] || fail "Arch ISO bootstrap script is missing"
bash -n "$SCRIPT" || fail "Arch ISO bootstrap has a Bash syntax error"
pass "bootstrap passes bash -n"

for required in \
  'readonly REPOSITORY_URL="https://github.com/K41-Origin/Lenovo-ThinkPad-X280-K41.git"' \
  'git clone --depth 1 --single-branch --branch main' \
  'git -C "$repo_dir" remote get-url origin' \
  'git -C "$repo_dir" rev-parse HEAD' \
  'git -C "$repo_dir" status --porcelain' \
  'review_files=(' \
  'scripts/install-arch-x280.sh' \
  'scripts/configure-arch-x280.sh' \
  'config/hardware/thinkpad-x280.conf' \
  'REVIEWED $commit_sha AND AUTHORIZE INSTALLER LAUNCH' \
  'exec bash "$repo_dir/scripts/install-arch-x280.sh"'; do
  grep -Fq -- "$required" "$SCRIPT" || fail "required bootstrap review/safety control is missing: $required"
done
pass "bootstrap pins and displays the fetched commit, verifies origin/clean checkout, reviews source, and requires exact acknowledgement"

if grep -Eq 'curl[^|]*\|[[:space:]]*(ba)?sh|wget[^|]*\|[[:space:]]*(ba)?sh' "$SCRIPT"; then
  fail "bootstrap pipes remote content directly into a shell"
fi
pass "bootstrap does not pipe remote content into a shell"

if grep -Eq 'wipefs|sgdisk|cryptsetup|mkfs\.' "$SCRIPT"; then
  fail "bootstrap itself contains destructive storage commands"
fi
pass "bootstrap delegates storage operations only to the separately reviewed installer"
