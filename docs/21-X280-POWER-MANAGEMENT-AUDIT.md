# ThinkPad X280 Power-Management Baseline Audit

## Purpose

Capture the active power-management configuration before designing battery, CPU, or thermal tuning. This complements the broad hardware collector and focuses on CPU frequency policy, governors, EPP, Intel pstate, ACPI platform profile, AC/battery state, and power-management services.

## Run

From the repository checkout on the ThinkPad, as the regular desktop user:

```bash
git pull --ff-only
bash scripts/audit-x280-power-management.sh
```

Do not use `sudo`. Reports are written under `reports/power-management-audit/<UTC timestamp>/`:

- `summary.md` — capture metadata and safety boundary.
- `diagnostics.txt` — CPU policies, EPP, Intel pstate, platform profile, CPU idle driver, AC/battery state, service state, and optional tool output.

## Safety and privacy

- The collector refuses root execution and requires no privilege escalation.
- It reads sysfs and queries service/profile state only. It does not write sysfs, install packages, enable/disable/restart services, alter configuration, or write firmware.
- Output directory mode is 0700; report files are 0600.
- It does not collect serial numbers, MAC addresses, Wi-Fi SSIDs, credentials, or the kernel command line.
- Optional `powerprofilesctl`, `busctl`, `tlp-stat`, and `upower` commands are recorded when unavailable. The collector also captures Power Profiles daemon D-Bus introspection and its `ActiveProfile` property as a diagnostic fallback if the Python-based CLI fails. D-Bus queries are read-only; if the daemon is absent or the interface differs, the command failure is recorded and collection continues.
- Collection completion is not proof of battery runtime, thermal stability, or suspend/resume reliability.

## Decision gate

If `power-profiles-daemon` is active, do not enable TLP or tuned as competing managers without a documented migration plan. Do not change governors, EPP, platform profile, charge thresholds, fan behavior, or service state based solely on a static snapshot. Future tuning must include rollback and AC-versus-battery acceptance tests.
