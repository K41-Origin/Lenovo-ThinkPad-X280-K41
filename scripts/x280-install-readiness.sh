#!/usr/bin/env bash
# Safe physical X280 installation gate: tests and read-only device validation only.
# This script NEVER partitions, formats, opens LUKS, mounts, or installs Arch.
set -Eeuo pipefail
umask 077

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}
info() { printf '\n== %s ==\n' "$*"; }

(( EUID == 0 )) || fail "Run as root from the official Arch Linux ISO."
[[ -f /etc/arch-release ]] || fail "This is not an Arch Linux environment."
[[ -d /sys/firmware/efi ]] || fail "Boot the Arch ISO in UEFI mode."
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "Repository checkout is invalid."

commit="$(git rev-parse HEAD)"
branch="$(git branch --show-current)"
printf 'Repository: %s\nBranch: %s\nCommit: %s\n' "$ROOT" "$branch" "$commit"
printf 'Working tree: '
if [[ -z "$(git status --porcelain)" ]]; then
  printf 'clean\n'
else
  printf 'has local changes (review before proceeding)\n'
fi

for cmd in bash git lsblk jq swapon base64 readlink stat; do
  command -v "$cmd" >/dev/null 2>&1 || fail "Required command missing: $cmd"
done

info "Bash syntax validation"
mapfile -d '' shell_files < <(find . -type f \( -name '*.sh' -o -name installer \) -not -path './.git/*' -print0)
(("${#shell_files[@]}" > 0)) || fail "No shell scripts found."
for file in "${shell_files[@]}"; do
  bash -n "$file" || fail "Bash syntax error: $file"
done
printf 'PASS: %s shell files pass bash -n\n' "${#shell_files[@]}"

info "Canonical automated test suite"
bash tests/run.sh || fail "Automated test suite failed. Review reports/test-runs/."

info "Physical X280 storage identity and topology (READ-ONLY)"
bash scripts/validate-live-storage.sh || fail "Live X280 storage validation failed. No installer was started."

cat <<EOF

PASS: live installation readiness checks completed.
Verified checkout: $commit

NO DISK CHANGES WERE MADE.
This gate does not authorize or execute the destructive installer.

Next step, only after reviewing the test report and confirming a current backup:
  bash scripts/install-arch-x280.sh

WARNING: the command above erases the selected internal SSD. It must be
started separately and only with explicit operator authorization after
independently checking the displayed model, serial, capacity, and plan.
If any identity differs from the expected X280 SSD, STOP.
EOF
