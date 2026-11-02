# Tests

The repository includes fixture-based tests for common/preflight behavior, installer entry handling, host inventory, storage discovery, standalone storage-topology analysis, storage-plan arithmetic, and the preflight safety gate. They do not constitute end-to-end installation tests.

Run from the repository root:

```bash
bash tests/test-common-preflight.sh
bash tests/test-installer-entry.sh
bash tests/test-inventory.sh
bash tests/test-storage-discovery.sh
bash tests/test-storage-topology.sh
bash tests/test-storage-plan.sh
bash tests/test-preflight-gate.sh
```

GitHub Actions runs Bash syntax checks and all seven test scripts on pushes to `main`, pull requests targeting `main`, and manual workflow dispatch. Treat the workflow as implemented, not passed, until its run completes successfully.

Storage-discovery tests mock `lsblk` and `swapon` and use JSON fixtures. The topology module is called by `storage::validate_target` using the selected disk's kernel major:minor and live `/sys`, `/proc/self/mountinfo`, and `/proc/swaps`. The discovery test stubs that integration boundary; the topology test builds a synthetic sysfs graph and mountinfo/swaps fixtures. Coverage includes partition descendants, device-mapper holder/slave relationships, mounted dependencies, swapfiles, active block swap, loop-backed squashfs, overlay lower/upper/work directories, unresolved paths, malformed mountinfo, and unsupported filesystem types. Backing paths are mapped using their actual `st_dev` major:minor; no mounts or block-device writes are created. The storage-plan test checks GPT bounds, 1 MiB alignment, 512-byte and 4Kn logical sectors, capacity rejection, RAM-plus-margin swap sizing, overflow, and decimal normalization. The installer entry point still does not invoke storage selection or installation. Tests use fixtures/mocks and do not inspect or modify host disks. Storage discovery requires `lsblk`, `jq`, `swapon`, `readlink`, and `base64`.

Inventory tests use temporary procfs/sysfs-shaped fixtures; they do not inspect actual hardware or require root. The mocked preflight gate verifies inventory failure blocks preflight success and that no installation/destructive marker is invoked.

Initial and future test layers:
- Bash syntax checks for all shell files.
- ShellCheck and shfmt when available.
- Unit tests with mocked commands for preflight, stage tracking, and error handling.
- Storage tests using mocks and, later, disposable loop devices only in isolated environments; never target a real disk.
- Integration tests in a disposable VM before any controlled ThinkPad X280 installation.
- Hardware-only checks (Wi-Fi, audio, suspend, hibernate/resume, lid behavior) remain NOT TESTED until run on the actual device.

Never treat a successful syntax check or mocked test as proof that installation works.
