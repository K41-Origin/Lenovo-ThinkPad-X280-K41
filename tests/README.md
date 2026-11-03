# Tests

The repository currently has ten fixture-based test scripts covering common/preflight behavior, installer entry handling, host inventory, storage discovery/topology, storage-plan arithmetic, live prerequisite collection, explicit confirmation/final revalidation, and the storage dry-run model. These tests do not constitute end-to-end installation or real-hardware validation.

Run the complete test suite from the repository root:

```bash
for test in \
  tests/test-common-preflight.sh \
  tests/test-installer-entry.sh \
  tests/test-inventory.sh \
  tests/test-storage-discovery.sh \
  tests/test-storage-plan.sh \
  tests/test-storage-prerequisites.sh \
  tests/test-storage-confirmation.sh \
  tests/test-storage-execution-dry-run.sh \
  tests/test-storage-topology.sh \
  tests/test-preflight-gate.sh
do
  bash "$test" || exit
 done
```

GitHub Actions also runs `bash -n` over all shell files and the ten test scripts on pushes to `main`, pull requests targeting `main`, and manual workflow dispatch. Run #106 (commit `5ef865d52370f4364678ff614cb8839d8da57ace`) passed syntax validation and all ten scripts. Treat each later workflow run independently; a prior pass does not prove subsequent commits pass.

Storage-discovery tests mock `lsblk` and `swapon` and use JSON fixtures. The topology module is called by `storage::validate_target` using the selected disk's kernel major:minor and live `/sys`, `/proc/self/mountinfo`, and `/proc/swaps`. The discovery test stubs that integration boundary; the topology test builds a synthetic sysfs graph and mountinfo/swaps fixtures. Coverage includes partition descendants, device-mapper holder/slave relationships, mounted dependencies, swapfiles, active block swap, loop-backed squashfs, overlay lower/upper/work directories, unresolved paths, malformed mountinfo, and unsupported filesystem types. Backing paths are mapped using their actual `st_dev` major:minor; no mounts or block-device writes are created.

The storage-plan test checks GPT bounds, 1 MiB alignment, 512-byte and 4Kn logical sectors, capacity rejection, RAM-plus-margin swap sizing, overflow, and decimal normalization. Prerequisite tests mock live collection and fail-closed paths. Confirmation tests cover exact confirmation, cancellation, modified plans, changed identity, and topology failure. The dry-run test checks the eight-step operation manifest, gate binding, stale-plan rejection, one-shot gate consumption, and injected failure stop behavior. It never executes storage commands.

The installer entry point remains diagnostic-only and does not invoke storage selection or installation. Tests use fixtures/mocks and do not inspect or modify host disks. Storage discovery requires `lsblk`, `jq`, `swapon`, `readlink`, and `base64`.

Inventory tests use temporary procfs/sysfs-shaped fixtures; they do not inspect actual hardware or require root. The mocked preflight gate verifies inventory failure blocks preflight success and that no installation/destructive marker is invoked.

Initial and future test layers:
- Bash syntax checks for all shell files.
- ShellCheck and shfmt when available; neither is currently included in CI.
- Unit tests with mocked commands for preflight, stage tracking, and error handling.
- Storage tests using mocks and, later, disposable loop devices only in isolated environments; never target a real disk.
- Integration tests in a disposable VM before any controlled ThinkPad X280 installation.
- Hardware-only checks (Wi-Fi, audio, suspend, hibernate/resume, lid behavior) remain NOT TESTED until run on the actual device.

Never treat a successful syntax check or mocked test as proof that installation works.
