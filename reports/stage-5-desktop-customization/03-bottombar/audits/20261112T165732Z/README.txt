K41 Bottombar audit
===================
Run as the regular desktop user from the repository checkout on branch main:

  bash stages/stage-5-desktop-customization/workstreams/03-bottombar/scripts/k41-audit-bottombar.sh

The collector is read-only with respect to runtime configuration, packages,
services, and the active Git checkout. The complete report is retained locally
under ~/.local/state/k41/bottombar/audits/ with private permissions.
A sanitized copy is automatically published to GitHub main under:

  reports/stage-5-desktop-customization/03-bottombar/audits/<timestamp>/

Publication uses a fresh independent temporary clone, not a linked worktree.
It does not fetch, checkout, reset, clean, stash, add, commit, or push from the
active checkout and does not change its HEAD, branch, index, FETCH_HEAD, or
worktree metadata. If publication fails, the private local report is retained
and the script exits non-zero. Review the public report for residual sensitive
information; automated redaction cannot guarantee removal of every secret.
