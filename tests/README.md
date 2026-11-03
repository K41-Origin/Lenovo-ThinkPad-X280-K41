# Tests

The repository currently has eleven fixture-based test scripts covering common/preflight behavior, installer entry handling, host inventory, storage discovery/topology, storage-plan arithmetic, live prerequisite collection, explicit confirmation/final revalidation, the storage dry-run model, and the mock-only execution boundary. These tests do not constitute end-to-end installation or real-hardware validation. The topology fixture now allocates synthetic major:minor IDs separately from the host temporary-filesystem ID to avoid environment-dependent collisions.

Run the complete test suite from the repository root:

```bash
bash tests/run.sh
```

`tests/run.sh` is the canonical manifest used by both local development and GitHub Actions. It checks for `bash`, `jq`, and `python3` before running all required scripts; missing scripts or dependencies fail the run. Install `jq` and `python3` using the package manager for the environment before running locally.


Storage-discovery tests mock `lsblk` and `swapon` and use JSON fixtures. The topology module is called by `storage::validate_target` using the selected disk's kernel major:minor and live `/sys`, `/proc/self/mountinfo`, and `/proc/swaps`. The discovery test stubs that integration boundary; the topology test builds a synthetic sysfs graph and mountinfo/swaps fixtures. Coverage includes partition descendants, device-mapper holder/slave relationships, mounted dependencies, swapfiles, active block swap, loop-backed squashfs, overlay lower/upper/work directories, unresolved paths, malformed mountinfo, and unsupported filesystem types. Backing paths are mapped using their actual `st_dev` major:minor; no mounts or block-device writes are created.

The storage-plan test checks GPT bounds, 1 MiB alignment, 512-byte and 4Kn logical sectors, capacity rejection, RAM-plus-margin swap sizing, overflow, and decimal normalization. Prerequisite tests mock live collection and fail-closed paths. Confirmation tests cover exact confirmation, cancellation, modified plans, changed identity, and topology failure. The dry-run test checks the eight-step operation manifest, gate binding, stale-plan rejection, one-shot gate consumption, and injected failure stop behavior. The mock execution-boundary test re-probes path/major:minor/capacity/stable-ID kind/value/WWN/serial/transport/removable/read-only attributes before every mock step, rejects target changes, failed probes, and tampered gate metadata, and records partial failure/recovery state. Neither test executes storage commands or closes real TOCTOU races.

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
