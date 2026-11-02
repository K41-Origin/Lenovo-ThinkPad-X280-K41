# Tests

The repository includes fixture-based tests for common/preflight behavior, installer entry handling, host inventory, storage discovery, and the preflight safety gate. They do not constitute end-to-end installation tests.

Run from the repository root:

```bash
bash tests/test-common-preflight.sh
bash tests/test-installer-entry.sh
bash tests/test-inventory.sh
bash tests/test-storage-discovery.sh
bash tests/test-preflight-gate.sh
```

GitHub Actions runs Bash syntax checks and all five test scripts on pushes to `main`, pull requests targeting `main`, and manual workflow dispatch. Treat the workflow as implemented, not passed, until its run completes successfully.

Storage tests mock `lsblk` and `swapon` and use JSON fixtures. They cover whole-disk discovery, internal NVMe acceptance, removable-device rejection, mounted descendants (including a mapper child), active swap descendants, duplicate WWN detection, changed secondary identity, unknown safety state, tool failures, and invalid output arrays. The tests do not inspect or modify host disks. Storage discovery requires `lsblk`, `jq`, `swapon`, and `base64`.

Inventory tests use temporary procfs/sysfs-shaped fixtures; they do not inspect actual hardware or require root. The mocked preflight gate verifies inventory failure blocks preflight success and that no installation/destructive marker is invoked.

Initial and future test layers:
- Bash syntax checks for all shell files.
- ShellCheck and shfmt when available.
- Unit tests with mocked commands for preflight, stage tracking, and error handling.
- Storage tests using mocks and, later, disposable loop devices only in isolated environments; never target a real disk.
- Integration tests in a disposable VM before any controlled ThinkPad X280 installation.
- Hardware-only checks (Wi-Fi, audio, suspend, hibernate/resume, lid behavior) remain NOT TESTED until run on the actual device.

Never treat a successful syntax check or mocked test as proof that installation works.
