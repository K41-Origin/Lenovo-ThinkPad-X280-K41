# ThinkPad X280 Power-Management Baseline Audit

## Read-only audit

    git pull --ff-only
    bash scripts/audit-x280-power-management.sh

Run as the regular user, without sudo. Reports are private under reports/power-management-audit/.

## Controlled Power Profiles comparison

The X280 report confirmed a working D-Bus ActiveProfile property and current profile balanced. The powerprofilesctl frontend fails due to a Python GI import error, while busctl D-Bus queries work.

Inspect profiles:

    bash scripts/set-x280-power-profile.sh --show

Explicitly test power saver:

    bash scripts/set-x280-power-profile.sh --apply power-saver

Restore balanced after the comparison:

    bash scripts/set-x280-power-profile.sh --apply balanced

The selector detects the daemon D-Bus endpoint, checks that the requested profile is exposed, applies only an explicit allowlisted profile, and reads back ActiveProfile. It prints a rollback command before changing state. It does not install packages, alter services, or write sysfs. If D-Bus authorization denies the operation, stop rather than bypassing policy with arbitrary root commands.

Treat power-saver as a temporary A/B test, not a permanent recommendation. Compare repeated discharge-power readings and workload responsiveness under similar brightness, radio, peripheral, and workload conditions. A single power_now reading is noisy. Restore the original profile after testing.

## Safety

The baseline collector is read-only, refuses root, uses private report permissions, and does not collect serials, MAC addresses, SSIDs, credentials, or kernel command line. Collection completion is not proof of battery runtime, thermal stability, or suspend/resume reliability.

Keep Power Profiles Daemon as the single profile manager. Do not enable TLP or tuned alongside it. Permanent tuning requires repeatable AC/battery measurements, workload checks, and documented rollback.
