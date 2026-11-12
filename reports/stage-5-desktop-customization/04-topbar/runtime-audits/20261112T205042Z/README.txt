K41 WS04 Topbar runtime audit
=============================
Run as the regular desktop user, preferably from TTY after the failed desktop startup:

  bash stages/stage-5-desktop-customization/workstreams/04-topbar/scripts/k41-audit-topbar-runtime.sh

The collector is read-only. It records runtime Topbar files, Quickshell logs, UPower device telemetry, kernel battery sysfs values, and bounded Caelestia notification/sidebar QML source references. It does not deploy files, launch Quickshell, trigger notification/sidebar actions, reload/restart services, install packages, or edit configuration. The complete local report is private under ~/.local/state/k41/topbar/runtime-audits/.

A separately redacted copy is published to the repository reports directory through an independent temporary clone. Review the published report for residual sensitive information. If publication fails, the private local report remains available and the script exits non-zero.
