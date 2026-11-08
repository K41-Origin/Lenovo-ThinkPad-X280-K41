# ThinkPad X280 Hardware Audit

## Purpose

Collect a read-only snapshot of the installed Arch system before selecting any battery, thermal, power, graphics, or device tuning. The report is evidence for the current machine and boot only; it is not an optimization profile or hardware acceptance result.

## Run

From the repository checkout on the installed ThinkPad X280, as the regular desktop user:

```bash
git pull --ff-only
bash scripts/audit-x280-hardware.sh
```

Do not run with `sudo`. The collector writes a private timestamped report under `reports/hardware-audit/<UTC timestamp>/`:

- `summary.md` — capture metadata and safety boundary.
- `diagnostics.txt` — CPU, memory, DMI identity (non-unique fields), PCI/USB devices, storage topology without serials/UUIDs, graphics, network state without SSIDs/MACs, battery, thermal sensors, and power-management service state.

## Safety and privacy

- Read-only: no package installation, service changes, configuration edits, firmware writes, partitioning, formatting, or storage operations.
- Does not require root; inaccessible optional diagnostics are recorded as skipped/unavailable.
- Report files and directory are created with restrictive permissions (0600/0700).
- Disk serials, filesystem UUIDs, MAC addresses, Wi-Fi SSIDs, and DMI serial numbers are not requested. Review the report before committing or sharing it; command output and hardware metadata can still disclose information about the host.
- A completed collection is not a PASS for battery life, thermal behavior, suspend/resume, or hardware function.

## Next decision gate

Review the report before changing anything. Select at most one power-management approach based on the observed services and kernel interfaces. Do not enable TLP, power-profiles-daemon, tuned, or thermald until conflicts and actual support are checked. Battery charge thresholds, fan controls, CPU policy, and suspend/hibernate behavior require separate verification and acceptance tests.
