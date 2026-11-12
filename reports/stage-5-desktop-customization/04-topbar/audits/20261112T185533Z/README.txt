K41 Topbar audit
================
Run from repository checkout on branch main as the regular desktop user:

  bash stages/stage-5-desktop-customization/workstreams/04-topbar/scripts/k41-audit-topbar.sh

The collector is read-only with respect to runtime configuration, packages,
services, source files, and the active Git checkout. Full evidence remains
private under ~/.local/state/k41/topbar/audits/.
A sanitized report is published through a fresh independent clone to:

  reports/stage-5-desktop-customization/04-topbar/audits/<timestamp>/

The active checkout's HEAD, branch, index, FETCH_HEAD, and worktree metadata are
not used for publication. Review the public report for residual sensitive data;
automated redaction cannot guarantee removal of every secret.
