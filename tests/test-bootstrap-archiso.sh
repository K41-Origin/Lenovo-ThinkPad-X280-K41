#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
SCRIPT="$ROOT/scripts/bootstrap-archiso.sh"

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

[[ -f $SCRIPT ]] || fail "Arch ISO bootstrap script is missing"
bash -n "$SCRIPT" || fail "Arch ISO bootstrap has a Bash syntax error"

for entry in k41-install-basic-arch.sh k41-install-desktop.sh; do
  path="$ROOT/scripts/$entry"
  [[ -f $path ]] || fail "canonical entry point is missing: $entry"
  bash -n "$path" || fail "canonical entry point has a Bash syntax error: $entry"
done
grep -Fq 'exec bash "$ROOT/scripts/install-arch-x280.sh" "$@"' "$ROOT/scripts/k41-install-basic-arch.sh" ||
  fail "basic Arch entry point does not delegate to the existing installer"
grep -Fq 'exec bash "$ROOT/scripts/setup-desktop-x280.sh" "$@"' "$ROOT/scripts/k41-install-desktop.sh" ||
  fail "desktop entry point does not delegate to the existing setup implementation"
pass "canonical entry points exist, parse, and delegate"

required=(
  'readonly REPOSITORY_URL="https://github.com/K41-Origin/Lenovo-ThinkPad-X280-K41.git"'
  'git clone --depth 1 --single-branch --branch main'
  'git -C "$repo_dir" remote get-url origin'
  'git -C "$repo_dir" rev-parse HEAD'
  'git -C "$repo_dir" status --porcelain'
  'review_files=('
  'README.md'
  'AGENTS.md'
  'docs/00-START-HERE.md'
  'docs/01-PROJECT.md'
  'docs/02-INSTALLATION.md'
  'docs/03-DESKTOP.md'
  'docs/04-TESTING.md'
  'docs/05-OPERATIONS.md'
  'docs/06-STATUS.md'
  'scripts/k41-install-basic-arch.sh'
  'scripts/install-arch-x280.sh'
  'scripts/configure-arch-x280.sh'
  'config/hardware/thinkpad-x280.conf'
  'scripts/bootstrap-archiso.sh'
  'stages/stage-1-live-readiness/scripts/k41-live-validation.sh'
  'scripts/k41-install-desktop.sh'
  'scripts/setup-desktop-x280.sh'
  'stages/stage-1-live-readiness/scripts/x280-install-readiness.sh'
  'scripts/x280-first-boot-check.sh'
  'tests/helpers/storage-fixtures.sh'
  'REVIEWED $commit_sha AND AUTHORIZE READ-ONLY READINESS CHECK'
  'bash stages/stage-1-live-readiness/scripts/k41-live-validation.sh --readiness'
  'READINESS PASSED FOR $commit_sha AND AUTHORIZE INSTALLER LAUNCH'
  'exec bash "$repo_dir/scripts/k41-install-basic-arch.sh"'
)
for token in "${required[@]}"; do
  grep -Fq -- "$token" "$SCRIPT" || fail "required bootstrap review/safety control is missing: $token"
done
pass "bootstrap pins commit, verifies origin/clean checkout, reviews current files, runs readiness, and requires two exact acknowledgements"

if grep -Eq 'curl[^|]*\|[[:space:]]*(ba)?sh|wget[^|]*\|[[:space:]]*(ba)?sh' "$SCRIPT"; then
  fail "bootstrap pipes remote content directly into a shell"
fi
pass "bootstrap does not pipe remote content into a shell"

if grep -Eq 'wipefs|sgdisk|cryptsetup|mkfs\.' "$SCRIPT"; then
  fail "bootstrap itself contains destructive storage commands"
fi
pass "bootstrap delegates storage operations only to the separately reviewed installer"
