#!/usr/bin/env bash
set -Eeuo pipefail

root="$(git -C "$(dirname -- "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
script="$root/stages/stage-5-desktop-customization/workstreams/03-bottombar/scripts/k41-audit-bottombar.sh"

[[ -s $script ]] || { printf 'FAIL: Bottombar audit script missing.\n' >&2; exit 1; }
bash -n "$script"

for token in \
  'report_root="$state_root/k41/bottombar/audits"' \
  'export GIT_OPTIONAL_LOCKS=0' \\
  'published_report="$run_dir/published-report.txt"' \
  'publish_report()' \
  'git clone --quiet --no-tags --single-branch --branch main "$remote_url" "$publish_dir"' \
  'GIT_TERMINAL_PROMPT=0 git -C "$publish_dir" push origin HEAD:main' \
  'GIT_TERMINAL_PROMPT=0 git -C "$publish_dir" fetch --no-tags origin main' \
  'git -C "$publish_dir" rebase FETCH_HEAD' \
  'reports/stage-5-desktop-customization/03-bottombar/audits/' \
  'chmod 0600 "$published_report"' \
  'chmod 0700 "$run_dir"' \
  'HOST-REDACTED' \
  'LOCAL-IDENTITY-REDACTED' \
  'uid|gid' \
  'REPOSITORY_CHECKOUT' \
  'active checkout Git metadata was not used'; do
  grep -Fq -- "$token" "$script" || {
    printf 'FAIL: Bottombar audit publisher missing required behavior: %s\n' "$token" >&2
    exit 1
  }
done

# The publisher must never fetch, push, or register a linked worktree against
# the user's active checkout. All write operations belong to publish_dir.
for forbidden in \
  'git -C "$repo_root" fetch' \
  'git -C "$repo_root" push' \
  'git -C "$repo_root" worktree' \
  'git -C "$repo_root" checkout' \
  'git -C "$repo_root" reset' \
  'git -C "$repo_root" clean'; do
  ! grep -Fq -- "$forbidden" "$script" || {
    printf 'FAIL: audit publisher mutates active checkout: %s\n' "$forbidden" >&2
    exit 1
  }
done

! grep -Fq 'report_root="$repo_root/reports' "$script" || {
  printf 'FAIL: private local report is stored inside the checkout.\n' >&2
  exit 1
}
grep -Fq 'git -C "$publish_dir" add -- "$relative_dir"' "$script"
grep -Fq 'git -C "$publish_dir" commit -m "Add X280 Bottombar audit report"' "$script"
grep -Fq 'rm -rf -- "$publish_tmp"' "$script"

# Audit collector must remain observational; it must not mutate host services
# or install packages as part of report generation.
if grep -Eiq 'systemctl[[:space:]]+(enable|disable|start|stop|restart|daemon-reload)|pacman[[:space:]]+(-S|--sync)' "$script"; then
  printf 'FAIL: Bottombar audit contains a host mutation command.\n' >&2
  exit 1
fi
! grep -Eiq '(^|[;&|[:space:]])(sudo|chown)[[:space:]]' "$script" || {
  printf 'FAIL: Bottombar audit must not elevate or change ownership.\n' >&2
  exit 1
}

printf 'PASS: Bottombar audit publisher isolation, sanitized publication, and read-only contract.\n'
