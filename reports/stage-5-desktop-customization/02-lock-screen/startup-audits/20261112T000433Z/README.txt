K41 desktop startup diagnostic
===============================
Run this script as the regular desktop user from tty2 or a normal shell:

  bash stages/stage-5-desktop-customization/workstreams/02-lock-screen/scripts/k41-audit-desktop-startup.sh

Report: report.txt

The collector does not modify host system state and does not attempt to launch or repair Hyprland. It writes a private local report and publishes a sanitized copy.
The script publishes a sanitized copy of this run directory (report.txt, README.txt, lifecycle-timeline.tsv) to GitHub main using existing Git credentials. The local report remains private (0600); if publication fails, the report stays local and the script exits non-zero. Review the published report for any residual private information.
