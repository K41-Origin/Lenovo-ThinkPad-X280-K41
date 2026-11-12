K41 desktop startup diagnostic
===============================
Run this script as the regular desktop user from tty2 or a normal shell:

  bash stages/stage-5-desktop-customization/workstreams/02-lock-screen/scripts/k41-audit-desktop-startup.sh

Report: report.txt

The collector does not modify configuration, packages, services, authentication, or boot state. By default it does not launch a shell. To run the optional 15-second foreground Quickshell diagnostic from an unlocked terminal inside the active Hyprland session, use:
  
  K41_AUDIT_RUN_QS_PROBE=1 bash stages/stage-5-desktop-customization/workstreams/02-lock-screen/scripts/k41-audit-desktop-startup.sh

The probe is skipped if Wayland session variables/socket are missing or a Quickshell/Caelestia process is already running. It may briefly display shell windows. The report is private locally and a redacted copy is published.
The script publishes a sanitized copy of this run directory (report.txt, README.txt, lifecycle-timeline.tsv) to GitHub main using existing Git credentials. The local report remains private (0600); if publication fails, the report stays local and the script exits non-zero. Review the published report for any residual private information.
