# Tests

Status: First-slice common/preflight tests are implemented and passed locally against temporary copies whose Git blob hashes matched the committed files. The installer now has a diagnostic-only entry point and focused entry-point tests; actual installation remains unimplemented and has not been tested end to end.

Run the focused tests from the repository root with `bash tests/test-common-preflight.sh`, `bash tests/test-installer-entry.sh`, `bash tests/test-preflight-gate.sh`, and `bash tests/test-inventory.sh`, and `bash tests/test-storage-discovery.sh`. GitHub Actions runs Bash syntax checks and all five test scripts on pushes to `main`, pull requests targeting `main`, and manual workflow dispatch (`.github/workflows/bash-tests.yml`). Treat the workflow as implemented, not as passed, until its first run completes successfully. The entry test checks argument handling, relative module loading, diagnostic-only behavior, and a static safety boundary. The gate test uses a mocked preflight module in a temporary copy to exercise inventory mismatch, unresolved boot-mode, required-command, and optional network-diagnostic outcomes. These are not end-to-end installation tests.

Storage discovery tests mock `lsblk` output and exercise identity, mounted-descendant, removable-device, and invalid-array handling; they do not inspect or modify host disks. Storage discovery currently requires `lsblk`, `jq`, and `base64`.\n\nInventory tests use temporary procfs/sysfs-shaped fixtures and exercise the preflight inventory adapter; they do not inspect real disks or require root. The mocked gate test verifies inventory failure blocks preflight success and that no installation/destructive marker is invoked.\n\nInitial test layers:
- Bash syntax checks for all shell files.
- ShellCheck and shfmt when available.
- Unit tests with mocked commands for preflight, stage tracking, and error handling.
- Storage tests must use mocks/loop devices in an isolated environment; never target a real disk.
- Integration tests in a disposable VM before any controlled ThinkPad X280 installation.
- Hardware-only checks (Wi-Fi, audio, suspend, hibernate/resume, lid behavior) must be marked NOT TESTED until run on the actual device.

Never treat a successful syntax check as proof that installation works.
