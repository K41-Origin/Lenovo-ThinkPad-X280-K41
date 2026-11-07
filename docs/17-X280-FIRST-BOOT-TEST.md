# ThinkPad X280 first-boot test and evidence collection

## Purpose and scope

`scripts/x280-first-boot-check.sh` is a read-only evidence collector to run after the initial Arch installation has booted from the internal SSD. It checks the expected UEFI, systemd-boot, UKI, LUKS2 mapper, ext4 root, EFI mount, systemd, NetworkManager, and user-session context. It also records hardware inventory and current-boot error journal output.

The script does not repair or configure the system. It does not partition, format, mount, unlock, change boot entries, enable/disable/start/stop services, install packages, or alter network settings. A FAIL is evidence for diagnosis, not an instruction to make an automatic repair.

## Run after the first successful login

From the installed Arch system, open a terminal and run:

```bash
sudo bash scripts/x280-first-boot-check.sh
```

The script creates a timestamped directory:

```text
reports/first-boot/<UTC timestamp>/
├── summary.md
├── diagnostics.log
├── boot-status.txt
├── system-status.txt
└── hardware.txt
```

All files are created with owner-only permissions (directory 0700, files 0600). The summary contains PASS/FAIL/SKIP counts and the result of each acceptance check. The collector returns exit code 1 when any acceptance check fails; the report is retained in that case. SKIP is not a pass, and the report may still need manual review.

## Acceptance checks

- Installed Arch Linux marker is present.
- Current boot is UEFI.
- Root is ext4 mounted from `/dev/mapper/cryptroot`.
- The `cryptroot` device-mapper mapping is active.
- EFI system partition is mounted as vfat at `/efi`.
- systemd-boot status is queryable and a UKI exists under the expected ESP paths.
- systemd is running, no failed units are reported, and the default target is active.
- NetworkManager is active and NetworkManager reports a connected state.
- The script is invoked through sudo from a regular-user session (otherwise this contextual check is SKIP).

This collector does not prove that a person successfully authenticated by password; it only records the invoking sudo UID when available. It does not test Wi-Fi roaming, DNS quality, internet reachability beyond NetworkManager's state, suspend/resume, audio, camera, Bluetooth, battery endurance, thermal behavior, or performance.

## Privacy and pushing the report

The collector intentionally omits disk serials, filesystem UUIDs, hostnames, account names, IP addresses, and MAC addresses from its hardware inventory. It applies best-effort redaction to captured command output and journal messages. This cannot guarantee that all sensitive data is removed.

**Review every file before committing.** In particular inspect `diagnostics.log`, `system-status.txt`, and `boot-status.txt` for passphrases, tokens, private data, or unexpected identifiers. Do not push a report until it is safe to publish.

The collector never runs `git add`, commit, or push. After review, stage only the selected report directory, for example:

```bash
git status --short
git add reports/first-boot/<UTC timestamp>
git diff --cached --stat
git diff --cached
git commit -m "Add X280 first-boot test report"
git push
```

Do not stage the entire `reports/` tree or unrelated local files.

## Validation limits

`tests/test-x280-first-boot-check.sh` uses mocked command outputs and temporary fixture files. It verifies report generation, healthy PASS behavior, failed-systemd-unit propagation, and the absence of mutating operations in the collector. It does not simulate a real firmware boot, decrypt a real disk, or validate the physical X280. Only a report collected from the actual laptop can establish first-boot observations.
