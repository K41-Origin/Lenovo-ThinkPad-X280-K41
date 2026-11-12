K41 Topbar environment audit
============================
Run as the regular desktop user from the repository checkout on branch main:

  bash stages/stage-5-desktop-customization/workstreams/04-topbar/scripts/k41-audit-topbar.sh

The audit is observational and does not modify runtime configuration, packages,
services, source files, or the active Git checkout. The full report is stored
privately at ~/.local/state/k41/topbar/audits/<timestamp>/topbar-audit.txt.

Only a bounded, privacy-minimized summary is published. It excludes source/config
contents, process command-line arguments, environment variables, host identity,
user identity, and absolute home paths. Automated minimization is not a guarantee
against every possible disclosure; inspect the summary before sharing further.

Caelestia has no native Topbar in this project baseline. The audit does not
assume one exists; it inventories the available shell/runtime environment so
K41 can implement its own Topbar using a verified integration point.
