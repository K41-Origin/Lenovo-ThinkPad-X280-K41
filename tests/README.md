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

Storage-discovery tests mock `lsblk` and `swapon` and use JSON fixtures. The standalone topology test builds a temporary sysfs-shaped block graph and synthetic mountinfo/swaps files; it exercises partition descendants, a device-mapper holder/slave relationship, mounted dependencies, swapfile backing, and unresolved swap mounts. The storage-plan test checks GPT bounds, 1 MiB alignment, 512-byte and 4Kn logical sectors, capacity rejection, and the RAM-plus-margin swap proposal. The topology module is now called by `storage::validate_target` using the selected disk's kernel major:minor and the live `/sys`, `/proc/self/mountinfo`, and `/proc/swaps` interfaces. The discovery test stubs that call to verify integration and fail-closed behavior; the standalone topology test exercises the algorithm against synthetic fixtures. The installer entry point still does not invoke storage selection or installation. Topology coverage includes partition descendants, device-mapper holder/slave relationships, mounted dependencies, active swapfile backing, ambiguous filesystem types, malformed mountinfo, and unresolved inputs. The discovery suite covers whole-disk inventory, internal NVMe acceptance, removable-device rejection, mounted descendants, active swap descendants and aliases, duplicate WWN detection, changed secondary identity, unknown safety state, and tool failures. The tests do not inspect or modify host disks. Storage discovery requires `lsblk`, `jq`, `swapon`, `readlink`, and `base64`.

Inventory tests use temporary procfs/sysfs-shaped fixtures; they do not inspect actual hardware or require root. The mocked preflight gate verifies inventory failure blocks preflight success and that no installation/destructive marker is invoked.

Initial and future test layers:
- Bash syntax checks for all shell files.
- ShellCheck and shfmt when available.
- Unit tests with mocked commands for preflight, stage tracking, and error handling.
- Storage tests using mocks and, later, disposable loop devices only in isolated environments; never target a real disk.
- Integration tests in a disposable VM before any controlled ThinkPad X280 installation.
- Hardware-only checks (Wi-Fi, audio, suspend, hibernate/resume, lid behavior) remain NOT TESTED until run on the actual device.

Never treat a successful syntax check or mocked test as proof that installation works.
