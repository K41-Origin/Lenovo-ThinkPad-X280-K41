# Tests

The repository currently has twelve test scripts covering common/preflight behavior, installer entry handling, host inventory, storage discovery/topology, storage-plan arithmetic, live prerequisite collection, explicit confirmation/final revalidation, the storage dry-run model, and the mock-only execution boundary. These tests do not constitute end-to-end installation or real-hardware validation. The topology fixture now allocates synthetic major:minor IDs separately from the host temporary-filesystem ID to avoid environment-dependent collisions.

Run the complete test suite from the repository root:

```bash
bash tests/run.sh
```

`tests/run.sh` is the canonical manifest used by both local development and GitHub Actions. It checks for `bash`, `jq`, `python3`, and a C compiler (`cc`) before running all required scripts; missing scripts or dependencies fail the run. Install `jq`, `python3`, and a C compiler using the package manager for the environment before running locally.


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

## Live Arch ISO / ThinkPad validation

From the repository root on the target machine, run:

```bash
bash scripts/live-validation.sh
```

The script performs read-only host/boot/storage/network inventory, validates Bash syntax, runs ShellCheck and shfmt when installed, executes the canonical `bash tests/run.sh` suite, and records installer help/preflight output. Missing optional inventory/lint tools are recorded as SKIPPED; failures in syntax, available static checks, or the canonical suite make the script exit non-zero.

Evidence is saved automatically under `reports/live-validation/`:
- `YYYYMMDDTHHMMSSZ.md` — timestamped report; existing reports are never overwritten.
- `latest.md` — convenience copy of the most recent report.

Reports are local working-tree artifacts, not automatically committed or uploaded. Review them for sensitive environment details before sharing or committing. Keep timestamped reports as historical evidence and consult `latest.md` before repeating checks. A report applies only to its recorded checkout/commit and host snapshot; it does not prove installation works or authorize disk changes. Re-run after changing code, booting a different environment, changing hardware/storage state, or when fresh evidence is required.

The script is non-destructive: it does not partition, format, mount, install packages, alter services, or change firmware. The installer preflight's non-zero exit is recorded as informational because installation remains intentionally disabled.


The native Stage 8 helper test compiles `native/storage-handle.c` with strict compiler warnings and checks help/argument rejection in a temporary directory. It does not open a block device; exclusive-open contention, descriptor ioctls, diskseq, descriptor lifetime, hot-unplug, and loop-device behavior remain NOT TESTED until isolated disposable-device tests are added.
